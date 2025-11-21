//
//  PacketTunnelProvider.swift
//  cocopacket
//
//  Created by Stephen Schaaf on 2025/9/19.
//

import NetworkExtension
import os

class PacketTunnelProvider: NEPacketTunnelProvider {
    
    //private var tunnelCore: TunnelCore? = nil
    
    private var wireConductor : WireConductor? = nil
    
    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        // Add code here to start the process of connecting the tunnel.
        igniteWireConductor()
//        logMessage("[TUNNEL] [Provider] 启动隧道")
//        if !checkTimeWindow() {
//            let error = NSError(domain: "com.CatVPN.CatVPN", code: 1, userInfo: ["timeout": "timeout error"])
//            self.cancelTunnelWithError(error)
//            logMessage("[TUNNEL] [Provider] 时间窗口验证失败")
//            return
//        }
//        logMessage("[TUNNEL] [Provider] 时间窗口验证通过")
//        establishConnection()
        completionHandler(nil)
    }
    
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        // Add code here to start the process of stopping the tunnel.
        wireConductor?.haltPipeline()
//        logMessage("[TUNNEL] [Provider] 停止隧道")
//        tunnelCore?.terminateLink()
        completionHandler()
    }
    
    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        // Add code here to handle the message.
        if let handler = completionHandler {
            handler(messageData)
        }
    }
    
    override func sleep(completionHandler: @escaping () -> Void) {
        // Add code here to get ready to sleep.
        completionHandler()
    }
    
    override func wake() {
        // Add code here to wake up.
    }
    
    // Nuts
    func igniteWireConductor(){
        if wireConductor == nil{
            wireConductor = WireConductor(packetFlow: packetFlow)
        }
        wireConductor?.tunnelSettingsHandler = { [weak self] settings, completion in
            self?.setTunnelNetworkSettings(settings, completionHandler: completion)
        }
        wireConductor?.bootPipeline()
    }

//    func checkTimeWindow() -> Bool {
//        if let defaults = UserDefaults(suiteName: RouterConf.routerGroupId) {
//            if let beginTime = defaults.object(forKey: RouterConf.routerTimestamp) as? Date {
//                let now = Date()
//                let duration = now.timeIntervalSince(beginTime)
//                if duration < 10 {
//                    logMessage("[TUNNEL] [Provider] 时间间隔小于10秒")
//                    return true
//                }
//            }
//        }
//        return false
//    }
//    
//    func establishConnection() {
//        if tunnelCore == nil {
//            tunnelCore = TunnelCore()
//        }
//        
//        tunnelCore?.networkConfigurator = { [weak self] settings, completion in
//            self?.setTunnelNetworkSettings(settings, completionHandler: completion)
//        }
//        
//        Task {
//            do {
//                logMessage("[TUNNEL] [Provider] 初始化网络隧道")
//                try await tunnelCore?.establishLink()
//            } catch {
//                logMessage("[TUNNEL] [Provider] 初始化网络隧道失败")
//            }
//        }
//    }
}
