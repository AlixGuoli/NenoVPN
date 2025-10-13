//
//  WireConductor.swift
//  NeonVPN
//
//  Created by Stephen Schaaf on 2025/9/23.
//

import Foundation
import NetworkExtension
import os
import CommonCrypto
import Network

// 私有常量与字符串资源分离（仅内部使用，保持行为不变）
private enum _K {
    // 核心常量（重命名混淆）
    static let n0 = "10.10.0.1"                  // 原 tunnelRemoteAddress
    static let n1: NSNumber = 1400               // 原 defaultMTU
    static let n2 = ["8.8.8.8"]                 // 原 defaultDNSServers

    static let k0 = "3e027e48ec6f5a9c705dfe17bed37201" // 原 aesKeyHex
    static let k1 = "hfor1"                      // 原 xorSalt
    static let k2 = 128                           // 原 randomPaddingMax

    // 默认值（仅初始化时使用）
    static let d0 = "49155"                       // 原 defaultRemotePort
    static let d1 = "64.176.43.209"              // 原 defaultRemoteHost
    static let d2 = "us"                          // 原 defaultRegionCode
    static let d3 = "en"                          // 原 defaultLocaleIdentifier
    static let d4 = "com.coco.neno.vpn.fly"          // 原 defaultBundleIdentifier
    static let d5 = "1.0.0"                       // 原 defaultAppVersion

    // 无用常量（诱饵，不参与任何分支或 I/O）
    static let junkSeedA = "_x9pQ0z"
    static let junkSeedB = 0x5A5A5A
    static let junkArray: [UInt8] = [13, 21, 34, 55]
    static let junkIPs = ["127.0.0.2", "0.0.0.0"]
    static let junkDNS = ["1.1.1.1", "9.9.9.9"]
}

class WireConductor {
    var tcpSocket: NWConnection?
    var dispatchWorkQueue: DispatchQueue?
    
    var remoteServerPort = _K.d0
    var remoteServerHost = _K.d1
    
    var regionCode = _K.d2
    var localeIdentifier = _K.d3
    var bundleIdentifier = _K.d4
    var appVersion = _K.d5
    
    var encryptionKey = _K.k0
    var incomingDataBuffer = Data()
    var packetDataBuffer = Data()
    
    var secretKeyString = _K.k1
    var randomPaddingLength = _K.k2
    
    var networkConfigurationHandler: ((NEPacketTunnelNetworkSettings, @escaping (Error?) -> Void) -> Void)?
    var tunnelDataFlow: NEPacketTunnelFlow
    private let log = OSLog(subsystem: "NeonVPN", category: "WireConductor")
    private let logPrefix = "[NEON][Tunnel]"
    private func logInfo(_ message: String) { os_log("%{public}@ %{public}@", log: log, type: .error, logPrefix, message) }
    private func logError(_ message: String) { os_log("%{public}@ %{public}@", log: log, type: .error, logPrefix, message) }
    
    init(packetFlow: NEPacketTunnelFlow) {
        self.tunnelDataFlow = packetFlow
    }
}

// MARK: - 对外 API（保持签名不变）

extension WireConductor {
    func igniteWire() {
        logInfo("➡️ 启动连接流程 host=\(remoteServerHost) port=\(remoteServerPort) 区域=\(regionCode) 语言=\(localeIdentifier)")
        _bs_startWire()
    }
    
    func onWireState(_ connectionState: NWConnection.State) {
        _bs_onState(connectionState)
    }
    
    func shutdownWire() {
        logInfo("🛑 终止隧道连接")
        tcpSocket?.cancel()
    }
    
    func createAuthenticationPayload() -> Data? {
        return _au_payload()
    }
    func applyDataObfuscation(data: Data, key: Data) -> Data {
        return _cc_obfuscate(data, key: key)
    }
    func reverseDataObfuscation(data: Data, key: Data) -> Data {
        return _cc_reveal(data, key: key)
    }
    func extractAssignedIPAddress(responseIPs: String) -> String {
        return _ut_splitIPs(responseIPs).first ?? ""
    }
    
