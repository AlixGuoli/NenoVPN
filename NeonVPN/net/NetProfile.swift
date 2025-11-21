//
//  NetProfile.swift
//  NeonVPN
//
//  Created by Stephen Schaaf on 2025/11/10.
//

import Foundation
import CryptoKit

/// 网络配置管理器
final class NetProfile {
    static let shared = NetProfile()
    
    private let deviceKeyStorage = "deviceKey"
    
    private init() {
        _ = deviceKey
    }
    
    // MARK: - 基础参数
    
    var deviceKey: String {
        get {
            if let saved = UserDefaults.standard.string(forKey: deviceKeyStorage), !saved.isEmpty {
                return saved
            }
            let newKey = UUID().uuidString
            UserDefaults.standard.set(newKey, forKey: deviceKeyStorage)
            return newKey
        }
    }
    
    var packageId: String {
        /// 测试
        //return "CatVPN.CatVPN"
        return Bundle.main.bundleIdentifier ?? "com.coco.neon.vpn.fly"
    }
    
    var locale: String {
        return Locale.current.language.languageCode?.identifier ?? "en"
    }
    
    var region: String {
        /// 测试
        //return "ru"
        return (Locale.current.region?.identifier ?? "us").lowercased()
    }
    
    var ver: String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    
    // MARK: - 接口路径
    /// 测试
    enum API {
        static let configPolicy = "/mesh/config/policy"
        static let adsProxy = "/mesh/ads/proxy"
        static let serviceEndpoint = "/mesh/service/endpoint"
        static let groupTopology = "/mesh/group/topology"
    }
    
    // MARK: - 事件标识
    enum EventKeys {
        static let KEY_START = "start_connect"
        static let KEY_FAIL = "connect_failed"
        static let KEY_SUCCESS = "connect_success"
        static let KEY_DISCONNECT = "disconnect"
        static let KEY_AD_START = "start_get_ad"
        static let KEY_AD_SUCCESS = "get_ad_success"
        static let KEY_AD_SHOW = "show_ad"
    }
    
    // MARK: - 构建参数
    
    func params() -> [String: String] {
        return [
            "uid": deviceKey,
            "country": region,
            "language": locale,
            "pk": packageId,
            "version": ver
        ]
    }
    
    func clear() {
        UserDefaults.standard.removeObject(forKey: deviceKeyStorage)
    }
    
    // MARK: - 安全
    struct Sec {
        static let cipherSeed = "f92mUj0K1uBnMlXGFQKrYP07Emgc4yFmWYS8WRgy4IY="
        
        static func reveal(_ payload: String) -> String? {
            let parts = payload
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .split(separator: ",", omittingEmptySubsequences: true)
            guard parts.count == 3 else { return nil }
            
            let base64Cipher = String(parts[0]).trimmingCharacters(in: .whitespacesAndNewlines)
            let hexIV = String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
            
            guard
                let keyData = cipherSeed.data(using: .utf8)?.prefix(32),
                let nonceData = Data(hex: hexIV),
                let cipherData = Data(base64Encoded: base64Cipher)
            else { return nil }
            
            let key = SymmetricKey(data: keyData)
            do {
                let sealed = try AES.GCM.SealedBox(combined: nonceData + cipherData)
                let plain = try AES.GCM.open(sealed, using: key)
                return String(data: plain, encoding: .utf8)
            } catch {
                return nil
            }
        }
    }
}

private extension Data {
    init?(hex: String) {
        let s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        guard s.count % 2 == 0 else { return nil }
        var data = Data(capacity: s.count / 2)
        var idx = s.startIndex
        while idx < s.endIndex {
            let next = s.index(idx, offsetBy: 2)
            guard let b = UInt8(s[idx..<next], radix: 16) else { return nil }
            data.append(b)
            idx = next
        }
        self = data
    }
}

