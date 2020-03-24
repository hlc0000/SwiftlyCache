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
  Step1:通过使用pod 'SwiftlyCache'下载并导入框架
  
  Step2: 或者使用手动将SwiftlyCache文件夹拖入到工程里面
  
更多测试代码和用例见 SwiflyCacheDemo

相关链接:
==============
[SwiftlyCache实现](https://juejin.im/post/5e7084886fb9a07c7b784f7f)
  

  
  
  


