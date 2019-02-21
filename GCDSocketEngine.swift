//
//  GCDSocketEngine.swift
//
//  Created by 赵磊 on 2018/12/3.
//  Copyright © 2018 leizhao. All rights reserved.
//

import UIKit

let defaultTimeOut = 5
let defaultHeartbeatInterval = 5
let maxHeartBeatCount = 3

enum GCDSocketConnectStatus: Int {
    case disconnected = 1
    case connecting
    case connected
}

protocol GCDSocketConnectDelegate: class {
    func didConnect(succ:Bool, host: String, port: Int, errorCode: Int?)
    func didReadData(tag:Int, time:Int, port: Int)
}

class GCDSocketEngine: NSObject {
    
    static let shared = GCDSocketEngine()
    
    var socketHost: String = "127.0.0.1"
    var socketPort: Int = 80
    
    var testHeartBeat: Bool = false
    var heartBeatIndex: Int = 0
    let gcdSocket: GCDAsyncSocket
    private var heartBeatTimer: CustomTimer!
    private var heartbeatInterval: Int32
    private var conncectTimeout: Int32
    private var heartBeatStartTime: Double
    
    private let barrierQueue =  DispatchQueue(label: "GCDSocketEngineBarrierQueue")
    private var status = GCDSocketConnectStatus.disconnected
    
    weak var delegate: GCDSocketConnectDelegate?
    
    override init() {
        gcdSocket = GCDAsyncSocket()
        conncectTimeout = Int32(defaultTimeOut)
        heartbeatInterval = Int32(defaultHeartbeatInterval)
        heartBeatStartTime = 0.0
        super.init()
        
        heartBeatTimer = CustomTimer.repeaticTimer(interval: .seconds(Int(heartbeatInterval)), queue: barrierQueue, handler: { [unowned self] timer in
                self.sendHeartBeatRequest()
        })
        
        gcdSocket.setDelegate(self, delegateQueue: DispatchQueue(label: "GCDSocketEngineCallbackQueue"))
    }
    
    open func connectToServer(host: String, port: Int) {
        
        self.socketHost = host
        self.socketPort = port
        
        barrierQueue.async { [unowned self] in
            if self.status != .disconnected {
                return
            }
            
            do {
                print("GCDSocketEngine", "connectToServer \(self.socketHost):\(self.socketPort)")
                try self.gcdSocket.connect(toHost: self.socketHost, onPort: UInt16(self.socketPort), withTimeout: TimeInterval(self.conncectTimeout))
                self.status = .connecting
            } catch {
                print("GCDSocketEngine", "connectToServer|error = \(String(describing: error))")
            }
        }
    }
    
    open func sendHeartBeatRequest() {
        if heartBeatIndex < maxHeartBeatCount {
            print("GCDSocketEngine","sendHeartBeatRequest...")
            heartBeatStartTime = CFAbsoluteTimeGetCurrent()
            gcdSocket.write("msg\(heartBeatIndex+1)-\(Int(Date().timeIntervalSince1970))".data(using: .utf8, allowLossyConversion: false)!, withTimeout: -1, tag: heartBeatIndex)
        } else {
            heartBeatTimer.suspend()
        }
        
    }
    
    open func disconnectToServer() {
        
        print("GCDSocketEngine", "disconnectToServer by app.")
        status = .disconnected
        
        heartBeatTimer.suspend()
        gcdSocket.disconnect()
    }
    
}

// MARK:- GCDAsyncSocketDelegate
extension GCDSocketEngine: GCDAsyncSocketDelegate {
    func socket(_ sock: GCDAsyncSocket, didConnectToHost host: String, port: UInt16) {
        print("GCDSocketEngine", "didConnectToHost|host=\(host), port=\(port)")
        status = .connected
        self.delegate?.didConnect(succ: true, host: host, port: Int(port), errorCode: nil)
        if testHeartBeat {
            heartBeatTimer.start()
        }
    }

    func socketDidDisconnect(_ sock: GCDAsyncSocket, withError err: Error?) {
        print("GCDSocketEngine", "socketDidDisconnect|err=\(String(describing: err))")
        
        status = .disconnected
        
        // 停止心跳包发送
        heartBeatTimer.suspend()
        if let error = err {
            self.delegate?.didConnect(succ: false, host: self.socketHost, port: self.socketPort, errorCode: (error as NSError).code)
        }
    }
    
    func socket(_ sock: GCDAsyncSocket, didWriteDataWithTag tag: Int) {
        print("GCDSocketEngine","didWriteDataWithTag: \(tag)")
        gcdSocket.readData(withTimeout: -1, tag: heartBeatIndex)
    }
    
    func socket(_ sock: GCDAsyncSocket, didRead data: Data, withTag tag: Int) {
        print("GCDSocketEngine","didReadDataWithTag: \(tag), data: \(String(describing: String(data: data, encoding: .utf8)))")
        self.delegate?.didReadData(tag: tag, time: Int((CFAbsoluteTimeGetCurrent()-heartBeatStartTime)*1000), port: socketPort)
        heartBeatIndex += 1
    }
    
}
