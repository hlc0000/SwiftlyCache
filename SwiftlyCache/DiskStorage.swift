//
//  DiskStorage.swift
//  HummingBird
//
//  Created by 黄琳川 on 2019/12/23.
//  Copyright © 2019 黄琳川. All rights reserved.
//

import Foundation
import SQLite3
import CommonCrypto

class DiskStorageItem{
    var key:String?
    var data:Data?
    var filename:String?
    var size:Int32 = 0
    var accessTime:Int32 = 0
}

fileprivate extension Date{
    var timeStamp:Int{
       return Int(timeIntervalSince1970)
    }
}

fileprivate extension String {
    var md5:String {
        let utf8 = cString(using: .utf8)
        var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
        CC_MD5(utf8, CC_LONG(utf8!.count - 1), &digest)
        return digest.reduce("") { $0 + String(format:"%02x", $1) }
    }
}

class DiskStorage<Value:Codable>{
       let dbFileName = "default.sqlite"
       let dbWalFileName = "default.sqlite-wal"
       let dbShmFileName = "default.sqlite-shm"
       let foldername = "data"
       var filePath:String
       var dbPath:String
       var db:OpaquePointer?
       let dataMaxSize = 1024 * 20
       var dbStmtCache:Dictionary = [String:OpaquePointer]()
       let fileManager:FileManager = FileManager.default
       init(path:String) {
        filePath = path
        dbPath = filePath
        filePath = filePath + ("/\(foldername)")
    }
    
      convenience init(currentPath:String){
        self.init(path: currentPath)
        guard createDirectory() else{ return }
        guard dbOpen() else{ return }
        guard dbCreateTable() else{ return }
    }
    
    deinit {
        dbClose()
    }
    
    /**
     md5
     */
    func makeFileName(forKey key:String)->String{
        return key.md5
    }
    
    /**
     创建文件夹
     */
    func createDirectory()->Bool{
        do{
            try fileManager.createDirectory(atPath: self.filePath, withIntermediateDirectories: true, attributes: nil)
        }catch{
            print("Failed to create folder \(error.localizedDescription)")
            return false
        }
        return true
    }
    
    /**
     拼接文件路径
     */
    func appendingPath(filename:String)->String{
        let path = self.filePath
        return path + ("/\(filename)")
    }
    
    /**
     判断是否存在该文件
     */
    func isfileExists()->Bool{
        return fileManager.fileExists(atPath: self.filePath)
    }
    
    /**
     创建文件并写入数据
     filename 通过md5后作为文件名
     */
    func createFile(filename:String?,data:Data) -> Bool{
        if let filename = filename{
            let path = appendingPath(filename: filename)
            if ((try? data.write(to: URL(fileURLWithPath: path))) != nil) { return true }
        }
        return false
    }
    
    /**
     读取指定文件数据
     @param filename: 文件名
     @return 根据指定路径成功读取到数据后直接把数据返回,否则返回nil
     */
    func readData(filename:String)->Data?{
        let path = appendingPath(filename: filename)
        guard let data = fileManager.contents(atPath: path) else{ return nil }
        return data
    }
    
    /**
     根据key移除指定数据
     @param key:与value关联的key
     @return 移除成功返回true,否则返回false
     */
    @discardableResult
    func removeObject(key:String)->Bool{
        if let filename = self.dbGetFilename(key: key){
            removeFile(filename: filename)
        }
        return  self.dbRemoveItem(key: key)
    }
    
    /**
     移除指定文件
     @param filename: 指定文件名
     @return 移除成功返回true,否则返回false
     */
    @discardableResult
    func removeFile(filename:String) -> Bool{
        let path = appendingPath(filename: filename)
        if ((try? fileManager.removeItem(atPath: path)) == nil) { return false }
        return true
    }
    
