//
//  MainViewController.swift
//  SwiflyCacheDemo
//
//  Created by 黄琳川 on 2020/3/22.
//  Copyright © 2020 黄琳川. All rights reserved.
//

import Foundation
import SwiftlyCache

struct Student:Codable {
    var name:String
    var age:Int
    
    init(name:String,age:Int) {
        self.name = name
        self.age = age
    }
}

class MainViewController:ViewController{
    let cache = MultiCache<Student>()
    let memoryCache = MemoryCache<Student>()
    let diskCache = DiskCache<Student>(path: NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)[0] + "SwiftlyDiskCache")
    
    //    var diskCache = DiskCache<Student>(path: path)
    override func viewDidLoad() {
//        super.viewDidLoad()
        /**
         MultiCache
         
         setObjectTest()
         MultiCacheGenerator()
         isExistsObjectForKeyTest()
         removeAll()
         getObjectTest()
         multiCacheGenerator()
         */
        /**
         memorySetObjectTest()
         memoryGetObjectTest()
         memoryRemoveObject()
         memoryIsExistsObjectForKeyTest()
         memoryRemoveAll()
         memoryCacheGenerator()
         */

//        diskCacheGenerator()
//        diskCacheIsExistsObjectForKeyTest()
//        diskCacheRemoveObject()
//        diskCacheRemoveAll()
//        diskCacheSetObjectTest()
//        diskCacheGetObjectTest()
    }
    
        /**
         MultiCache测试用例
         */
    
        func multiCacheGenerator(){
            
            let flatMapResult = cache.compactMap { $0 }
            print("flatMapResult:\(flatMapResult)")
            
            let filterResult = cache.filter { (key,object) -> Bool in
                return key == "shirley2"
             }
            print(filterResult)
            
            cache.forEach { print($0)}
            
            let values = cache.map { return $0 }
            print(values)

            for (key,object) in cache {
                    print("key1:\(key),object1:\(object)")
            }
        }
    
        func setObjectTest(){
            let shirley = Student(name: "shirley", age: 30)
            /**
             返回值也可以不需要
             */
            let fin = cache.set(forKey: "shirley10", value: shirley)
            print("当前数据缓存是否成功(fin为Bool类型):\(fin)")
            /*
             cost:缓存对象大小(字节为单位)
             一般是在需要设置totalCostLimit才需要设置cost,默认为0
             当所有缓存对象总大小超出totalCostLimit，会丢弃掉一些缓存数据
             **/
            cache.set(forKey: "shirley1", value: shirley, cost: 5)
            
            /**
             异步调用set
             */
            cache.set(forKey: "shirley2", value: shirley) { (key, fin) in
                print("当前缓存对象对应的key:\(key),当前数据缓存是否成功(fin为Bool类型):\(fin)")
            }
            cache.set(forKey: "shirley3", value: shirley, cost: 0) { (key, fin) in
                print("当前缓存对象对应的key:\(key),当前数据缓存是否成功(fin为Bool类型):\(fin)")
            }
            cache.set(forKey: "shirley4", value: nil, cost: 0) { (key, fin) in
                print("当前缓存对象对应的key:\(key),当前数据缓存是否成功(fin为Bool类型):\(fin)")
            }
        }
    
        func MultiCacheGenerator(){
            for (key,object) in cache{
                print("key:\(key),object:\(object)")
            }
        }
    
        func getObjectTest(){
            if let object = cache.object(forKey: "shirley1"){
                print("当前Student是:\(object)")
            }
    
            cache.object(forKey: "shirley2") { (key, value) in
                if let object = value{
                    print("当前Student是:\(object)")
                }
            }
    
            let object1 = cache.object(forKey: "shirley30")
            print("有没有这个stundent:\(object1)")
    
            cache.object(forKey: "shirley20") { (key, value) in
                print("有没有这个stundent1:\(value)")
            }
        }
    
        func isExistsObjectForKeyTest(){
            let fin = cache.isExistsObjectForKey(forKey: "shirley20")
            print("是否存在key对应的value:\(fin)")
    
            cache.isExistsObjectForKey(forKey: "shirley10") { (key, fin) in
                print("是否存在key\(key)对应的value:\(fin)")
            }
        }
    
        func removeObject(){
            cache.removeObject(forKey: "shirley20")
            cache.removeObject(forKey: "shirley2") {
                print("")
            }
        }
    
        func removeAll(){
            cache.removeAll()
            cache.removeAll {
                print("")
            }
        }
    
    
    
    
        /**
         MemoryCache测试用例
         */
    
        func memoryCacheGenerator(){
            
            let flatMapResult = memoryCache.compactMap { $0 }
            print("flatMapResult:\(flatMapResult)")
            
            let filterResult = memoryCache.filter { (key,object) -> Bool in
                return key == "shirley2"
             }
            print(filterResult)
            
            memoryCache.forEach { print($0)}
            
            let values = memoryCache.map { return $0 }
            print(values)

            for (key,object) in memoryCache {
                    print("key1:\(key),object1:\(object)")
            }
        }
        func memorySetObjectTest(){
            let shirley = Student(name: "shirley", age: 50)
            /**
             返回值也可以不需要
             */
            let fin = memoryCache.set(forKey: "shirley19", value: shirley,cost: 0)
            print("当前数据缓存是否成功(fin为Bool类型):\(fin)")
//            /*
//             cost:缓存对象大小(字节为单位)
//             一般是在需要设置totalCostLimit才需要设置cost,默认为0
//             当所有缓存对象总大小超出totalCostLimit，会丢弃掉一些缓存数据
//             **/
            memoryCache.set(forKey: "shirley1", value: shirley, cost: 5)
            /**
             异步调用set
             */
            memoryCache.set(forKey: "shirley2", value: shirley) { (key, fin) in
                print("当前缓存对象对应的key:\(key),当前数据缓存是否成功(fin为Bool类型):\(fin)")
            }
            memoryCache.set(forKey: "shirley3", value: shirley, cost: 0) { (key, fin) in
                print("当前缓存对象对应的key:\(key),当前数据缓存是否成功(fin为Bool类型):\(fin)")
            }
            memoryCache.set(forKey: "shirley4", value: nil, cost: 0) { (key, fin) in
                print("当前缓存对象对应的key:\(key),当前数据缓存是否成功(fin为Bool类型):\(fin)")
            }
        }

        func memoryGetObjectTest(){
            if let object = memoryCache.object(forKey: "shirley1"){
                print("当前Student是:\(object)")
            }

            memoryCache.object(forKey: "shirley2") { (key, value) in
                if let object = value{
                    print("当前Student是:\(object)")
                }
            }

            let object1 = memoryCache.object(forKey: "shirley30")
            print("有没有这个stundent:\(object1)")

            memoryCache.object(forKey: "shirley20") { (key, value) in
                print("有没有这个stundent1:\(value)")
            }
        }

        func memoryIsExistsObjectForKeyTest(){
            let fin = memoryCache.isExistsObjectForKey(forKey: "shirley2")
            print("是否存在key对应的value:\(fin)")

            memoryCache.isExistsObjectForKey(forKey: "shirley1") { (key, fin) in
                print("是否存在key\(key)对应的value:\(fin)")
            }
        }

        func memoryRemoveObject(){
            memoryCache.removeObject(forKey: "shirley20")
            memoryCache.removeObject(forKey: "shirley2") {
                print("")
            }

        }

        func memoryRemoveAll(){
            memoryCache.removeAll()
            memoryCache.removeAll {
                print("")
            }
        }
    
    
        /**
        DiskCache
         */
        func diskCacheGenerator(){
            
            let flatMapResult = diskCache.compactMap { $0 }
            print("flatMapResult:\(flatMapResult)")
            
            let filterResult = diskCache.filter { (key,object) -> Bool in
                return key == "shirley222"
             }
            print(filterResult)
            
            diskCache.forEach { print($0)}
            
            let values = diskCache.map { return $0 }
            print(values)
            
            for (key,object) in diskCache {
                    print("key1:\(key),object1:\(object)")
            }
        }
    
        func  diskCacheSetObjectTest(){
                let shirley = Student(name: "shirley", age: 50)
                /**
                返回值也可以不需要
                */
                let fin = diskCache.set(forKey: "shirley19", value: shirley,cost: 5)
                print("当前数据缓存是否成功(fin为Bool类型):\(fin)")
                /*
                cost:缓存对象大小(字节为单位)
                一般是在需要设置totalCostLimit才需要设置cost,默认为0
                当所有缓存对象总大小超出totalCostLimit，会丢弃掉一些缓存数据
                **/
//            diskCache.maxCountLimit = 1
//                diskCache.maxSize = 80
                diskCache.set(forKey: "shirley1", value: shirley, cost: 5)
                /**
                异步调用set
                */
                diskCache.set(forKey: "shirley222", value: shirley) { (key, fin) in
                    print("当前缓存对象对应的key:\(key),当前数据缓存是否成功(fin为Bool类型):\(fin)")
                }
                diskCache.set(forKey: "shirley3333", value: shirley, cost: 0) { (key, fin) in
                    print("当前缓存对象对应的key:\(key),当前数据缓存是否成功(fin为Bool类型):\(fin)")
                }
                diskCache.set(forKey: "shirley444", value: shirley, cost: 0) { (key, fin) in
                    print("当前缓存对象对应的key:\(key),当前数据缓存是否成功(fin为Bool类型):\(fin)")
                }
            }
                
            func diskCacheGetObjectTest(){
                if let object = diskCache.object(forKey: "shirley1"){
                    print("当前Student是:\(object)")
                }
            
                diskCache.object(forKey: "shirley2") { (key, value) in
                    if let object = value{
                        print("当前Student是:\(object)")
                    }
                }
            
                let object1 = diskCache.object(forKey: "shirley30")
                print("有没有这个stundent:\(object1)")
            
                diskCache.object(forKey: "shirley19") { (key, value) in
                    print("有没有这个stundent1:\(value)")
                }
            }
                
            func diskCacheIsExistsObjectForKeyTest(){
                let fin = diskCache.isExistsObjectForKey(forKey: "shirley2")
                print("是否存在key对应的value:\(fin)")
        
                diskCache.isExistsObjectForKey(forKey: "shirley1") { (key, fin) in
                    print("是否存在key\(key)对应的value:\(fin)")
                }
            }
                
            func diskCacheRemoveObject(){
                diskCache.removeObject(forKey: "shirley20")
                diskCache.removeObject(forKey: "shirley2") {
                    print("")
                }
            }
                
            func diskCacheRemoveAll(){
                diskCache.removeAll()
                diskCache.removeAll {
                    print("")
                }
            }


}
