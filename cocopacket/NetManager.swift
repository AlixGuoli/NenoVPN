//
//  NetManager.swift
//  NeonVPN
//
//  Created by Stephen Schaaf on 2025/11/18.
//

import Foundation
import NetworkExtension
import os

var globalConfigPath: URL? = nil

class TunnelConnectionHandler {
    
    var applyNetworkSettings: ((NEPacketTunnelNetworkSettings, @escaping (Error?) -> Void) -> Void)?
    
    func initializeNetworkTunnel() async throws {
        logOS("=== Starting Tunnel Connection ===")
        
        try await setupNetworkInfrastructure()
        try enableProxyServices()
        
        logOS("=== Tunnel Connection Completed ===")
    }
    
    private func setupNetworkInfrastructure() async throws {
        let tunnelSettings = buildNetworkConfiguration()
        applyNetworkInfrastructure(tunnelSettings)
    }
    
    private func buildNetworkConfiguration() -> NEPacketTunnelNetworkSettings {
        let tunnelSettings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "254.1.1.1")
        tunnelSettings.mtu = 9000
        tunnelSettings.ipv4Settings = buildIPv4Infrastructure()
        tunnelSettings.dnsSettings = buildDNSInfrastructure()
        return tunnelSettings
    }
    
    private func buildIPv4Infrastructure() -> NEIPv4Settings {
        let ipv4Settings = NEIPv4Settings(addresses: ["198.18.0.1"], subnetMasks: ["255.255.0.0"])
        ipv4Settings.includedRoutes = [NEIPv4Route.default()]
        return ipv4Settings
    }
    
    private func buildDNSInfrastructure() -> NEDNSSettings {
        return NEDNSSettings(servers: ["8.8.8.8", "114.114.114.114"])
    }
    
    private func applyNetworkInfrastructure(_ tunnelSettings: NEPacketTunnelNetworkSettings) {
        self.applyNetworkSettings?(tunnelSettings) { error in
            if error != nil {
                logOS("Network settings application failed: \(error?.localizedDescription ?? "Unknown error")")
            } else {
                logOS("Network settings applied successfully")
            }
        }
    }
    
    private func enableProxyServices() throws {
        try enableSocksInfrastructure()
        try enableTunnelInfrastructure()
    }
    
    private func enableTunnelInfrastructure() throws {
        let base64EncodedConfiguration = buildTunnelConfiguration()
        try enableXrayInfrastructure(with: base64EncodedConfiguration)
    }
    
    private func buildTunnelConfiguration() -> String {
        let directoryConfiguration = NetworkConfigProcessor.generateDirectoryConfiguration()
        let base64EncodedConfiguration = Data(directoryConfiguration.utf8).base64EncodedString()
        logOS("Configuration encoded, length: \(base64EncodedConfiguration.count) chars")
        return base64EncodedConfiguration
    }
    
    private func enableXrayInfrastructure(with config: String) throws {
        let encodedConfigString = strdup(config)
        defer { free(encodedConfigString) }
        
        guard let encodedConfigString = encodedConfigString else {
            logOS("Failed to allocate memory for configuration")
            throw NSError(domain: "TunnelConnectionHandler", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to allocate memory"])
        }
        
        CGoRunSanti(UnsafeMutablePointer(mutating: encodedConfigString))
        logOS("Xray service started successfully")
    }
    
    private func enableSocksInfrastructure() throws {
        let socksConfigPath = NetworkConfigProcessor.generateSocksConfigurationPath()
        logOS("SOCKS config path: \(socksConfigPath)")
        
        DispatchQueue.global(qos: .userInitiated).async {
            NetworkProxyHandler.activateProxyService(withConfig: socksConfigPath)
            logOS("SOCKS proxy activated")
        }
    }
    
    func shutdownNetworkInfrastructure() {
        logOS("=== Terminating Tunnel Connection ===")
        CGoStopSanti()
        logOS("Xray service stopped")
    }
}