    /**
     移除全部文件数据
     */
    func removeAll(){
        if !dbRemoveAllItem(){ return }
        if dbStmtCache.count > 0{ dbStmtCache.removeAll(keepingCapacity: true) }
        if !dbClose() { return }
        if ((try? fileManager.removeItem(atPath: self.filePath)) == nil) { return }
        if !createDirectory() { return }
        if !dbOpen() { return }
        if !dbCreateTable() { return }
    }
    
    /**
     获取文件大小
     */
    func fileSize(filename:String) -> UInt64{
        let path = appendingPath(filename: filename)
        guard let attr = try? fileManager.attributesOfItem(atPath: path) else{ return 0 }
        let fileSize = Double((attr as NSDictionary).fileSize())
        return UInt64(fileSize)
    }
    
    /**
     获取文件总的大小
     */
    func fileTotalSize() throws -> UInt64 {
      var size: UInt64 = 0
      let contents = try fileManager.contentsOfDirectory(atPath: self.filePath)
      for pathComponent in contents {
        let filePath = NSString(string: self.filePath).appendingPathComponent(pathComponent)
        let attributes = try fileManager.attributesOfItem(atPath: filePath)
        if let fileSize = attributes[.size] as? UInt64 { size += fileSize }
      }
      return size
    }
    
    
    /**
     打开数据库
     */
    func dbOpen() ->Bool{
        guard sqlite3_open(dbPath + ("/\(dbFileName)"), &db) == SQLITE_OK else{ return false }
        return true
    }
    
    /**
     关闭数据库
     */
    @discardableResult
    func dbClose()->Bool{
        var isCont = true
        guard db == nil else{
            let result = sqlite3_close(db)
            if result == SQLITE_BUSY || result == SQLITE_LOCKED{
                var stmt:OpaquePointer?
                while isCont {
                    stmt = sqlite3_next_stmt(db, nil)
                    if stmt != nil{
                        sqlite3_finalize(stmt)
                    }else{ isCont = false }
                }
            }else if result != SQLITE_OK{
                print("sqlite close failed \(String(describing: String(validatingUTF8: sqlite3_errmsg(db))))")
                return false
            }
            db = nil
            return true
        }
        return true
    }
    
    /**
     创建数据库表
     */
    func dbCreateTable() -> Bool{
        let sql = "pragma journal_mode = wal; pragma synchronous = normal; create table if not exists detailed (key text primary key,filename text,inline_data blob,size integer,last_access_time integer); create index if not exists last_access_time_idx on detailed(last_access_time);"
        guard dbExcuSql(sql: sql) else{ return false }
        return true
    }
    
    
    @discardableResult
    func dbExcuSql(sql:String) -> Bool{
        guard sqlite3_exec(db,sql.cString(using: .utf8),nil,nil,nil) == SQLITE_OK else{
            print("sqlite exec error \(String(describing: String(validatingUTF8: sqlite3_errmsg(db))))")
            return false
        }
        return true
    }
    
    /**
     保存数据
     @param key: value关联的键
     @param value: 要缓存的数据对象
     @param filename:文件名称(如果为nil，则缓存到数据库,否则value则写入到文件中，元数据则写入数据库中)
     @return 缓存成功返回true,否则返回false
     */
    @discardableResult
    func save(forKey key:String,value:Data,filename:String?)->Bool{
        if filename != nil{
            guard createFile(filename: filename, data: value) else{ return false }
            guard dbSave(forKey: key, value: value, filename: filename) else { removeFile(filename: filename!); return false }
            return true
        }
        if let currentFilename = dbGetFilename(key: key){ removeFile(filename: currentFilename) }
        guard dbSave(forKey: key, value: value, filename: filename) else { return false }
        return true
    }
    
