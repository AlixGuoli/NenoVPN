//
//  ConnectionStatusCenter.swift
//  NeonVPN
//
//  Created by Stephen Schaaf on 2025/11/18.
//

import Foundation

/// 轻量级的全局连接状态存储，供非 VM 模块查询。
final class ConnectionStatusCenter {
    
    static let shared = ConnectionStatusCenter()
    
    private let queue = DispatchQueue(label: "com.neonvpn.connection.center", attributes: .concurrent)
    private var _stage: ConnectVM.Stage = .disconnected
    
    private init() {}
    
    var stage: ConnectVM.Stage {
        queue.sync { _stage }
    }
    
    var isConnected: Bool {
        stage == .connected
    }
    
    var isConnecting: Bool {
        stage == .connecting
    }
    
    func update(stage: ConnectVM.Stage) {
        queue.async(flags: .barrier) {
            self._stage = stage
        }
    }
}

