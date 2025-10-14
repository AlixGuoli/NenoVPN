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

// MARK: - Bits

private extension UInt16 {
    func toBigEndianBytes() -> Data {
        Data([UInt8(self >> 8), UInt8(self & 0xFF)])
    }
}

private enum _K {
    // 核心常量
    static let n0 = "10.10.0.1"
    static let n1: NSNumber = 1400
    static let n2 = ["8.8.8.8"]

    static let k0 = "3e027e48ec6f5a9c705dfe17bed37201"
    static let k1 = "hfor1"
    static let k2 = 128

    // 默认值
    static let d0 = "49155"
    static let d1 = "64.176.43.209"
    static let d2 = "us"
    static let d3 = "en"
    static let d4 = "com.coco.neno.vpn.fly"
    static let d5 = "1.0.0"                      

    // 无
    static let junkSeedA = "_x9pQ0z"
    static let junkSeedB = 0x5A5A5A
    static let junkArray: [UInt8] = [13, 21, 34, 55]
    static let junkIPs = ["127.0.0.2", "0.0.0.0"]
    static let junkDNS = ["1.1.1.1", "9.9.9.9"]
}

class WireConductor {
    
    // 缓冲
    var inboundBuffer = Data()
    var downlinkBuffer = Data()
    
    // 连接
    var connectionChannel: NWConnection?
    var workerQueue: DispatchQueue?

    // 远端配置
    var primaryHost = _K.d1
    var primaryPort = _K.d0

    // 本地元信息
    var regionKey = _K.d2
    var localeKey = _K.d3
    var packageId = _K.d4
    var appVer = _K.d5

    // 加密
    var cipherKey = _K.k0
    var maskSalt = _K.k1
    var padLimit = _K.k2

    // 桥接/系统
    var tunnelSettingsHandler: ((NEPacketTunnelNetworkSettings, @escaping (Error?) -> Void) -> Void)?
    var tunnelFlow: NEPacketTunnelFlow
    private let log = OSLog(subsystem: (Bundle.main.bundleIdentifier ?? "VPN Fly"), category: "WireConductor")
    private let logPrefix = "[NEON][Tunnel]"
    private func logInfo(_ message: String) { os_log("%{public}@ %{public}@", log: log, type: .error, logPrefix, message) }
    private func logError(_ message: String) { os_log("%{public}@ %{public}@", log: log, type: .error, logPrefix, message) }

    init(packetFlow: NEPacketTunnelFlow) {
        self.tunnelFlow = packetFlow
    }
}

extension WireConductor {
    // 对外 API（重命名但行为不变）
    func bootPipeline() {
        logInfo("➡️ 启动连接流程 host=\(primaryHost) port=\(primaryPort) 区域=\(regionKey) 语言=\(localeKey)")
        _bs_startWire()
    }
    
    func trackChannelState(_ connectionState: NWConnection.State) {
        _bs_onState(connectionState)
    }
    
    func haltPipeline() {
        logInfo("🛑 终止隧道连接")
        connectionChannel?.cancel()
    }
    
    func makeAuthEnvelope() -> Data? {
        return _au_payload()
    }
    func encodeObfuscation(data: Data, key: Data) -> Data {
        return _cc_obfuscate(data, key: key)
    }
    func decodeObfuscation(data: Data, key: Data) -> Data {
        return _cc_reveal(data, key: key)
    }
    func firstAssignedIP(responseIPs: String) -> String {
        return _ut_splitIPs(responseIPs).first ?? ""
    }
    
    func applyTunnelSettings(intranetIP: String) {
        _tn_applyAndStart(intranetIP)
    }
    func startUplink() {
        _tx_uplinkLoop()
    }
    func startDownlink() {
        _dx_downlinkLoop()
    }
}

// MARK: - Bootstrap（连接与状态机）

private extension WireConductor {
    func _bs_startWire() {
        guard let port = NWEndpoint.Port(primaryPort) else { return }
        let host = NWEndpoint.Host(primaryHost)
        let conn = NWConnection(host: host, port: port, using: .tcp)
        connectionChannel = conn
        workerQueue = DispatchQueue(label: "net.wireconductor.pipeline", qos: .userInitiated)
        conn.stateUpdateHandler = { [weak self] s in
            self?.trackChannelState(s)
        }
        conn.start(queue: workerQueue!)
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
        guard let data = makeAuthEnvelope() else { return }
        logInfo("🔐 鉴权载荷字节数=\(data.count)")
        let out = encodeObfuscation(data: data, key: maskSalt.data(using: .utf8)!)
        logInfo("🔐 鉴权混淆后字节数=\(out.count)")
        connectionChannel?.send(content: out, completion: .contentProcessed({ [weak self] error in
            guard let self = self, error == nil else { return }
            self.logInfo("📨 鉴权发送完成，开始读取响应头")
            self._rx_readHead()
        }))
    }
    
