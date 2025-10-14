import SwiftUI

struct LanguageSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var localeManager = LocaleDao.shared
    @State private var selectedLanguage: AppLanguage = .english
    @State private var isLoading = false
    
    // 展示的语言（按名称排序）
    private var languages: [AppLanguage] {
        AppLanguage.allCases
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // 暗黑背景
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 可滚动的内容区域
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            // 当前语言提示卡片
                            CurrentLanguageCard(language: selectedLanguage)
                            
                            // 语言选项
                            ForEach(languages, id: \.self) { language in
                                LanguageCard(
                                    language: language,
                                    isSelected: language == selectedLanguage
                                ) {
                                    selectedLanguage = language
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 20)
                        .padding(.bottom, 100) // 为底部按钮留出空间
                    }
                    
                    // 固定在底部的按钮
                    VStack(spacing: 0) {
                        // 分隔线
                        Rectangle()
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 1)
                        
                        HStack(spacing: 12) {
                            Button(LocalizedText("cancel")) {
                                dismiss()
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.06))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                    )
                            )
                            .foregroundColor(.white)
                            
                            Button(LocalizedText("confirm")) {
                                switchLanguage(selectedLanguage)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.accentColor)
                            )
                            .foregroundColor(.white)
                            .disabled(isLoading)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                        .background(Color.black) // 确保底部按钮有背景
                    }
                }
            }
            .navigationTitle(LocalizedText("language_settings"))
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
        .onAppear {
            loadCurrentLanguage()
        }
        .overlay {
            if isLoading {
                ZStack {
                    Color.black.opacity(0.3).ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(.white)
                        Text("切换语言中...")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .background(Color.black.opacity(0.7))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
        }
    }
    
    private func loadCurrentLanguage() {
        if let current = AppLanguage(rawValue: localeManager.activeCode) {
            selectedLanguage = current
        } else {
            selectedLanguage = .english
        }
    }
    
    private func switchLanguage(_ language: AppLanguage) {
        withAnimation(.easeInOut(duration: 0.2)) {
            isLoading = true
            localeManager.setCode(language.rawValue)
            // 减少延迟，让语言切换更快生效
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isLoading = false
                dismiss()
            }
        }
    }
}

// MARK: - 当前语言卡片
private struct CurrentLanguageCard: View {
    let language: AppLanguage
    @ObservedObject private var localeManager = LocaleDao.shared
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(language.flag)
                    .font(.system(size: 24))
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizedText("current_language"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                    Text(language.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.accentColor)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(LinearGradient(colors: [Color.accentColor.opacity(0.15), Color.accentColor.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.accentColor.opacity(0.25), lineWidth: 1)
                )
        )
    }
}

// MARK: - 语言卡片
private struct LanguageCard: View {
    let language: AppLanguage
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
            HStack(spacing: 16) {
                Text(language.flag)
                    .font(.system(size: 20))
                    .frame(width: 26)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(language.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    Text(language.rawValue.uppercased())
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.accentColor)
                } else {
                    Image(systemName: "circle")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white.opacity(0.3))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isSelected ? Color.accentColor.opacity(0.4) : Color.white.opacity(0.12), lineWidth: 1)
                    )
            )
            .scaleEffect(pressed ? 0.98 : 1)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    LanguageSettingsView()
}
