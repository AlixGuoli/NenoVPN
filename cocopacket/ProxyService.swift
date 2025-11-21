//
//  NetSocks.swift
//  NeonVPN
//
//  Created by Stephen Schaaf on 2025/11/18.
//

import Foundation
import os

public enum ProxyService {
    
    @discardableResult
    public static func launchBridge(withConfig configPath: String) -> Int32 {
        logMessage("[PROXY] [Service] 启动代理服务，配置路径: \(configPath)")
        
        guard let tunnelFD = self.locateBridgeFD else {
            logMessage("[PROXY] [Service] 获取隧道文件描述符失败")
            fatalError("Get tunnel file descriptor failed.")
        }
        
        let status = SantiProxyServiceLaunch(configPath.cString(using: .utf8), tunnelFD)
        logMessage("[PROXY] [Service] 代理服务启动结果: \(status == 0 ? "成功" : "失败")")
        
        return status
    }
    
    public static func shutdownBridge() {
        logMessage("[PROXY] [Service] 停止代理服务")
        SantiProxyServiceShutdown()
        logMessage("[PROXY] [Service] 代理服务已停止")
    }
    
    private static var locateBridgeFD: Int32? {
        logMessage("[PROXY] [Service] 查找隧道文件描述符")
        
        var bridgeInfo = bridge_ctl_block()
        withUnsafeMutablePointer(to: &bridgeInfo.bridge_name) {
            $0.withMemoryRebound(to: CChar.self, capacity: MemoryLayout.size(ofValue: $0.pointee)) {
                _ = strcpy($0, "com.apple.net.utun_control")
            }
        }
        
        for fileDesc: Int32 in 0...1024 {
            var bridgeAddr = bridge_sock_info()
            var result: Int32 = -1
            var addrLen = socklen_t(MemoryLayout.size(ofValue: bridgeAddr))
            withUnsafeMutablePointer(to: &bridgeAddr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    result = getpeername(fileDesc, $0, &addrLen)
                }
            }
            if result != 0 || bridgeAddr.bridge_type != AF_SYSTEM {
                continue
            }
            if bridgeInfo.bridge_id == 0 {
                result = ioctl(fileDesc, BRIDGE_IOCTL_INFO, &bridgeInfo)
                if result != 0 {
                    continue
                }
            }
            if bridgeAddr.bridge_id == bridgeInfo.bridge_id {
                logMessage("[PROXY] [Service] 找到文件描述符: \(fileDesc)")
                return fileDesc
            }
        }
        logMessage("[PROXY] [Service] 查找文件描述符失败")
        return nil
    }
}
