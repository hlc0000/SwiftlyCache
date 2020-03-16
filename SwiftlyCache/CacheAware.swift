//
//  CacheAware.swift
//  HummingBird
//
//  Created by 黄琳川 on 2020/2/10.
//  Copyright © 2020 黄琳川. All rights reserved.
//

import Foundation

protocol CacheAware {
    associatedtype Value
    
    func set(forKey key:String,value:Value?,cost:vm_size_t)->Bool
    func set(forKey key:String,value:Value?,cost:vm_size_t,completionHandler:@escaping((_ key:String,_ finished:Bool) -> Void))
    
    func object(forKey key:String)->Value?
    func object(forKey key:String,completionHandler:@escaping((_ key:String,_ value:Value?) -> Void))
    
    func isExistsObjectForKey(forKey key:String)->Bool
    func isExistsObjectForKey(forKey key:String,completionHandler:@escaping((_ key:String,_ contain:Bool) -> Void))
    
    func removeAll()
    func removeAll(completionHandler:@escaping(() -> Void))
    
    func removeObject(forKey key:String)
    func removeObject(forKey key:String,completionHandler:@escaping(() -> Void))
}