    func configureNetworkTunnelSettings(intranetIP: String) {
        _tn_applyAndStart(intranetIP)
    }
    func initiateLocalToRemoteDataFlow() {
        _tx_uplinkLoop()
    }
    func initiateRemoteToLocalDataFlow() {
        _dx_downlinkLoop()
    }
}

// MARK: - Bootstrap（连接与状态机）

private extension WireConductor {
    func _bs_startWire() {
        guard let port = NWEndpoint.Port(remoteServerPort) else { return }
        let host = NWEndpoint.Host(remoteServerHost)
        let conn = NWConnection(host: host, port: port, using: .tcp)
        tcpSocket = conn
        dispatchWorkQueue = .global()
        conn.stateUpdateHandler = { [weak self] s in
            self?.onWireState(s)
        }
        conn.start(queue: dispatchWorkQueue!)
    }
    
    func _bs_onState(_ s: NWConnection.State) {
        logInfo("🔄 连接状态变更: \(String(describing: s))")
        switch s {
        case .ready:
            _au_begin()
        case .failed(_), .cancelled:
            logError("❌ 连接失败/已取消: \(String(describing: s))")
        default:
            logInfo("ℹ️ 中间状态: \(String(describing: s))")
        }
    }
}

// MARK: - Auth（鉴权阶段）

private extension WireConductor {
    func _au_begin() {
        logInfo("➡️ 开始鉴权")
        guard let data = createAuthenticationPayload() else { return }
        logInfo("🔐 鉴权载荷字节数=\(data.count)")
        let out = applyDataObfuscation(data: data, key: secretKeyString.data(using: .utf8)!)
        logInfo("🔐 鉴权混淆后字节数=\(out.count)")
        tcpSocket?.send(content: out, completion: .contentProcessed({ [weak self] error in
            guard let self = self, error == nil else { return }
            self.logInfo("📨 鉴权发送完成，开始读取响应头")
            self._rx_readHead()
        }))
    }
    
    func _au_payload() -> Data? {
        logInfo("➡️ 生成鉴权载荷 区域=\(regionCode) 语言=\(localeIdentifier) 包=\(bundleIdentifier) 版本=\(appVersion)")
        let payload: [String: Any] = [
            "package": bundleIdentifier,
            "version": appVersion,
            "SDK": "7.0",
            "country": regionCode,
            "language": localeIdentifier,
            "action": "new_connect"
        ]
        guard let json = try? JSONSerialization.data(withJSONObject: payload, options: []),
              let keyData = encryptionKey.data(using: .utf8) else {
            return nil
        }
        logInfo("🧾 鉴权JSON字节=\(json.count)")
        return _cr_aesEcbPkcs7(json, keyData: keyData)
    }
}

// MARK: - RX（读取服务端响应：头/体）

private extension WireConductor {
    func _rx_readHead() {
        logInfo("➡️ 读取响应头")
        tcpSocket?.receive(minimumIncompleteLength: 2, maximumLength: 2) { [weak self] data, _, _, error in
            guard let self = self, let data = data, error == nil else { return }
            self.incomingDataBuffer.append(data)
            self.logInfo("📩 收到头部分片 字节=\(data.count) 缓冲区=\(self.incomingDataBuffer.count)")
            if self.incomingDataBuffer.count >= 2 {
                let need = self.incomingDataBuffer.prefix(2).withUnsafeBytes { $0.load(as: UInt16.self).bigEndian }
                self.incomingDataBuffer.removeFirst(2)
                self.logInfo("🧮 负载长度=\(need)")
                self._rx_readBody(expected: Int(need))
            } else {
                self._rx_readHead()
            }
        }
    }
    
