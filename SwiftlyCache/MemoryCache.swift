//
//  MemoryCache.swift
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
public class MemoryCacheGenerator<Value:Codable>:IteratorProtocol{
    public typealias Element = (key:String,object:Value)
    
    private var memoryCache:MemoryCache<Value>
    
    fileprivate init(memoryCache:MemoryCache<Value>) {
        self.memoryCache = memoryCache
    }
    public func next() -> Element? {
        guard let node = memoryCache.storage.next() else {
            memoryCache.storage.setCurrentNode()
            return nil
        }
        memoryCache.storage.moveNode(node: node)
        return (node.key,node.object)
    }
    
}
private let cacheIdentifier: String = "com.swiftcache.memory"

public class MemoryCache<Value:Codable>{
    /**
     设置最大的内存缓存容量(0为不限制)
     */
    public var totalCostLimit:vm_size_t = 0
    /**
    设置最大的内存缓存数量
    */
    public var totalCountLimit:vm_size_t = 0
    /**
     系统内存警告是否删除所有内存数据，默认为true
     */
    public var autoRemoveAllObjectWhenMemoryWarning = true
    /**
     进入后台是否删除所有内存数据，默认为true
     */
    public var autoRemoveAllObjectWhenEnterBackground = true
    
    fileprivate let storage:MemoryStorage = MemoryStorage<Value>()
    
//    private var mutex:pthread_mutex_t = pthread_mutex_t()
    private let semaphoreSignal = DispatchSemaphore(value: 1)
    
    private let queue: DispatchQueue = DispatchQueue(label: cacheIdentifier, attributes: DispatchQueue.Attributes.concurrent)
    
    public init() {
//        pthread_mutex_init(&mutex, nil)
        NotificationCenter.default.addObserver(self, selector: #selector(didReceiveMemoryWarningNotification), name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(didEnterBackgroundNotification), name: UIApplication.didEnterBackgroundNotification, object: nil)
    }
    
    deinit {
//        pthread_mutex_destroy(&mutex)
        NotificationCenter.default.removeObserver(self, name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.didEnterBackgroundNotification, object: nil)
    }
    
    @objc fileprivate func didReceiveMemoryWarningNotification(){
        if self.autoRemoveAllObjectWhenMemoryWarning{
            removeAll()
        }
    }
       
    @objc fileprivate func didEnterBackgroundNotification(){
        if self.autoRemoveAllObjectWhenEnterBackground{
            removeAll()
        }
    }
    
    /**
     超过限定张数，需要丢弃一部分内容
     */
    private func discardedToCount(){
        if self.totalCountLimit != 0{
            if self.storage.totalCountLimit > self.totalCountLimit{
                storage.removeTailNode()
            }
        }
    }
    
    /**
     超过限定容量，需要丢弃一部分内容
     */
    private func discardedToCost(){
        if self.totalCostLimit != 0{
            while self.storage.totalCostLimit > self.totalCostLimit {
                self.storage.removeTailNode()
            }
        }
    }
}

extension MemoryCache:Sequence{
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
    public func makeIterator() -> MemoryCacheGenerator<Value> {
//        pthread_mutex_lock(&mutex)
        semaphoreSignal.wait()
        self.storage.setCurrentNode()
        let generator = MemoryCacheGenerator(memoryCache: self)
//        pthread_mutex_unlock(&mutex)
        semaphoreSignal.signal()
        return generator
    }
}

extension MemoryCache:CacheAware{
    /**
    设置需要缓存的key和value
    @param key: 与value关联的键
    @param value: 需要缓存的对象，如果为nil,则直接返回false
    @cost: 缓存对象所占用的字节(默认为0)
    @return 内存缓存与磁盘缓存只要其中一个缓存成功则返回true
    */
    
    @discardableResult
    public func set(forKey key: String, value: Value?, cost: vm_size_t = 0) ->Bool{
        guard let object = value else { return false }
//        pthread_mutex_lock(&mutex)
        semaphoreSignal.wait()
        if let node:LinkedNode = storage.dic[key]{
            node.object = object
            node.cost = cost
            //移动到链表头
            storage.moveNode(node: node)
        }else{
            let node:LinkedNode = LinkedNode(key: key, object: object, cost: cost)
            storage.dic[key] = node
            storage.insertNodeAtHead(node: node)
        }
        discardedToCount()
        discardedToCost()
//        pthread_mutex_unlock(&mutex)
        semaphoreSignal.signal()
        return true
    }
    
    /**
    设置需要缓存的key和value
    @param key: 与value关联的键
    @param value: 需要缓存的对象，如果为nil，则该方法无效
    @param cost:缓存对象所占用的字节(默认为0)
    @param completionHandler: 缓存数据写入完成回调
    */
    public func set(forKey key:String,value:Value?,cost:vm_size_t = 0,completionHandler:@escaping((_ key:String,_ finished:Bool) -> Void)){
        queue.async {
            let fin = self.set(forKey: key, value: value,cost: cost)
            completionHandler(key,fin)
        }
    }
    
    /**
    根据key查询对应的value
    @param key: 与value关联的键
    @return 返回与key关联的value，如果没有与key对应的value，返回nil
    */
    public func object(forKey key: String) -> Value? {
//        pthread_mutex_lock(&mutex)
        semaphoreSignal.wait()
        guard let node = storage.dic[key] else {
//            pthread_mutex_unlock(&mutex)
            semaphoreSignal.signal()
            return nil
        }
        //移动到链表头
        storage.moveNode(node: node)
//        pthread_mutex_unlock(&mutex)
        semaphoreSignal.signal()
        return node.object
    }
    
    /**
    根据key查询对应的value
    @param key: 与value关联的键
    @param completionHandler 查询完成回调
    */
    public func object(forKey key:String,completionHandler:@escaping((_ key:String,_ value:Value?) -> Void)){
        queue.async {
            if let object = self.object(forKey: key){ completionHandler(key,object) }
            else{ completionHandler(key,nil) }
        }
    }
    
    /**
    根据key查询缓存中是否存在对应的value
    @return 如果缓存中存在与key对应的value，返回true,否则返回false
    */
    public func isExistsObjectForKey(forKey key: String) -> Bool {
//        pthread_mutex_lock(&mutex)
        semaphoreSignal.wait()
        let exists = storage.dic.keys.contains(key)
//        pthread_mutex_unlock(&mutex)
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
        if storage.dic.isEmpty{ return }
//        pthread_mutex_lock(&mutex)
        semaphoreSignal.wait()
        storage.removeAllObject()
//        pthread_mutex_unlock(&mutex)
        semaphoreSignal.signal()
    }
    
    /**
     移除所有缓存
     completionHandler: 移除完成回调
     */
    public func removeAll(completionHandler: @escaping (() -> Void)) {
        queue.async {
            self.removeAll()
            completionHandler()
        }
    }
    
    /**
     移除指定缓存
     key:通过key删除对应的value
     */
    public func removeObject(forKey key:String){
//        pthread_mutex_lock(&mutex)
        semaphoreSignal.wait()
        if let node:LinkedNode = storage.dic[key]{
            storage.removeObject(node: node)
        }
//        pthread_mutex_unlock(&mutex)
        semaphoreSignal.signal()
    }
    
    /**
     移除指定缓存
     key:通过key删除对应的value
     completionHandler: 移除完成回调
     */
    public func removeObject(forKey key: String, completionHandler:@escaping(() -> Void)) {
        queue.async {
            self.removeObject(forKey: key)
            completionHandler()
        }
    }
}


