//
//  PacketTunnelProvider.swift
//  cocopacket
//
//  Created by Stephen Schaaf on 2025/9/19.
//

import NetworkExtension
import os

class PacketTunnelProvider: NEPacketTunnelProvider {
    
    private var wireConductor : WireConductor? = nil
    
    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        // Add code here to start the process of connecting the tunnel.
        igniteWireConductor()
        completionHandler(nil)
    }
    
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        // Add code here to start the process of stopping the tunnel.
        wireConductor?.haltPipeline()
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
    
    func igniteWireConductor(){
        if wireConductor == nil{
            wireConductor = WireConductor(packetFlow: packetFlow)
        }
        wireConductor?.tunnelSettingsHandler = { [weak self] settings, completion in
            self?.setTunnelNetworkSettings(settings, completionHandler: completion)
        }
        wireConductor?.bootPipeline()
    }
}