    func dbSave(forKey key:String,value:Data,filename:String?)->Bool{
            let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            let sql = "insert or replace into detailed" + "(key,filename,inline_data,size,last_access_time)" + "values(?1,?2,?3,?4,?5);"
            guard let stmt = dbPrepareStmt(sql: sql) else{ return false }
            sqlite3_bind_text(stmt, 1, key.cString(using: .utf8), -1, SQLITE_TRANSIENT)
            if let filename = filename{
                sqlite3_bind_text(stmt, 2, filename, -1, SQLITE_TRANSIENT)
                sqlite3_bind_blob(stmt, 3, nil, 0, SQLITE_TRANSIENT)
            }else{
                sqlite3_bind_text(stmt, 2, nil, -1, SQLITE_TRANSIENT)
                sqlite3_bind_blob(stmt,3,[UInt8](value),Int32(value.count),SQLITE_TRANSIENT)
            }
            sqlite3_bind_int(stmt, 4, Int32(value.count))
            sqlite3_bind_int(stmt, 5,Int32(Date().timeStamp))
            guard sqlite3_step(stmt) == SQLITE_DONE else{
                print("sqlite insert error \(String(describing: String(validatingUTF8: sqlite3_errmsg(db))))")
                return false
            }
        return true
    }
    
    /**
     根据sql语句查询对应的stmt
     @param sql: sql语句
     */
    func dbPrepareStmt(sql:String) -> OpaquePointer?{
        guard sql.count != 0 || dbStmtCache.count != 0 else{ return nil }
        var stmt:OpaquePointer? = dbStmtCache[sql]
        guard stmt != nil else{
            if sqlite3_prepare_v2(db, sql.cString(using: .utf8), -1, &stmt, nil) != SQLITE_OK{
                print("sqlite stmt prepare error \(String(describing: String(validatingUTF8: sqlite3_errmsg(db))))")
                return nil
            }
            dbStmtCache[sql] = stmt
            return stmt
        }
        sqlite3_reset(stmt)
        return stmt
    }
    
    /**
     根据指定key获取对应的数据并更新最后访问时间
     @return 获取到对应的数据后则使用DiskStorageItem进行封装后返回
     */
    func dbGetItemForKey(forKey key:String)->DiskStorageItem?{
        guard let item = dbQuery(forKey: key) else{ return nil }
        dbUpdataLastAccessTime(key: key)
        if let filename = item.filename{
            item.data = readData(filename: filename) }
        return item
    }
    
    
    /**
     使用DiskStorageItem进行数据的封装
     @return 返回封装后的item
     */
    func dbGetItemFromStmt(stmt:OpaquePointer?)->DiskStorageItem{
        let item = DiskStorageItem()
        let currentKey = String(cString: sqlite3_column_text(stmt, 0))
        if let name = sqlite3_column_text(stmt, 1){
            let filename = String(cString: name)
            item.filename = filename
        }
        let size = sqlite3_column_int(stmt, 3)
        if let blob = sqlite3_column_blob(stmt, 2){ item.data = Data(bytes: blob, count: Int(size)) }
        let last_access_time = sqlite3_column_int(stmt, 4)
        item.key = currentKey
        item.size = size
        item.accessTime = last_access_time
        return item
    }
    
    /**
     根据指定key查询对应数据
     @return 如果没有找到对应的数据,则返回nil
     */
    func dbQuery(forKey key:String) -> DiskStorageItem?{
        let sql = "select key,filename,inline_data,size,last_access_time from detailed where key=?1;"
        guard let stmt = dbPrepareStmt(sql: sql) else { return nil }

        /**
        如果第5个参数传递 nil 或者 SQLITE_STATIC ，SQlite 会假定这块 buffer 是静态内存，所以SQlite放手不管
        如果第5个参数传递的是 SQLITE_TRANSIENT，则SQlite会在内部复制这块buffer的内容。这就允许客户应用程序在调用完 bind 函数之后，立刻释放这块 buffer（或者是一块栈上的 buffer 在离开作用域之后自动销毁）。SQlite会自动在合适的时机释放它内部复制的这块 buffer
        由于在 SQLite.h 中 SQLITE_TRANSIENT 是以宏的形式定义的，而在 swift 中无法直接利用宏传递函数指针，因此需要使用以下代码转换一下
        */
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(stmt, 1, key.cString(using: .utf8), -1, SQLITE_TRANSIENT)
        guard sqlite3_step(stmt) == SQLITE_ROW else {
            return nil
        }
        let item = dbGetItemFromStmt(stmt: stmt)
        return item
    }
    
