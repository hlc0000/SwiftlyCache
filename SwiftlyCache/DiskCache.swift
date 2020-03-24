//
//  DiskCache.swift
//  HummingBird
//
//  Created by 黄琳川 on 2019/12/27.
//  Copyright © 2019 黄琳川. All rights reserved.
//

import Foundation
import UIKit

/**
支持for...in循环
*/
public class DiskCacheGenerator<Value:Codable>:IteratorProtocol{
    public typealias Element = (key:String,object:Value)
    
    private let diskCache:DiskCache<Value>
    
    var index:Int
    
    public func next() -> Element? {
        if index == 0{ diskCache.getAllKey() }
        guard index < diskCache.keys.endIndex  else {
            index = diskCache.keys.startIndex
            return nil
        }
        let key = diskCache.keys[index]
        diskCache.keys.formIndex(after: &index)
        if let element = diskCache.object(forKey: key){
            return (key,element)
        }
        return nil
    }
    fileprivate init(diskCache:DiskCache<Value>) {
        self.diskCache = diskCache
        self.index = self.diskCache.keys.startIndex
    }
}

public class ConvertibleFactory<Value:Codable>{
    public func toData(value:Value)throws -> Data?{
        let data = try? JSONEncoder().encode(value)
        return data
    }
    
    public func fromData(data:Data)throws -> Value?{
        let object = try? JSONDecoder().decode(Value.self, from: data)
        return object
    }
}

private let cacheIdentifier: String = "com.swiftcache.disk"
public class DiskCache<Value:Codable>{
    /**
    设置最大的磁盘缓存容量(0为不限制)
    */
    public var maxSize:vm_size_t = 0

    /**
    设置最大的磁盘缓存数量
    */
    public var maxCountLimit:vm_size_t = 0
    /**
     缓存的过期时间(默认是一周)
     */
    public var maxCachePeriodInSecond:TimeInterval = 60 * 60 * 24 * 7
    
    fileprivate let storage:DiskStorage<Value>
    
    private let semaphoreSignal = DispatchSemaphore(value: 1)
    
    private let convertible:ConvertibleFactory = ConvertibleFactory<Value>()
    
    private let dataMaxSize = 20 * 1024
    
    public var autoInterval:TimeInterval = 120
    
    var keys = [String]()
    
    private let queue: DispatchQueue = DispatchQueue(label: cacheIdentifier, attributes: DispatchQueue.Attributes.concurrent)
    
    public init(path:String) {
        storage = DiskStorage(currentPath: path)
        recursively()
    }
    
    private func recursively(){
        DispatchQueue.global().asyncAfter(deadline: .now() + autoInterval) {[weak self] in
            guard let strongSelf = self else { return }
            strongSelf.discardedData()
            strongSelf.recursively()
        }
    }
    
    private func discardedData(){
        queue.async {
            self.semaphoreSignal.wait()
            self.discardedToCost()
            self.discardedToCount()
            self.removeExpired()
            self.semaphoreSignal.signal()
        }
    }
    
    /**
     超过限定张数，需要丢弃一部分内容
     */
    private func discardedToCount(){
        if maxCountLimit == 0{ return }
        var totalCount = storage.dbTotalItemCount()
        if totalCount <= maxCountLimit{ return }
        var fin = false
        repeat{
            let items = storage.dbGetSizeExceededValues()
            for item in items{
                if totalCount > maxCountLimit{
                    if let filename = item?.filename{
                        if storage.removeFile(filename: filename){
                            if let key = item?.key{ fin = storage.dbRemoveItem(key: key) }
                        }
                    }else if let key = item?.key{ fin = storage.dbRemoveItem(key: key )}
                    if fin{ totalCount -= 1 }
                    else { break }
                }else{ break }
            }
            
        }while totalCount > maxCountLimit
        if fin{ storage.dbCheckpoint() }
    }
    
    /**
     超过限定容量,需要丢弃一部分内容
     */
    private func discardedToCost(){
        if maxSize == 0{ return }
        var totalCost = storage.dbTotalItemSize()
        if totalCost < maxSize{ return }
        var fin = false
        repeat{
            let items = storage.dbGetSizeExceededValues()
            for item in items{
                if totalCost > maxSize{
                    if let filename = item?.filename{
                        if storage.removeFile(filename: filename){
                            if let key = item?.key{ fin = storage.dbRemoveItem(key: key) }
                        }
                    }else if let key = item?.key{ fin = storage.dbRemoveItem(key: key) }
                    if fin{ totalCost -= item!.size }
                    else { break }
                }else{ break }
            }
        }while totalCost > maxSize
        if fin{ storage.dbCheckpoint() }
    }
    
    /**
     移除过期数据
     @return 移除成功,返回true,否则返回false
     */
    @discardableResult
    private func removeExpired()->Bool{
        var currentTime = Date().timeIntervalSince1970
        currentTime -= maxCachePeriodInSecond
        let fin = storage.dbRemoveAllExpiredData(time: currentTime)
        return fin
    }
    
    @discardableResult
    public func removeAllExpired()->Bool{
        semaphoreSignal.wait()
        let fin = removeExpired()
        semaphoreSignal.signal()
        return fin
    }
}

extension DiskCache:Sequence{
    /**
    通过下标方式set和get
    @param key: value关联的键
    @return Value:根据key查询对应的value，如果查询到则返回对应value，否则返回nil
    */
    public subscript(key:String) ->Value?{
        set{
            if let newValue = newValue{ set(forKey: key, value: newValue) }
        }get{
            if let object = object(forKey: key){ return object }
            return nil
        }
    }
    