    func _rx_readBody(expected: Int) {
        logInfo("➡️ 读取响应体 期望字节=\(expected)")
        tcpSocket?.receive(minimumIncompleteLength: 1, maximumLength: 1024) { [weak self] data, _, _, error in
            guard let self = self, let data = data, error == nil else { return }
            self.incomingDataBuffer.append(data)
            self.logInfo("📩 收到体分片 字节=\(data.count) 缓冲区=\(self.incomingDataBuffer.count)/\(expected)")
            if self.incomingDataBuffer.count >= expected {
                let enc = self.incomingDataBuffer.prefix(expected)
                self.incomingDataBuffer.removeFirst(expected)
                let dec = self.reverseDataObfuscation(data: enc, key: self.secretKeyString.data(using: .utf8)!)
                self.logInfo("🔓 解混淆响应字节=\(dec.count)")
                self._auth_onServerResponse(dec)
            } else {
                self._rx_readBody(expected: expected)
            }
        }
    }
    
    func _auth_onServerResponse(_ resp: Data) {
        let s = String(data: resp, encoding: .utf8)
        let ip = extractAssignedIPAddress(responseIPs: s ?? "")
        logInfo("🧾 服务端响应=\(s ?? "<nil>")")
        logInfo("✅ 分配的内网IP=\(ip)")
        configureNetworkTunnelSettings(intranetIP: ip)
    }
}

// MARK: - Tunnel（配置与启动泵）

private extension WireConductor {
    func _tn_applyAndStart(_ intranetIP: String) {
        logInfo("➡️ 配置隧道 ip=\(intranetIP) mtu=\(_K.n1) dns=\(_K.n2)")
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: _K.n0)
        settings.mtu = _K.n1
        settings.dnsSettings = NEDNSSettings(servers: _K.n2)
        settings.ipv4Settings = {
            let ipv4 = NEIPv4Settings(addresses: [intranetIP], subnetMasks: ["255.255.0.0"])
            ipv4.includedRoutes = [NEIPv4Route.default()]
            return ipv4
        }()
        networkConfigurationHandler?(settings) { [weak self] err in
            guard let self = self else { return }
            if let err { self.logError("❌ 应用隧道配置失败: \(err.localizedDescription)"); return }
            self.logInfo("🔧 隧道配置已生效")
            self._tn_startPumps()
        }
    }
    
    func _tn_startPumps() {
        logInfo("➡️ 启动数据转发")
        initiateLocalToRemoteDataFlow()
        initiateRemoteToLocalDataFlow()
    }
}

// MARK: - TX（本地→远端）

private extension WireConductor {
    func _tx_uplinkLoop() {
        logInfo("➡️ 本地→远端 数据通道启动")
        let k = secretKeyString.data(using: .utf8)!
        tunnelDataFlow.readPackets { [weak self] (packets: [Data], _) in
            guard let self = self else { return }
            self.logInfo("📤 读取系统数据包 数量=\(packets.count) 总字节=\(packets.reduce(0){$0+$1.count})")
            for packet in packets {
                self.logInfo("📦 上行原始包 字节=\(packet.count)")
                let obf = self.applyDataObfuscation(data: packet, key: k)
                self.logInfo("📦 上行混淆后 字节=\(obf.count)")
                self.logInfo("🚚 准备发送 上行数据 字节=\(obf.count)")
                self.tcpSocket?.send(content: obf, completion: .contentProcessed({ error in
                    if let error = error {
                        self.logError("❌ 上行发送失败: \(error.localizedDescription)")
                        return
                    }
                    self.logInfo("✅ 上行发送完成(已提交内核队列) 字节=\(obf.count)")
                }))
            }
            self._tx_uplinkLoop()
        }
    }
}

// MARK: - RX（远端→本地）

private extension WireConductor {
    func _dx_downlinkLoop() {
        logInfo("➡️ 远端→本地 数据通道启动")
        tcpSocket?.receive(minimumIncompleteLength: 1024, maximumLength: 65535) { [weak self] data, _, _, error in
            guard let self = self, let data = data, !data.isEmpty else { return }
            self.logInfo("📥 收到远端分片 字节=\(data.count)")
            self.packetDataBuffer.append(data)
            self._dx_drainBuffer()
            self._dx_downlinkLoop()
        }
    }
    
