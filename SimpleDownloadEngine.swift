//
//  SimpleDownloadEngine.swift
//  RobotApp
//
//  Created by 赵磊 on 2018/12/4.
//  Copyright © 2018 zhaolei. All rights reserved.
//

import UIKit

protocol SimpleDownloadDelegate {
    func didFinishDownload(succ:Bool, type:Int, totalBytes:Int, costTime:Double)
}

class SimpleDownloadEngine: NSObject {
    
    private var type = 0
    private var startTime: Double = 0.000
    private lazy var session:URLSession = {
        let config = URLSessionConfiguration.default
        let currentSession = URLSession(configuration: config, delegate: self,
                                        delegateQueue: OperationQueue.main)
        return currentSession
        
    }()
    var delegate: SimpleDownloadDelegate?
    
    //下载文件
    func sessionSeniorDownload(){
        
        let url = "下载链接"
        let request = URLRequest(url: URL(string: url)!)
        let downloadTask = session.downloadTask(with: request)
        
        //使用resume方法启动任务
        startTime = CFAbsoluteTimeGetCurrent()
        downloadTask.resume()
    }
    
    //获取文件大小(Bytes)
    func getSize(url: URL)->UInt64
    {
        var fileSize : UInt64 = 0
        
        do {
            let attr = try FileManager.default.attributesOfItem(atPath: url.path)
            fileSize = attr[FileAttributeKey.size] as! UInt64
            
            let dict = attr as NSDictionary
            fileSize = dict.fileSize()
        } catch {
            print("Error: \(error)")
        }
        
        return fileSize
    }
    
}

extension SimpleDownloadEngine: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        
        let size = getSize(url: URL(string: location.path)!)
        let time = CFAbsoluteTimeGetCurrent()-startTime
        delegate?.didFinishDownload(succ: true, type: type, totalBytes: Int(size), costTime: time)
        
        print("download finished size:\(size)bytes, time:\(time)ms")
        
        if type == 0 {
            type = 1
            sessionSeniorDownload()
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        
        print("bytesWritten/totalBytesWritten/totalBytesExpectedToWrite:\(Double(bytesWritten))/\(Double(totalBytesWritten))/\(Double(totalBytesExpectedToWrite))")
    }
    
}
