//
//  NetHelper.swift
//  NeonVPN
//
//  Created by Stephen Schaaf on 2025/11/18.
//

import Foundation
import os

// MARK: - 全局日志方法
func logMessage(_ message: String) {
    os_log("[Neon COCO] %{public}@", log: OSLog.default, type: .error, message)
}

class ConfigDecoder {
    
    // MARK: - 静态常量
    
    // 原始Base32字符串（保持不变）
    static let base32Source = """
OR2W43TFNQ5AUIBANV2HKORAHEYDAMAKONXWG23TGU5AUIBAOBXXE5B2EA4DAOBQBIQCAYLEMRZGK43THIQDUORRBIQCA5LEOA5CAJ3VMRYCOCTNNFZWGOQKEAQHIYLTNMWXG5DBMNVS243JPJSTUIBSGA2DQMAKEAQGG33ONZSWG5BNORUW2ZLPOV2DUIBVGAYDACRAEBZGKYLEFV3XE2LUMUWXI2LNMVXXK5B2EA3DAMBQGAFCAIDMN5TS2ZTJNRSTUIDTORSGK4TSBIQCA3DPM4WWYZLWMVWDUIDFOJZG64QKEAQGY2LNNF2C23TPMZUWYZJ2EA3DKNJTGU======
"""
    
    // MARK: - Base32解码算法
    
    static func decodeBase32(_ source: String) -> String? {
        let charSet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
        var bitCount = 0
        var accumulator = 0
        var output = Data()
        
        for ch in source.uppercased() {
            if ch == "=" {
                break
            }
            
            guard let index = charSet.firstIndex(of: ch)?.encodedOffset else {
                return nil
            }
            
            accumulator = (accumulator << 5) | index
            bitCount += 5
            
            while bitCount >= 8 {
                bitCount -= 8
                output.append(UInt8((accumulator >> bitCount) & 0xFF))
            }
        }
        
        return String(data: output, encoding: .utf8)
    }
    
    // MARK: - 配置解码
    
    static var parsedConfig: String? {
        return decodeBase32(base32Source)
    }
    
    // MARK: - 文件操作
    
    static func saveData(withName fileName: String, data content: Data?) -> URL {
        let fm = FileManager.default
        let docDir = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let targetPath = docDir.appendingPathComponent(fileName)
        
        do {
            try content?.write(to: targetPath)
        } catch {
            logMessage("writeDataToFile Error : \(error)")
        }
        
        return targetPath
    }
    
    // MARK: - 数据准备
    
    private static func loadFromStorage() -> String {
        let userDefaults = UserDefaults(suiteName: RouterConf.routerGroupId)
        return userDefaults?.string(forKey: RouterConf.routerConfigKey) ?? ""
    }
    
    private static func serializeToData() -> Data? {
        return parsedConfig?.data(using: .utf8)
    }
    
    // MARK: - 文件创建
    
    private static func persistFile(withName fileName: String, data content: Data?) -> URL {
        return saveData(withName: fileName, data: content)
    }
    
    private static func createJson(with path: URL) -> String {
        return """
            {
                "datDir": "",
                "configPath": "\(path.path)",
                "maxMemory": \(31457280)
            }
            """
    }
    
    // MARK: - 配置管理
    
    static func buildDirectoryConfig() -> String {
        let rawData = loadFromStorage()
        let targetUrl = persistFile(withName: "NetConfig", data: rawData.data(using: .utf8))
        return createJson(with: targetUrl)
    }
    
    static func buildSocksPath() -> String {
        let contentData = serializeToData()
        let filePath = persistFile(withName: "SocksConfig", data: contentData)
        return filePath.path()
    }
}
