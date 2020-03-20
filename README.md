# SwiftlyCache

[![Build Status](https://travis-ci.org/hlc0000/SwiftlyCache.svg?branch=master)](https://travis-ci.org/hlc0000/SwiftlyCache)
![](https://img.shields.io/cocoapods/p/SwiftlyCache.svg?style=flat)
![](https://img.shields.io/cocoapods/v/SwiftlyCache.svg?style=flat)

SwiftlyCache是用Swift 5编写的一个线程安全的iOS通用缓存库。

特性:
==============

-  支持所有遵守Codable协议的数据类型
-  支持LRU淘汰算法
-  当收到内存警告或者App进入后台时,内存缓存可以配置为自动清空或者手动清空
-  当App进入后台时,磁盘缓存可以配置为自动移除过期数据或者手动移除过期数据
-  支持使用Subscript，使读写数据更加方便
- 提供了MultiCacheGennerator、MemoryCacheGenerator、DiskCacheGenerator用于支持for..in、
  flapmap、map、filter等方法
  
  使用方法:
  =============
  Step1:通过使用pod 'SwiftlyCache'下载并导入框架
  
  Step2: 或者使用手动将SwiftlyCache文件夹拖入到工程里面
  
  基本的接口使用方式:
  --------------------------
  只要是所有遵守Codable协议的数据类型都可以作为缓存对象
  
cache初始化:
  let cache = MultiCache<String>()
  
  set:
  
  最简单的设置缓存对象的形式(fin为Bool)
  let fin =cache.set(forKey: "3", value: "7")
  
  设置缓存对象的时候顺便把缓存对象的大小作为参数传入,用于记录所有缓存对象的总大小,当缓存总大小超出指定值时,缓存会移除部分数据(cost:默认值为0)
  cache.set(forKey: "3", value: "7", cost: 5)
  
  //异步缓存对象(cost:默认值为0)
  cache.set(forKey: "3", value: "7", cost: 5) { (key, fin) in}
  
  异步缓存对象
  cache.set(forKey: "3", value: "7") { (key, fin) in}

  
  
  


