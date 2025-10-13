import SwiftUI

private struct ServerItem: Identifiable, Equatable {
    let id: String     // code, e.g., "auto", "us"
    let name: String   // display text
    let flag: String   // emoji
    let subtitle: String?
}

struct ServersView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selected: String = UserDefaults.standard.string(forKey: "selectedServerCode") ?? "auto"
    @ObservedObject private var localeManager = LocaleDao.shared

    private var servers: [ServerItem] {
        [
            ServerItem(id: "auto", name: LocalizedText("auto_node"), flag: "🧭", subtitle: LocalizedText("recommended")),
            ServerItem(id: "us", name: "United States", flag: "🇺🇸", subtitle: nil),
            ServerItem(id: "uk", name: "United Kingdom", flag: "🇬🇧", subtitle: nil),
            ServerItem(id: "sg", name: "Singapore", flag: "🇸🇬", subtitle: nil),
            ServerItem(id: "jp", name: "Japan", flag: "🇯🇵", subtitle: nil),
            ServerItem(id: "de", name: "Germany", flag: "🇩🇪", subtitle: nil),
            ServerItem(id: "nl", name: "Netherlands", flag: "🇳🇱", subtitle: nil),
            ServerItem(id: "ca", name: "Canada", flag: "🇨🇦", subtitle: nil),
            ServerItem(id: "au", name: "Australia", flag: "🇦🇺", subtitle: nil)
        ]
    }

    var body: some View {
        NavigationView {
            ZStack {
                // 暗黑背景
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(servers) { item in
                            ServerCard(
                                item: item,
                                isSelected: item.id == selected
                            ) {
                                selected = item.id
                                UserDefaults.standard.set(item.id, forKey: "selectedServerCode")
                                NotificationCenter.default.post(name: .selectedServerChanged, object: item.id)
                                dismiss() // 选择后自动关闭
                            }
                            .padding(.horizontal, 16)
                        }
                        .padding(.top, 12)
                    }
                }
            }
            .navigationTitle(LocalizedText("servers_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(LocalizedText("cancel")) {
                        dismiss()
                    }
                    .foregroundColor(.accentColor)
                }
            }
        }
        .bindLocale()
    }
}

extension Notification.Name {
    static let selectedServerChanged = Notification.Name("selectedServerChanged")
}

private struct ServerCard: View {
    let item: ServerItem
    let isSelected: Bool
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
                        .foregroundColor(.white)
                        .lineLimit(1)
                    if let subtitle = item.subtitle {
                        Text(subtitle)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.65))
                            .lineLimit(1)
                    }
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "chevron.right")
                    .foregroundColor(isSelected ? .green : .white.opacity(0.6))
                    .font(.system(size: 18, weight: .semibold))
            }
            .padding(.horizontal, 16)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.green.opacity(0.5) : Color.white.opacity(0.12), lineWidth: isSelected ? 1.5 : 1)
            )
            .scaleEffect(pressed ? 0.98 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack { ServersView() }
}