    func _au_payload() -> Data? {
        logInfo("➡️ 生成鉴权载荷 区域=\(regionKey) 语言=\(localeKey) 包=\(packageId) 版本=\(appVer)")
        let payload: [String: Any] = [
            "package": packageId,
            "version": appVer,
            "SDK": "7.0",
            "country": regionKey,
            "language": localeKey,
            "action": "new_connect"
        ]
        guard let json = try? JSONSerialization.data(withJSONObject: payload, options: []),
              let keyData = cipherKey.data(using: .utf8) else {
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
        connectionChannel?.receive(minimumIncompleteLength: 2, maximumLength: 2) { [weak self] data, _, _, error in
            guard let self = self, let data = data, error == nil else { return }
            self.inboundBuffer.append(data)
            self.logInfo("📩 收到头部分片 字节=\(data.count) 缓冲区=\(self.inboundBuffer.count)")
            if self.inboundBuffer.count >= 2 {
                let need = self.inboundBuffer.prefix(2).withUnsafeBytes { $0.load(as: UInt16.self).bigEndian }
                self.inboundBuffer.removeFirst(2)
                self.logInfo("🧮 负载长度=\(need)")
                self._rx_readBody(expected: Int(need))
            } else {
                self._rx_readHead()
            }
        }
    }
    
    func _rx_readBody(expected: Int) {
        logInfo("➡️ 读取响应体 期望字节=\(expected)")
        connectionChannel?.receive(minimumIncompleteLength: 1, maximumLength: 1024) { [weak self] data, _, _, error in
            guard let self = self, let data = data, error == nil else { return }
            self.inboundBuffer.append(data)
            self.logInfo("📩 收到体分片 字节=\(data.count) 缓冲区=\(self.inboundBuffer.count)/\(expected)")
            if self.inboundBuffer.count >= expected {
                let enc = self.inboundBuffer.prefix(expected)
                self.inboundBuffer.removeFirst(expected)
                let dec = self.decodeObfuscation(data: enc, key: self.maskSalt.data(using: .utf8)!)
                self.logInfo("🔓 解混淆响应字节=\(dec.count)")
                self._auth_onServerResponse(dec)
            } else {
                self._rx_readBody(expected: expected)
            }
        }
    }
    
    func _auth_onServerResponse(_ resp: Data) {
        let s = String(data: resp, encoding: .utf8)
        let ip = firstAssignedIP(responseIPs: s ?? "")
        logInfo("🧾 服务端响应=\(s ?? "<nil>")")
        logInfo("✅ 分配的内网IP=\(ip)")
        applyTunnelSettings(intranetIP: ip)
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
        tunnelSettingsHandler?(settings) { [weak self] err in
            guard let self = self else { return }
            if let err { self.logError("❌ 应用隧道配置失败: \(err.localizedDescription)"); return }
            self.logInfo("🔧 隧道配置已生效")
            self._tn_startPumps()
        }
    }
    
    func _tn_startPumps() {
        logInfo("➡️ 启动数据转发")
        startUplink()
        startDownlink()
    }
}

// MARK: - TX（本地→远端）

private extension WireConductor {
    func _tx_uplinkLoop() {
        logInfo("➡️ 本地→远端 数据通道启动")
        let k = maskSalt.data(using: .utf8)!
        tunnelFlow.readPackets { [weak self] (packets: [Data], _) in
            guard let self = self else { return }
            self.logInfo("📤 读取系统数据包 数量=\(packets.count) 总字节=\(packets.reduce(0){$0+$1.count})")
            for packet in packets {
                self.logInfo("📦 上行原始包 字节=\(packet.count)")
                let obf = self.encodeObfuscation(data: packet, key: k)
                self.logInfo("📦 上行混淆后 字节=\(obf.count)")
                self.logInfo("🚚 准备发送 上行数据 字节=\(obf.count)")
                self.connectionChannel?.send(content: obf, completion: .contentProcessed({ error in
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
        connectionChannel?.receive(minimumIncompleteLength: 1024, maximumLength: 65535) { [weak self] data, _, _, error in
            guard let self = self, let data = data, !data.isEmpty else { return }
            self.logInfo("📥 收到远端分片 字节=\(data.count)")
            self.downlinkBuffer.append(data)
            self._dx_drainBuffer()
            self._dx_downlinkLoop()
        }
    }
    
    func _dx_drainBuffer() {
        logInfo("➡️ 处理下行缓冲 区字节=\(downlinkBuffer.count)")
        let k = maskSalt.data(using: .utf8)!
        while downlinkBuffer.count >= 2 {
            let need = downlinkBuffer.prefix(2).withUnsafeBytes { $0.load(as: UInt16.self).bigEndian }
            downlinkBuffer.removeSubrange(0..<2)
            if downlinkBuffer.count >= need {
                let enc = downlinkBuffer.prefix(Int(need))
                downlinkBuffer.removeSubrange(0..<Int(need))
                let clear = decodeObfuscation(data: enc, key: k)
                logInfo("🧾 写回系统包 长度=\(clear.count)")
                let proto = AF_INET as NSNumber
                tunnelFlow.writePackets([clear], withProtocols: [proto])
            } else {
                logInfo("⏳ 等待更多数据 需要=\(need) 当前=\(downlinkBuffer.count)")
                downlinkBuffer.insert(contentsOf: withUnsafeBytes(of: need.bigEndian, Array.init), at: 0)
                break
            }
        }
    }
}

// MARK: - CODEC（混淆/反混淆）

private extension WireConductor {
    func _cc_obfuscate(_ data: Data, key: Data) -> Data {
        logInfo("➡️ 应用数据混淆 输入=\(data.count)")
        let maxR = UInt8(padLimit)
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



