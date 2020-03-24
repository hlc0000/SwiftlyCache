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
-  支持使用Subscript，使读写数据更加方便
-  提供了MultiCacheGennerator、MemoryCacheGenerator、DiskCacheGenerator用于支持for..in、
  compactMap、map、filter等方法
  
  使用方法:
  =============
  CocoaPods:
  ------------------------------
  1.在Podfile中添加pod 'SwiftlyCache'
  2.执行pod install或者pod update
  3.导入 SwiftlyCache
  
  手动导入:
  1.下载SwiftlyCache文件夹内所有内容
  2.将SwiftCache内的源文件添加到你的工程
  
更多测试代码和用例见 SwiflyCacheDemo

相关链接:
==============
[SwiftlyCache实现](https://juejin.im/post/5e7084886fb9a07c7b784f7f)
  

  
  
  


