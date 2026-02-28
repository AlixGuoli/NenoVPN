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
}

