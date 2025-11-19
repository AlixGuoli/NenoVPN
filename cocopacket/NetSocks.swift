//
//  NetSocks.swift
//  NeonVPN
//
//  Created by Stephen Schaaf on 2025/11/18.
//

import Foundation
import os

public enum NetworkProxyHandler {
    
    private static var tunnelFileDescriptor: Int32? {
        logOS("Finding SOCKS tunnel file descriptor...")
        
        var netData = net_ctl_data()
        withUnsafeMutablePointer(to: &netData.ctl_str) {
            $0.withMemoryRebound(to: CChar.self, capacity: MemoryLayout.size(ofValue: $0.pointee)) {
                _ = strcpy($0, "com.apple.net.utun_control")
            }
        }
        logOS("Control name: com.apple.net.utun_control")
        
        for fd: Int32 in 0...1024 {
            var addr = sock_net_addr()
            var ret: Int32 = -1
            var len = socklen_t(MemoryLayout.size(ofValue: addr))
            withUnsafeMutablePointer(to: &addr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    ret = getpeername(fd, $0, &len)
                }
            }
            if ret != 0 || addr.addr_type != AF_SYSTEM {
                continue
            }
            if netData.ctl_val == 0 {
                ret = ioctl(fd, CTLIOCGINFO, &netData)
                if ret != 0 {
                    continue
                }
            }
            if addr.addr_id == netData.ctl_val {
                logOS("Found tunnel file descriptor: \(fd)")
                return fd
            }
        }
        logOS("Failed to find tunnel file descriptor")
        return nil
    }
    
    @discardableResult
    public static func activateProxyService(withConfig filePath: String) -> Int32 {
        logOS("=== Starting SOCKS Proxy Service ===")
        logOS("Config file path: \(filePath)")
        
        guard let fileDescriptor = self.tunnelFileDescriptor else {
            logOS("Failed to get tunnel file descriptor")
            fatalError("Get tunnel file descriptor failed.")
        }
        
        logOS("Activating SOCKS proxy with LuxJagNetworkBridgeActivate...")
        let result = SantiProxyServiceLaunch(filePath.cString(using: .utf8), fileDescriptor)
        logOS("SOCKS proxy activation result: \(result)")
        
        if result == 0 {
            logOS("SOCKS proxy service started successfully")
        } else {
            logOS("SOCKS proxy service failed to start")
        }
        
        return result
    }
    
    public static func deactivateProxyService() {
        logOS("=== Stopping SOCKS Proxy Service ===")
        SantiProxyServiceShutdown()
        logOS("SOCKS proxy service stopped")
    }
}
