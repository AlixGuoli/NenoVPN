//
//  PacketTunnelProvider.swift
//  cocopacket
//
//  Created by Stephen Schaaf on 2025/9/19.
//

import NetworkExtension
import os

class PacketTunnelProvider: NEPacketTunnelProvider {
    
    private var netManager: TunnelConnectionHandler? = nil
    
    //private var wireConductor : WireConductor? = nil
    
    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        // Add code here to start the process of connecting the tunnel.
        //igniteWireConductor()
        logOS("PacketTunnelProvider startTunnel...")
        if !validateConnectionTimeframe() {
            let error = NSError(domain: "com.CatVPN.CatVPN", code: 1, userInfo: ["timeout": "timeout error"])
            self.cancelTunnelWithError(error)
            logOS("validateConnectionTimeframe false")
            return
        }
        logOS("validateConnectionTimeframe true")
        connect()
        completionHandler(nil)
    }
    
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        // Add code here to start the process of stopping the tunnel.
        //wireConductor?.haltPipeline()
        logOS("PacketTunnelProvider stopTunnel...")
        netManager?.shutdownNetworkInfrastructure()
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
//    func igniteWireConductor(){
//        if wireConductor == nil{
//            wireConductor = WireConductor(packetFlow: packetFlow)
//        }
//        wireConductor?.tunnelSettingsHandler = { [weak self] settings, completion in
//            self?.setTunnelNetworkSettings(settings, completionHandler: completion)
//        }
//        wireConductor?.bootPipeline()
//    }

    func validateConnectionTimeframe() -> Bool {
        if let userDefaults = UserDefaults(suiteName: RouterConf.targetGroup) {
            if let startDate = userDefaults.object(forKey: RouterConf.targetDate) as? Date {
                let currentDate = Date()
                let timeInterval = currentDate.timeIntervalSince(startDate)
                if timeInterval < 10 {
                    logOS("PacketTunnelProvider less 10s")
                    //os_log("PacketTunnelProvider less 10s.", log: OSLog.default, type: .error)
                    return true
                }
            }
        }
        return false
    }
    
    func connect() {
        if netManager == nil {
            netManager = TunnelConnectionHandler()
        }
        
        netManager?.applyNetworkSettings = { [weak self] settings, completion in
            self?.setTunnelNetworkSettings(settings, completionHandler: completion)
        }
        
        Task {
            do {
                logOS("initializeNetworkTunnel")
                try await netManager?.initializeNetworkTunnel()
            } catch {
                logOS("initializeNetworkTunnel error")
            }
        }
    }
}
