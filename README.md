# SwiftlyCache

[![Build Status](https://travis-ci.org/hlc0000/SwiftlyCache.svg?branch=master)](https://travis-ci.org/hlc0000/SwiftlyCache)
![](https://img.shields.io/cocoapods/p/SwiftlyCache.svg?style=flat)
![](https://img.shields.io/cocoapods/v/SwiftlyCache.svg?style=flat)

`Swiftlycache` is a thread safe IOS general cache library written with `swift 5`.

Features
===============

- Support all data types complying with the `codable` protocol
- Objects can be evicted with least-recently-used algorithm
- It can be configured to automatically recycle objects or manually recycle objects when receiving memory warnings or when the application enters the background
- Using subscript can make reading and writing data more convenient
- Support reading data using sequence generator

Installation
==============
CocoaPods
-------------------------------
1.Add `pod 'SwiftlyCache'` to your Podfile  
2.Run `pod install` or `pod update`  
3.import `SwiftlyCache`

Manually
-------------------------------
1.Download all the files in the `SwiftlyCache` subdirectory  
2.Add the source files to your Xcode project  

Example:
-------------------------------
Cache a struct complying with the  `codable` protocol

```
struct Student:Codable {
     var name:String
     var age:Int
     
     init(name:String,age:Int) {
         self.name = name
         self.age = age
     }
 }
 ```
 ```
 let cache = MultiCache<Student>()
 
 let shirley = Student(name: "shirley", age: 30)
 
```
 
Set `key` and `value` to be cached
 
 ```
 cache.set(forKey: "shirley10", value: shirley)
 
``` 

Query the corresponding value according to the given `key`

```
if let object = cache.object(forKey: "shirley1"){
    print("当前Student是:\(object)")
}
```

Query whether the corresponding `value` exists in the cache according to `key`

```

let isExists = cache.isExistsObjectForKey(forKey: "shirley20")

```
See `swiftlycachedemo` for more test code and cases

<br/><br/>
---

中文介绍
============================

 `SwiftlyCache`是用 `Swift 5`编写的一个线程安全的iOS通用缓存库。

特性:
==============

-  支持所有遵守 `Codable`协议的数据类型
-  支持LRU淘汰算法
-  当收到内存警告或者App进入后台时,内存缓存可以配置为自动清空或者手动清空
-  支持使用 `Subscript`，使读写数据更加方便
-  提供了 `MultiCacheGennerator、` `MemoryCacheGenerator、` `DiskCacheGenerator`用于支持 `for..in、`
   `compactMap、` `map、` `filter`等方法
  
  使用方法:
  =============
  CocoaPods:
  ------------------------------
  1.在Podfile中添加 `pod 'SwiftlyCache'`     
  2.执行 `pod install`或者 `pod update`    
  3.导入  `SwiftlyCache`    
  
  手动导入:
  ------------------------------
  1.下载 `SwiftlyCache`文件夹内所有内容  
  2.将 `SwiftlyCache`内的源文件添加到你的工程  
  
  示例:
  ------------------------------
  将一个遵守`Codable`协议的struct进行缓存
  
 ```
 struct Student:Codable {
      var name:String
      var age:Int
      
      init(name:String,age:Int) {
          self.name = name
          self.age = age
      }
  }
  ```
  ```
  let cache = MultiCache<Student>()
  
  let shirley = Student(name: "shirley", age: 30)
  
 ```
  
  设置需要缓存的`Key`和`Value`
  
  ```
  cache.set(forKey: "shirley10", value: shirley)
  
 ``` 
 
 根据给定的`Key`查询对应的Value
 
 ```
 if let object = cache.object(forKey: "shirley1"){
     print("当前Student是:\(object)")
 }
 ```
 
 根据`Key`查询缓存中是否存在对应的`Value`
 
 ```
 
 let isExists = cache.isExistsObjectForKey(forKey: "shirley20")
 
 ```
 
更多测试代码和用例见  `SwiftlyCacheDemo`

相关链接:
==============
[SwiftlyCache实现](https://juejin.im/post/5e7084886fb9a07c7b784f7f)
  

  
  
  


