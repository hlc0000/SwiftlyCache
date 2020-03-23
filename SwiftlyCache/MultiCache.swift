//
//  HybridCache.swift
//  HummingBird
//
//  Created by 黄琳川 on 2020/1/10.
//  Copyright © 2020 黄琳川. All rights reserved.
//

import Foundation

/**
 支持for...in循环
 */
public class MultiCacheGenerator<Value:Codable>:IteratorProtocol{
    public typealias Element = (String,Value)
    
    private let memoryCache:MemoryCache<Value>
    
    private let diskCache:DiskCache<Value>
    
    private let memoryCacheGenerator: MemoryCacheGenerator<Value>
    
    private let diskCacheGenerator: DiskCacheGenerator<Value>
    
    public func next() -> Element? {
        if diskCacheGenerator.index == 0{ diskCache.getAllKey() }
        guard diskCacheGenerator.index < diskCache.keys.endIndex  else {
            diskCacheGenerator.index = diskCache.keys.startIndex
            return nil
        }
        let key = diskCache.keys[diskCacheGenerator.index]
        diskCache.keys.formIndex(after: &diskCacheGenerator.index)
        if let element = memoryCache.object(forKey: key){
            return (key,element)
        }else if let element = diskCache.object(forKey: key){
            memoryCache.set(forKey: key, value: element)
            return (key,element)
        }
        return nil
    }
    
    fileprivate init(memoryCache:MemoryCache<Value>,diskCache:DiskCache<Value>,
                     memoryCacheGenerator:MemoryCacheGenerator<Value>,diskCacheGenerator:DiskCacheGenerator<Value>){
        self.memoryCache = memoryCache
        self.diskCache = diskCache
        self.memoryCacheGenerator = memoryCacheGenerator
        self.diskCacheGenerator = diskCacheGenerator
    }
}

private let cacheIdentifier: String = "com.swiftcache.hybrid"
public class MultiCache<Value:Codable>{
    
    public let memoryCache:MemoryCache = MemoryCache<Value>()
    
    public let diskCache:DiskCache<Value>
    
    /**
     磁盘缓存路径
     */
    private var diskCachePath:String
    
    private let queue: DispatchQueue = DispatchQueue(label: cacheIdentifier, attributes: DispatchQueue.Attributes.concurrent)
    
    public init(cacheName:String="default") {
        self.diskCachePath = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)[0]
        self.diskCachePath = self.diskCachePath + ("/\(cacheName)")
        self.diskCache = DiskCache(path: self.diskCachePath)
    }
}

extension MultiCache:Sequence{
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
    public func makeIterator() -> MultiCacheGenerator<Value> {
        let generator = MultiCacheGenerator(memoryCache:memoryCache,diskCache: diskCache,memoryCacheGenerator: memoryCache.makeIterator(), diskCacheGenerator: diskCache.makeIterator())
        return generator
    }
}

extension MultiCache:CacheAware{
    /**
     设置需要缓存的key和value
     @param key: 与value关联的键
     @param value: 需要缓存的对象，如果为nil,则直接返回false
     @cost: 缓存对象所占用的字节(默认为0)
     @return 内存缓存与磁盘缓存只要其中一个缓存成功则返回true
     */
    
    @discardableResult
    public func set(forKey key: String, value: Value?, cost: vm_size_t = 0)->Bool {
        let memoryCacheFin = memoryCache.set(forKey: key, value: value,cost: cost)
        let diskCacheFin = diskCache.set(forKey: key, value: value)
        if memoryCacheFin || diskCacheFin{ return true }
        return false
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
            let memoryCacheFin = self.memoryCache.set(forKey: key, value: value,cost: cost)
            let diskCacheFin = self.diskCache.set(forKey: key, value: value)
            if memoryCacheFin || diskCacheFin{ completionHandler(key,true) }
            else{ completionHandler(key,false) }
        }
    }
    
    /**
     根据key查询对应的value
     @param key: 与value关联的键
     @return 返回与key关联的value，如果没有与key对应的value，返回nil
     */
    public func object(forKey key: String) -> Value? {
         if let object = self.memoryCache.object(forKey: key){ return object }
         if let object = diskCache.object(forKey: key){
            memoryCache.set(forKey: key, value: object)
            return object
        }
            return nil
    }
    
    /**
     根据key查询对应的value
     @param key: 与value关联的键
     @param completionHandler 查询完成回调
     */
    public func object(forKey key:String,completionHandler:@escaping((_ key:String,_ value:Value?) -> Void)){
        queue.async {
            if let object = self.memoryCache.object(forKey: key){
                completionHandler(key,object)
            }else if let object = self.diskCache.object(forKey: key){
                self.memoryCache.set(forKey: key, value: object)
                completionHandler(key,object)
            }else{ completionHandler(key,nil) }
        }
    }
    
    /**
     根据key查询缓存中是否存在对应的value
     @return 如果缓存中存在与key对应的value，返回true,否则返回false
     */
    public func isExistsObjectForKey(forKey key: String) -> Bool {
        return memoryCache.isExistsObjectForKey(forKey: key) || diskCache.isExistsObjectForKey(forKey: key)
    }
    
    /**
     根据key查询缓存中是否存在对应的value
     @param completionHandler: 查询完成后回调
     */
    public func isExistsObjectForKey(forKey key:String,completionHandler:@escaping((_ key:String,_ contain:Bool) -> Void)) {
        queue.async {
            let isExists = self.memoryCache.isExistsObjectForKey(forKey: key) || self.diskCache.isExistsObjectForKey(forKey: key)
            completionHandler(key,isExists)
        }
    }
    
    /**
     移除所有缓存
    */
    public func removeAll(){
        memoryCache.removeAll()
        diskCache.removeAll()
    }
    
    /**
     移除所有缓存
     @param completionHandler 移除完成后回调
     */
   public func removeAll(completionHandler:@escaping(() -> Void)){
        queue.async {
            self.memoryCache.removeAll()
            self.diskCache.removeAll()
            completionHandler()
        }
    }
    
    /**
     根据key移除缓存中对应的value
     @param key: 要移除的value对应的键
     */
    public func removeObject(forKey key: String){
        memoryCache.removeObject(forKey: key)
        diskCache.removeObject(forKey: key)
    }
    
    /**
     根据key移除缓存中对应的value
     @param key:要移除的value对应的键
     @param completionHandler:移除完成后回调
     */
    public func removeObject(forKey key: String, completionHandler: @escaping (() -> Void)) {
        queue.async {
            self.memoryCache.removeObject(forKey: key)
            self.diskCache.removeObject(forKey: key)
            completionHandler()
        }
    }
}