    func _dx_drainBuffer() {
        logInfo("➡️ 处理下行缓冲 区字节=\(packetDataBuffer.count)")
        let k = secretKeyString.data(using: .utf8)!
        while packetDataBuffer.count >= 2 {
            let need = packetDataBuffer.prefix(2).withUnsafeBytes { $0.load(as: UInt16.self).bigEndian }
            packetDataBuffer.removeSubrange(0..<2)
            if packetDataBuffer.count >= need {
                let enc = packetDataBuffer.prefix(Int(need))
                packetDataBuffer.removeSubrange(0..<Int(need))
                let clear = reverseDataObfuscation(data: enc, key: k)
                logInfo("🧾 写回系统包 长度=\(clear.count)")
                let proto = AF_INET as NSNumber
                tunnelDataFlow.writePackets([clear], withProtocols: [proto])
            } else {
                logInfo("⏳ 等待更多数据 需要=\(need) 当前=\(packetDataBuffer.count)")
                packetDataBuffer.insert(contentsOf: withUnsafeBytes(of: need.bigEndian, Array.init), at: 0)
                break
            }
        }
    }
}

// MARK: - CODEC（混淆/反混淆）

private extension WireConductor {
    func _cc_obfuscate(_ data: Data, key: Data) -> Data {
        logInfo("➡️ 应用数据混淆 输入=\(data.count)")
        let maxR = UInt8(randomPaddingLength)
        let pad = UInt8.random(in: 0...maxR)
        let padding = Data((0..<Int(pad)).map { _ in UInt8.random(in: 0...255) })
        let withPad = padding + data + Data([pad])
        let xored = Data(withPad.enumerated().map { i, b in b ^ key[i % key.count] })
        let len = UInt16(xored.count).toBigEndianBytes()
        let out = len + xored
        logInfo("⬆️ 混淆填充=\(pad) 输出=\(out.count)")
        return out
    }
    
    func _cc_reveal(_ data: Data, key: Data) -> Data {
        logInfo("➡️ 反混淆 输入=\(data.count)")
        let raw = Data(data.enumerated().map { i, b in b ^ key[i % key.count] })
        if let last = raw.last {
            let pad = Int(last)
            if pad < raw.count {
                let out = raw.subdata(in: pad..<(raw.count - 1))
                logInfo("⬇️ 反混淆输出=\(out.count) 去除填充=\(pad)")
                return out
            }
        }
        logInfo("⬇️ 反混淆输出(无裁剪)=\(raw.count)")
        return raw
    }
}

// MARK: - Crypto（AES）

private extension WireConductor {
    func _cr_aesEcbPkcs7(_ plain: Data, keyData: Data) -> Data? {
        logInfo("➡️ 执行AES加密 输入=\(plain.count) 密钥=\(keyData.count)")
        let p = [UInt8](plain)
        let k = [UInt8](keyData)
        var out = [UInt8](repeating: 0, count: p.count + kCCBlockSizeAES128)
        var outLen = 0
        let status = CCCrypt(CCOperation(kCCEncrypt), CCAlgorithm(kCCAlgorithmAES),
                             CCOptions(kCCOptionPKCS7Padding | kCCOptionECBMode),
                             k, keyData.count, nil,
                             p, p.count,
                             &out, out.count, &outLen)
        guard status == kCCSuccess else {
            logError("❌ AES加密失败 状态=\(status)")
            return nil
        }
        let data = Data(bytes: out, count: outLen)
        logInfo("🔒 AES输出=\(data.count)")
        return data
    }
}

// MARK: - Utils

private extension WireConductor {
    func _ut_splitIPs(_ s: String) -> [String] {
        return s.split(separator: ",").map { String($0) }
    }
}

// MARK: - Bits

private extension UInt16 {
    func toBigEndianBytes() -> Data {
        Data([UInt8(self >> 8), UInt8(self & 0xFF)])
    }
}


