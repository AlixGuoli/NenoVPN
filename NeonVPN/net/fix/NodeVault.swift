//
//  NodeVault.swift
//  NeonVPN
//
//  管理节点列表和当前选中的节点 ID（用于向服务端传 group）。
//

import Foundation

final class NodeVault {
    static let shared = NodeVault()
    private init() {}

    struct Node: Codable, Equatable {
        let id: Int
        let name: String
        let countryCode: String
    }

    private let nodesKey = "nvNodesPayload"
    private let selectedIdKey = StoreKeys.Server.chosenServerId

    // MARK: - 节点列表持久化

    func storeNodes(_ nodes: [Node]) {
        guard let data = try? JSONEncoder().encode(nodes) else { return }
        UserDefaults.standard.set(data, forKey: nodesKey)
        UserDefaults.standard.synchronize()
    }

    func loadNodes() -> [Node]? {
        guard let data = UserDefaults.standard.data(forKey: nodesKey),
              let nodes = try? JSONDecoder().decode([Node].self, from: data),
              !nodes.isEmpty else {
            return nil
        }
        return nodes
    }

    // MARK: - 当前选中节点 ID（用于 group）

    func storeSelectedId(_ id: Int) {
        UserDefaults.standard.set(id, forKey: selectedIdKey)
        UserDefaults.standard.synchronize()
    }

    /// 当前选中的节点 ID，默认 -1（Auto / 随机）
    func selectedId() -> Int {
        if UserDefaults.standard.object(forKey: selectedIdKey) == nil {
            return -1
        }
        let value = UserDefaults.standard.integer(forKey: selectedIdKey)
        return value == 0 ? -1 : value
    }

    /// 重置为自动节点（非会员时调用）
    func resetToAuto() {
        UserDefaults.standard.set("auto", forKey: "selectedServerCode")
        storeSelectedId(-1)
        NotificationCenter.default.post(name: .selectedServerChanged, object: nil)
    }

    // MARK: - 显示用（与节点页统一：优先从节点列表取）

    private static let selectedCodeKey = "selectedServerCode"

    /// 当前选中节点的显示名称（与节点页一致，优先用 API 节点 name）
    func selectedDisplayName() -> String {
        let id = selectedId()
        if id == -1 { return "recommended" }
        if let nodes = loadNodes(), let node = nodes.first(where: { $0.id == id }) {
            return node.name
        }
        let code = UserDefaults.standard.string(forKey: Self.selectedCodeKey) ?? "auto"
        return fallbackDisplayName(for: code)
    }

    /// 当前选中节点的旗子 emoji
    func selectedFlag() -> String {
        let id = selectedId()
        if id == -1 { return "🧭" }
        if let nodes = loadNodes(), let node = nodes.first(where: { $0.id == id }) {
            return Self.flagEmoji(for: node.countryCode)
        }
        let code = UserDefaults.standard.string(forKey: Self.selectedCodeKey) ?? "auto"
        return fallbackFlag(for: code)
    }

    private func fallbackDisplayName(for code: String) -> String {
        switch code.lowercased() {
        case "auto": return "recommended"
        case "us": return "United States"
        case "uk", "gb": return "United Kingdom"
        case "sg": return "Singapore"
        case "jp": return "Japan"
        case "de": return "Germany"
        case "nl": return "Netherlands"
        case "ca": return "Canada"
        case "au": return "Australia"
        case "kr": return "South Korea"
        case "fr": return "France"
        case "in": return "India"
        case "es": return "Spain"
        case "it": return "Italy"
        case "br": return "Brazil"
        case "mx": return "Mexico"
        case "pl": return "Poland"
        case "hk": return "Hong Kong"
        case "tw": return "Taiwan"
        case "th": return "Thailand"
        case "vn": return "Vietnam"
        case "id": return "Indonesia"
        case "my": return "Malaysia"
        case "ph": return "Philippines"
        case "ru": return "Russia"
        case "tr": return "Turkey"
        case "ch": return "Switzerland"
        case "se": return "Sweden"
        case "no": return "Norway"
        case "fi": return "Finland"
        case "ie": return "Ireland"
        case "pt": return "Portugal"
        case "at": return "Austria"
        case "be": return "Belgium"
        case "cz": return "Czech Republic"
        case "gr": return "Greece"
        case "ro": return "Romania"
        case "hu": return "Hungary"
        case "ar": return "Argentina"
        case "za": return "South Africa"
        case "ua": return "Ukraine"
        case "il": return "Israel"
        case "ae": return "United Arab Emirates"
        case "sa": return "Saudi Arabia"
        case "eg": return "Egypt"
        case "nz": return "New Zealand"
        case "cl": return "Chile"
        case "co": return "Colombia"
        case "pe": return "Peru"
        default: return "recommended"
        }
    }

    private func fallbackFlag(for code: String) -> String {
        switch code.lowercased() {
        case "auto": return "🧭"
        case "us": return "🇺🇸"
        case "uk", "gb": return "🇬🇧"
        case "sg": return "🇸🇬"
        case "jp": return "🇯🇵"
        case "de": return "🇩🇪"
        case "nl": return "🇳🇱"
        case "ca": return "🇨🇦"
        case "au": return "🇦🇺"
        case "kr": return "🇰🇷"
        case "fr": return "🇫🇷"
        case "in": return "🇮🇳"
        case "es": return "🇪🇸"
        case "it": return "🇮🇹"
        case "br": return "🇧🇷"
        case "mx": return "🇲🇽"
        case "pl": return "🇵🇱"
        case "hk": return "🇭🇰"
        case "tw": return "🇹🇼"
        case "th": return "🇹🇭"
        case "vn": return "🇻🇳"
        case "id": return "🇮🇩"
        case "my": return "🇲🇾"
        case "ph": return "🇵🇭"
        case "ru": return "🇷🇺"
        case "tr": return "🇹🇷"
        case "ch": return "🇨🇭"
        case "se": return "🇸🇪"
        case "no": return "🇳🇴"
        case "fi": return "🇫🇮"
        case "ie": return "🇮🇪"
        case "pt": return "🇵🇹"
        case "at": return "🇦🇹"
        case "be": return "🇧🇪"
        case "cz": return "🇨🇿"
        case "gr": return "🇬🇷"
        case "ro": return "🇷🇴"
        case "hu": return "🇭🇺"
        case "ar": return "🇦🇷"
        case "za": return "🇿🇦"
        case "ua": return "🇺🇦"
        case "il": return "🇮🇱"
        case "ae": return "🇦🇪"
        case "sa": return "🇸🇦"
        case "eg": return "🇪🇬"
        case "nz": return "🇳🇿"
        case "cl": return "🇨🇱"
        case "co": return "🇨🇴"
        case "pe": return "🇵🇪"
        default: return Self.flagEmoji(for: code)
        }
    }

    private static func flagEmoji(for countryCode: String) -> String {
        let base: UInt32 = 127397
        var scalars = String.UnicodeScalarView()
        for scalar in countryCode.uppercased().unicodeScalars {
            if let flagScalar = UnicodeScalar(base + scalar.value) {
                scalars.append(flagScalar)
            }
        }
        return String(scalars).isEmpty ? "🧭" : String(scalars)
    }
}

