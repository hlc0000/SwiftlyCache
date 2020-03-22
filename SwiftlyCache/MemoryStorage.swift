//
//  MemoryStorage.swift
//  HummingBird
//
//  Created by 黄琳川 on 2019/12/23.
//  Copyright © 2019 黄琳川. All rights reserved.
//

import Foundation

class LinkedNode<Value:Codable>:Equatable{
    static func == (lhs: LinkedNode<Value>, rhs: LinkedNode<Value>) -> Bool {
        return lhs.key == rhs.key
    }
    var key:String
    var object:Value
    var cost:vm_size_t
    weak var prev:LinkedNode?
    weak var next:LinkedNode?
    
    init(key:String,object:Value,cost:vm_size_t) {
        self.key = key
        self.object = object
        self.cost = cost
    }
}

class MemoryStorage<Value:Codable>{
    var head:LinkedNode<Value>?
    var tail:LinkedNode<Value>?
    var totalCostLimit:vm_size_t = 0
    var totalCountLimit:vm_size_t = 0
    var dic = [String:LinkedNode<Value>]()
    typealias Element = (String,Value)
    var currentNode:LinkedNode<Value>?
    
    /**
     插入数据
     @param node:缓存对象
     */
    func insertNodeAtHead(node:LinkedNode<Value>){
        totalCostLimit+=node.cost
        totalCountLimit+=1
        if head == nil{
            head = node
            tail = head
        }else{
            node.next = head
            head?.prev = node
            head = node
            
        }
    }
    
    /**
     移除最后的节点
     */
    @discardableResult
    func removeTailNode()->Bool{
        if tail == nil{
            head = tail
            totalCostLimit = 0
            totalCountLimit = 0
            return false
        }else{
            if let currentKey = tail?.key{
                if let node = dic.removeValue(forKey: currentKey){
                    tail?.prev?.next = nil
                    tail = tail?.prev
                    node.prev = nil
                    node.next = nil
                    totalCostLimit -= node.cost
                    totalCountLimit -= 1
                    return true
                }
            }
        }
        return false
    }
    
    /**
     移动节点
     */
    func moveNode(node:LinkedNode<Value>){
        if head == node{ return }
        if tail == node{
            //在链表尾部
            node.prev?.next = nil
            tail = node.prev
            node.next = head
            head?.prev = node
            head = node
        }else{
            //在链表中间
            node.prev?.next = node.next
            node.next?.prev = node.prev
            node.next = head
            head?.prev = node
            head = node
        }
    }
    
    
    func removeObject(node:LinkedNode<Value>){
        guard head != nil else{ return }
        if node.prev != nil && node.next != nil{
            node.prev?.next = node.next
            node.next?.prev = node.prev
            totalCostLimit -= node.cost
            totalCountLimit -= 1
            node.prev = nil
            node.next = nil
            dic.removeValue(forKey: node.key)
        }else if node.prev == nil{
            head = node.next
            node.next = nil
            node.prev = nil
            head?.prev = nil
            dic.removeValue(forKey: node.key)
        }else if node.next == nil{
            removeTailNode()
        }
    }
    
    func removeAllObject(){
        totalCountLimit = 0
        totalCostLimit = 0
        head = nil
        tail = nil
        currentNode = nil
        if dic.count>0{ self.dic.removeAll(keepingCapacity: true) }
    }
    
    func setCurrentNode(){
        currentNode = head
    }
    
   func next()->LinkedNode<Value>?{
        let node = currentNode
        currentNode = currentNode?.next
        return node
    }
}