    /**
     获取所有数据key
     @return 如果没有获取到则返回一个空数组
     */
    func dbGetAllkey()->[String]{
        var keys = [String]()
        let sql = "select key from detailed;"
        guard let stmt = dbPrepareStmt(sql: sql) else { return keys }
        repeat{
            let result = sqlite3_step(stmt)
            if result == SQLITE_ROW{
                let key = String(cString: sqlite3_column_text(stmt,0))
                keys.append(key)
            }else if result == SQLITE_DONE{
                break
            }else{
                print("sqlite query keys error \(String(describing: String(validatingUTF8: sqlite3_errmsg(db))))")
                break
            }
        }while(true)
        return keys
    }
    
    /**
     根据key获取数据的文件名
     @return 如果没有找到指定文件名，则返回nil
     */
    func dbGetFilename(key:String)->String?{
        let sql = "select filename from detailed where key = ?1;"
        guard let stmt = dbPrepareStmt(sql: sql) else { return nil }
        sqlite3_bind_text(stmt, 1, key.cString(using: .utf8), -1, nil)
        guard sqlite3_step(stmt) == SQLITE_ROW else{
            return nil
        }
        guard let filename = sqlite3_column_text(stmt, 0) else{ return nil }
        return String(cString: filename)
    }
    
    /**
     移除所有过期数据
     @return 移除成功返回true,否则返回false
     */
    func dbRemoveAllExpiredData(time:TimeInterval)->Bool{
        let filenames = dbGetExpiredFiles(time: time)
        for filename in filenames { removeFile(filename:filename) }
        if dbRemoveExpired(time: time){ dbCheckpoint();return true }
        return false
    }
    
    /**
     直接把日志数据同步到数据库中
     */
    func dbCheckpoint(){
        sqlite3_wal_checkpoint(db, nil);
    }
    
    /**
     获取过期文件名
     @return 如果没有获取到不为nil的文件名，则返回一个空的数组
     */
    func dbGetExpiredFiles(time:TimeInterval)->[String]{
        var filenames = [String]()
        let sql = "select filename from detailed where last_access_time < ?1 and filename is not null;"
        guard let stmt = dbPrepareStmt(sql: sql) else { return filenames }
        sqlite3_bind_int(stmt,1,Int32(time))
        repeat{
            let result = sqlite3_step(stmt)
            if result == SQLITE_ROW{
                let filename = String(cString: sqlite3_column_text(stmt,0))
                filenames.append(filename)
            }else if result == SQLITE_DONE{ break }else{
                print("sqlite query expired file error \(String(describing: String(validatingUTF8: sqlite3_errmsg(db))))")
                break
            }
        }while(true)
        return filenames
    }
    
    /**
     移除数据库中过期的数据
     @return 移除成功返回true,否则返回false
     */
    func dbRemoveExpired(time:TimeInterval)->Bool{
        let sql = "delete from detailed where last_access_time < ?1;"
        guard let stmt = dbPrepareStmt(sql: sql) else { return false }
        sqlite3_bind_int(stmt, 1, Int32(time))
        guard sqlite3_step(stmt) == SQLITE_DONE else{
            print("sqlite remove expired data error \(String(describing: String(validatingUTF8: sqlite3_errmsg(db))))")
            return false
        }
        return true
    }

    
    func dbGetSizeExceededValueFromStmt(stmt:OpaquePointer?)->DiskStorageItem{
        let item = DiskStorageItem()
        let currentKey = String(cString: sqlite3_column_text(stmt, 0))
        if let name = sqlite3_column_text(stmt, 1){
            let filename = String(cString: name)
            item.filename = filename
        }
        let size = sqlite3_column_int(stmt, 2)
        item.key = currentKey
        item.size = size
        return item
    }
    
