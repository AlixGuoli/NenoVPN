//
//  ConfigVault.swift
//  NeonVPN
//
//  Created by Stephen Schaaf on 2025/11/11.
//

import Foundation
import CryptoKit

final class ConfigVault {
    static let shared = ConfigVault()
    private init() {}
    
    // 读取并解密 Bundle 内的基础配置（local.git）
    func loadBundledProfile() -> String? {
        guard let path = Bundle.main.path(forResource: "local", ofType: "git") else {
            debugPrint("local.git 未找到")
            return nil
        }
        guard let envelope = try? String(contentsOfFile: path, encoding: .utf8) else {
            debugPrint("local.git 读取失败")
            return nil
        }
        return revealPayload(envelope)
    }
    
    // 解密三段式密文：base64Cipher, hexIV, reserved
    func revealPayload(_ payload: String) -> String? {
        let parts = payload
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: ",", omittingEmptySubsequences: true)
        guard parts.count == 3 else {
            debugPrint("解密失败：分段数量错误 \(parts.count)")
            return nil
        }
        
        let base64Cipher = String(parts[0]).trimmingCharacters(in: .whitespacesAndNewlines)
        let hexIV = String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard
            let keyData = NetProfile.Sec.cipherSeed.data(using: .utf8)?.prefix(32),
            let nonceData = Data(hexadecimal: hexIV),
            let cipherData = Data(base64Encoded: base64Cipher)
        else {
            debugPrint("解密失败：数据解析错误")
            return nil
        }
        
        let key = SymmetricKey(data: keyData)
        do {
            let sealed = try AES.GCM.SealedBox(combined: nonceData + cipherData)
            let plain = try AES.GCM.open(sealed, using: key)
            return String(data: plain, encoding: .utf8)
        } catch {
            debugPrint("解密失败：\(error.localizedDescription)")
            return nil
        }
    }
}

// Hex 字符串转 Data（命名做微差异）
private extension Data {
    init?(hexadecimal: String) {
        let s = hexadecimal.trimmingCharacters(in: .whitespacesAndNewlines)
        guard s.count % 2 == 0 else { return nil }
        var data = Data(capacity: s.count / 2)
        var idx = s.startIndex
        while idx < s.endIndex {
            let next = s.index(idx, offsetBy: 2)
            guard let byte = UInt8(s[idx..<next], radix: 16) else { return nil }
            data.append(byte)
            idx = next
        }
        self = data
    }
}


