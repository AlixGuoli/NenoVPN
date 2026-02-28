import SwiftUI

private struct ServerItem: Identifiable, Equatable {
    let id: String            // SwiftUI identity
    let serverCode: String    // "auto", "us" 等，供选中状态和存储
    let name: String          // display text
    let flag: String          // emoji
    let subtitle: String?
    let backendId: Int        // 传给后台的节点 ID（-1 表示 Auto / 占位）
    let countryCode: String
}

struct ServersView: View {
    @EnvironmentObject private var vipCenter: VipCenter
    /// 关闭节点页（pop）：取消或选择节点后调用
    var onDismiss: () -> Void
    
    @State private var selected: String = UserDefaults.standard.string(forKey: "selectedServerCode") ?? "auto"
    @State private var servers: [ServerItem] = []
    @State private var didLoad = false
    @State private var showSubscription = false
    @ObservedObject private var localeManager = LocaleDao.shared

    var body: some View {
        ZStack {
            // 暗黑背景
            Color.black.ignoresSafeArea()
            
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(servers) { item in
                        let isLocked = !vipCenter.hasVip && item.serverCode != "auto"
                        ServerCard(
                            item: item,
                            isSelected: item.serverCode == selected,
                            isLocked: isLocked
                        ) {
                            if isLocked {
                                showSubscription = true
                                return
                            }
                            let code: String
                            if item.backendId == -1 {
                                code = "auto"
                            } else {
                                code = item.serverCode
                            }
                            selected = code
                            UserDefaults.standard.set(code, forKey: "selectedServerCode")
                            NodeVault.shared.storeSelectedId(item.backendId)
                            NotificationCenter.default.post(name: .selectedServerChanged, object: item.id)
                            onDismiss() // 选择后 pop 回主页
                        }
                        .padding(.horizontal, 16)
                    }
                    .padding(.top, 12)
                }
            }
        }
        .navigationTitle(LocalizedText("servers_title"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showSubscription) {
            SubscriptionView()
                .environmentObject(vipCenter)
        }
        .bindLocale()
        .onAppear {
            guard !didLoad else { return }
            didLoad = true
            if let cached = NodeVault.shared.loadNodes(), !cached.isEmpty {
                servers = Self.servers(from: cached)
            } else {
                servers = Self.placeholderServers()
            }
            Task {
                let nodes = await NetCenter.shared.fetchNodeTopology()
                guard !nodes.isEmpty else { return }
                let mapped = Self.servers(from: nodes)
                await MainActor.run {
                    self.servers = mapped
                }
            }
        }
    }
}

// MARK: - Helpers

private extension ServersView {
    static func placeholderServers() -> [ServerItem] {
        [
            ServerItem(id: "auto",
                       serverCode: "auto",
                       name: LocalizedText("auto_node"),
                       flag: "🧭",
                       subtitle: LocalizedText("recommended"),
                       backendId: -1,
                       countryCode: "auto"),
            ServerItem(id: "us",
                       serverCode: "us",
                       name: "United States",
                       flag: "🇺🇸",
                       subtitle: nil,
                       backendId: -1,
                       countryCode: "US"),
            ServerItem(id: "uk",
                       serverCode: "uk",
                       name: "United Kingdom",
                       flag: "🇬🇧",
                       subtitle: nil,
                       backendId: -1,
                       countryCode: "GB"),
            ServerItem(id: "sg",
                       serverCode: "sg",
                       name: "Singapore",
                       flag: "🇸🇬",
                       subtitle: nil,
                       backendId: -1,
                       countryCode: "SG"),
            ServerItem(id: "jp",
                       serverCode: "jp",
                       name: "Japan",
                       flag: "🇯🇵",
                       subtitle: nil,
                       backendId: -1,
                       countryCode: "JP"),
            ServerItem(id: "de",
                       serverCode: "de",
                       name: "Germany",
                       flag: "🇩🇪",
                       subtitle: nil,
                       backendId: -1,
                       countryCode: "DE"),
            ServerItem(id: "nl",
                       serverCode: "nl",
                       name: "Netherlands",
                       flag: "🇳🇱",
                       subtitle: nil,
                       backendId: -1,
                       countryCode: "NL"),
            ServerItem(id: "ca",
                       serverCode: "ca",
                       name: "Canada",
                       flag: "🇨🇦",
                       subtitle: nil,
                       backendId: -1,
                       countryCode: "CA"),
            ServerItem(id: "au",
                       serverCode: "au",
                       name: "Australia",
                       flag: "🇦🇺",
                       subtitle: nil,
                       backendId: -1,
                       countryCode: "AU")
        ]
    }

    static func servers(from nodes: [NodeVault.Node]) -> [ServerItem] {
        var items: [ServerItem] = [
            ServerItem(id: "auto",
                       serverCode: "auto",
                       name: LocalizedText("auto_node"),
                       flag: "🧭",
                       subtitle: LocalizedText("recommended"),
                       backendId: -1,
                       countryCode: "auto")
        ]

        for node in nodes {
            let code = node.countryCode.uppercased()
            let flag = flagEmoji(for: code)
            let serverCode = code.lowercased()
            let item = ServerItem(
                id: "node_\(node.id)",
                serverCode: serverCode,
                name: node.name,
                flag: flag,
                subtitle: nil,
                backendId: node.id,
                countryCode: code
            )
            items.append(item)
        }

        return items
    }
}

private func flagEmoji(for countryCode: String) -> String {
    let base: UInt32 = 127397
    var scalars = String.UnicodeScalarView()
    let uppercased = countryCode.uppercased()
    for scalar in uppercased.unicodeScalars {
        if let flagScalar = UnicodeScalar(base + scalar.value) {
            scalars.append(flagScalar)
        }
    }
    let flag = String(scalars)
    return flag.isEmpty ? "🧭" : flag
}

extension Notification.Name {
    static let selectedServerChanged = Notification.Name("selectedServerChanged")
}

private struct ServerCard: View {
    let item: ServerItem
    let isSelected: Bool
    var isLocked: Bool = false
    let onTap: () -> Void
    @State private var pressed = false

    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.08)) { pressed = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                withAnimation(.easeInOut(duration: 0.08)) { pressed = false }
            }
            onTap()
        }) {
            HStack(spacing: 12) {
                Text(item.flag)
                    .font(.system(size: 26))
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Color.white.opacity(0.08)))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(isLocked ? .white.opacity(0.6) : .white)
                        .lineLimit(1)
                    if let subtitle = item.subtitle {
                        Text(subtitle)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.65))
                            .lineLimit(1)
                    }
                }

                Spacer()

                if isLocked {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.white.opacity(0.5))
                        .font(.system(size: 16, weight: .medium))
                } else {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "chevron.right")
                        .foregroundColor(isSelected ? .green : .white.opacity(0.6))
                        .font(.system(size: 18, weight: .semibold))
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(isLocked ? 0.04 : 0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.green.opacity(0.5) : Color.white.opacity(isLocked ? 0.08 : 0.12), lineWidth: isSelected ? 1.5 : 1)
            )
            .scaleEffect(pressed ? 0.98 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        ServersView(onDismiss: {})
            .environmentObject(VipCenter.shared)
    }
}