    /**
     删除超过指定大小的值
     */
    func dbGetSizeExceededValues()->[DiskStorageItem?]{
        let sql = "select key,filename,size from detailed order by last_access_time asc limit ?1;"
        let stmt = dbPrepareStmt(sql: sql)
        let count = 16
        var items = [DiskStorageItem]()
        sqlite3_bind_int(stmt, 1, Int32(count))
        repeat{
            let result = sqlite3_step(stmt)
            if result == SQLITE_ROW{
                let item = dbGetSizeExceededValueFromStmt(stmt: stmt)
                items.append(item)
            }else if result == SQLITE_OK{ break }
            else{ break }
        }while true
        return items
    }
    
    /**
    根据key查询是否存在对应的值
    @param key: value关联的键
    @return 查询成功返回true,否则返回false
     */
    func dbIsExistsForKey(forKey key:String) -> Bool{
        let sql = "select count(key) from detailed where key = ?1"
        guard let stmt = dbPrepareStmt(sql: sql) else { return false }
        sqlite3_bind_text(stmt, 1, key.cString(using: .utf8), -1, nil)
        guard sqlite3_step(stmt) == SQLITE_ROW else{
            return false
        }
        return Int(sqlite3_column_int(stmt, 0)) > 0
    }
    
    /**
     @return 获取数据总大小
     */
    func dbTotalItemSize() -> Int32{
        let sql = "select sum(size) from detailed;"
        guard let stmt = dbPrepareStmt(sql: sql) else { return -1 }
        guard sqlite3_step(stmt) == SQLITE_ROW else{
            return -1
        }
        return Int32(sqlite3_column_int(stmt, 0))
    }
    
    /**
     @return 获取数据总个数
     */
    func dbTotalItemCount()->Int{
        let sql = "select count(*) from detailed;"
        guard let stmt = dbPrepareStmt(sql: sql) else { return -1 }
        guard sqlite3_step(stmt) == SQLITE_ROW else{
            return -1
        }
        return Int(sqlite3_column_int(stmt, 0))
    }
    
    /**
     根据key更新最后访问时间
     */
    func dbUpdataLastAccessTime(key:String){
        let sql = "update detailed set last_access_time=?1 where key=?2;"
        guard let stmt = dbPrepareStmt(sql: sql) else { return }
        sqlite3_bind_int(stmt, 1, Int32(Date().timeStamp))
        sqlite3_bind_text(stmt, 2, key.cString(using: .utf8), -1, nil)
        guard sqlite3_step(stmt) == SQLITE_DONE else{
            print("sqlite update accessTime error \(String(describing: String(validatingUTF8: sqlite3_errmsg(db))))")
            return
        }
    }
    
    /**
     移除key指定数据
     @return 成功返回true，否则返回false
     */
    func dbRemoveItem(key:String)->Bool{
        //删除sql语句
        let sql = "delete from detailed where key = ?1";
        guard let stmt = dbPrepareStmt(sql: sql) else { return false}
        sqlite3_bind_text(stmt, 1, key.cString(using: .utf8), -1, nil)
        //step执行
        guard sqlite3_step(stmt) == SQLITE_DONE else{
            print("sqlite remove data error \(String(describing: String(validatingUTF8: sqlite3_errmsg(db))))")
            return false
        }
        return true
    }
    
    func dbRemoveAllItem()->Bool{
        //删除sql语句
        let sql = "delete from detailed";
        guard let stmt = dbPrepareStmt(sql: sql) else { return false}
        //step执行
        guard sqlite3_step(stmt) == SQLITE_DONE else{
            print("sqlite remove data error \(String(describing: String(validatingUTF8: sqlite3_errmsg(db))))")
            return false
        }
        return true
    }
}



