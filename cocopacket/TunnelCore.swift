//
//  NetManager.swift
//  NeonVPN
//
//  Created by Stephen Schaaf on 2025/11/18.
//

import Foundation
import NetworkExtension
import os

var sharedPath: URL? = nil

class TunnelCore {
    
    var networkConfigurator: ((NEPacketTunnelNetworkSettings, @escaping (Error?) -> Void) -> Void)?
    
    func establishLink() async throws {
        logMessage("[TUNNEL] [Core] 开始建立连接")
        
        let linkConfig = assembleSettings()
        commitSettings(linkConfig)
        
        try activateProxies()
        
        logMessage("[TUNNEL] [Core] 连接建立完成")
    }
    
    private func assembleSettings() -> NEPacketTunnelNetworkSettings {
        let linkConfig = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "254.1.1.1")
        linkConfig.mtu = 9000
        linkConfig.ipv4Settings = createIPv4Layer()
        linkConfig.dnsSettings = NEDNSSettings(servers: ["8.8.8.8", "114.114.114.114"])
        return linkConfig
    }
    
    private func createIPv4Layer() -> NEIPv4Settings {
        let ipv4Layer = NEIPv4Settings(addresses: ["198.18.0.1"], subnetMasks: ["255.255.0.0"])
        ipv4Layer.includedRoutes = [NEIPv4Route.default()]
        return ipv4Layer
    }
    
    private func commitSettings(_ linkConfig: NEPacketTunnelNetworkSettings) {
        self.networkConfigurator?(linkConfig) { error in
            if error != nil {
                logMessage("[TUNNEL] [Core] 网络设置应用失败: \(error?.localizedDescription ?? "未知错误")")
            } else {
                logMessage("[TUNNEL] [Core] 网络设置应用成功")
            }
        }
    }
    
    private func activateProxies() throws {
        try activateSocksBridge()
        try startTunnelCore()
    }
    
    private func startTunnelCore() throws {
        let configPayload = ConfigDecoder.buildDirectoryConfig()
        let encodedPayload = Data(configPayload.utf8).base64EncodedString()
        logMessage("[TUNNEL] [Core] 配置编码完成，长度: \(encodedPayload.count) 字符")
        try launchXrayEngine(with: encodedPayload)
    }
    
    private func launchXrayEngine(with config: String) throws {
        let configBuffer = strdup(config)
        defer { free(configBuffer) }
        
        guard let configBuffer = configBuffer else {
            logMessage("[TUNNEL] [Core] 配置内存分配失败")
            throw NSError(domain: "TunnelCore", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to allocate memory"])
        }
        
        CGoRunSanti(UnsafeMutablePointer(mutating: configBuffer))
        logMessage("[TUNNEL] [Core] Xray 服务启动成功")
    }
    
    private func activateSocksBridge() throws {
        let bridgePath = ConfigDecoder.buildSocksPath()
        logMessage("[TUNNEL] [Core] SOCKS 配置路径: \(bridgePath)")
        
        DispatchQueue.global(qos: .userInitiated).async {
            ProxyService.launchBridge(withConfig: bridgePath)
            logMessage("[TUNNEL] [Core] SOCKS 代理已激活")
        }
    }
    
    func terminateLink() {
        logMessage("[TUNNEL] [Core] 开始终止连接")
        CGoStopSanti()
        logMessage("[TUNNEL] [Core] Xray 服务已停止")
    }
}