    /**
    返回该序列元素迭代器
    */
    public func makeIterator() -> DiskCacheGenerator<Value> {
        semaphoreSignal.wait()
        let generator = DiskCacheGenerator(diskCache: self)
       semaphoreSignal.signal()
        return generator
    }
}

extension DiskCache:CacheAware{
    
    /**
    设置需要缓存的key和value
    @param key: 与value关联的键
    @param value: 需要缓存的对象，如果为nil,则直接返回false
    @cost: 缓存对象所占用的字节(默认为0,在磁盘缓存中此参数暂不使用)
    @return 缓存成功则返回true,否则返回false
    */
    @discardableResult
    public func set(forKey key: String, value: Value?, cost: vm_size_t = 0)->Bool{
        guard let object = value else { return false }
        guard let encodedData = try? convertible.toData(value: object) else{ return false }
        var filename:String? = nil
        if encodedData.count > dataMaxSize{
            filename = storage.makeFileName(forKey: key)
        }
        semaphoreSignal.wait()
        let fin = storage.save(forKey: key, value: encodedData,filename: filename)
        semaphoreSignal.signal()
        return fin
    }
    
    /**
    设置需要缓存的key和value
    @param key: 与value关联的键
    @param value: 需要缓存的对象，如果为nil，则直接返回false
    @cost: 缓存对象所占用的字节(默认为0,在磁盘缓存中此参数暂不使用)
    @param completionHandler: 缓存数据写入完成回调
    */
    public func set(forKey key:String,value:Value?,cost:vm_size_t = 0,completionHandler:@escaping((_ key:String,_ finished:Bool) -> Void)){
        queue.async {
            let fin =  self.set(forKey: key, value: value,cost: cost)
            completionHandler(key,fin)
        }
    }
    
    /**
    根据key查询对应的value
    @param key: 与value关联的键
    @return 返回与key关联的value，如果没有与key对应的value，返回nil
    */
    public func object(forKey key: String) -> Value? {
        semaphoreSignal.wait()
        let item = storage.dbGetItemForKey(forKey: key)
        semaphoreSignal.signal()
        guard let value = item?.data else{ return nil }
        return try? convertible.fromData(data: value)
    }
    
    /**
    根据key查询对应的value
    @param key: 与value关联的键
    @param completionHandler 查询完成回调
    */
    public func object(forKey key:String,completionHandler:@escaping((_ key:String,_ value:Value?) -> Void)){
        queue.async {
            if let object = self.object(forKey: key){ completionHandler(key,object) }
            else { completionHandler(key,nil) }
        }
    }
    
    func getAllKey(){
        semaphoreSignal.wait()
        keys = storage.dbGetAllkey()
        semaphoreSignal.signal()
    }
    
    /**
     获取存储总的数量
     @return 返回存储总的数量
     */
    public func getTotalItemCount()->Int{
        semaphoreSignal.wait()
        let count = storage.dbTotalItemCount()
        semaphoreSignal.signal()
        return count
    }
    
    /**
     获取存储总的数量
     @param completionHandler 查询存储数量成功回调
     */
    public func getTotalItemCount(completionHandler:@escaping((_ count:Int)->Void)){
        queue.async {
            let count = self.getTotalItemCount()
            completionHandler(count)
        }
    }
    
    /**
     获取磁盘数据占用容量
     @return 返回磁盘数据占用容量
     */
    public func getTotalItemSize()->Int32{
        self.semaphoreSignal.wait()
        let size = storage.dbTotalItemSize()
        self.semaphoreSignal.signal()
        return size
    }
    
    /**
     获取数据占用容量
     @param completionHandler: 查询存储数量成功回调
     */
    public func getTotalItemSize(completionHandler:@escaping((_ size:Int32)->Void)){
        queue.async {
            let size = self.getTotalItemSize()
            completionHandler(size)
        }
    }
    
    /**
    根据key查询缓存中是否存在对应的value
    @return 如果缓存中存在与key对应的value，返回true,否则返回false
    */
    public func isExistsObjectForKey(forKey key: String) -> Bool {
        semaphoreSignal.wait()
        let exists = self.storage.dbIsExistsForKey(forKey: key)
        semaphoreSignal.signal()
        return exists
    }
    
    /**
    根据key查询缓存中是否存在对应的value
    @param completionHandler: 查询完成后回调
    */
    public func isExistsObjectForKey(forKey key:String,completionHandler:@escaping((_ key:String,_ contain:Bool) -> Void)) {
        queue.async {
            let exists = self.isExistsObjectForKey(forKey: key)
            completionHandler(key,exists)
        }
    }
    
    /**
     移除所有缓存
    */
    public func removeAll(){
        semaphoreSignal.wait()
        storage.removeAll()
        semaphoreSignal.signal()
    }
    
    /**
    移除所有缓存
    @param completionHandler 移除完成后回调
    */
    public func removeAll(completionHandler: @escaping (() -> Void)) {
        queue.async {
            self.removeAll()
            completionHandler()
        }
    }
    
    /**
    移除所有缓存
    @param completionHandler 移除完成后回调
    */
    public func removeObject(forKey key:String){
        semaphoreSignal.wait()
        storage.removeObject(key: key)
        semaphoreSignal.signal()
    }
    
    /**
    根据key移除缓存中对应的value
    @param key:要移除的value对应的键
    @param completionHandler:移除完成后回调
    */
    public func removeObject(forKey key:String,completionHandler:@escaping(() -> Void)){
        queue.async {
            self.removeObject(forKey: key)
            completionHandler()
        }
    }
}
