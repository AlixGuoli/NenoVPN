import Foundation
import SwiftUI

final class LocaleDao: ObservableObject {
    static let shared = LocaleDao()
    
    @Published var activeCode: String = ""
    
    private let userKey = "userLocale"
    private let appleKey = "AppleLanguages"
    
    private var lastUpdateTime: Date = Date()
    private var isInitialized: Bool = false
    private let cacheManager = LanguageCacheManager()
    
    private init() {
        performInitialization()
    }
    
    // 公开方法：设置语言代码
    func setCode(_ code: String) {
        guard validateLanguageCode(code) else { return }
        
        // 记录更新时间
        lastUpdateTime = Date()
        
        // 更新当前代码
        activeCode = code
        
        // 执行语言环境配置
        executeLanguageConfiguration(code: code)
        
        // 发送语言变更通知
        broadcastLanguageChange(code: code)
    }
    
    // 公开方法：获取本地化字符串
    func localizedString(for key: String) -> String {
        return retrieveLocalizedText(key: key)
    }
    
    // 私有方法：执行初始化
    private func performInitialization() {
        // 从缓存中恢复设置
        restoreFromCache()
        
        // 标记为已初始化
        isInitialized = true
    }
    
    // 私有方法：从缓存恢复
    private func restoreFromCache() {
        // 尝试从用户偏好中读取
        if let cached = UserDefaults.standard.string(forKey: userKey),
           validateLanguageCode(cached) {
            activeCode = cached
        } else {
            // 自动检测系统语言
            let detected = detectSystemLanguage()
            activeCode = validateLanguageCode(detected) ? detected : "en"
        }
        
        // 应用语言设置
        executeLanguageConfiguration(code: activeCode)
    }
    
    // 私有方法：验证语言代码
    private func validateLanguageCode(_ code: String) -> Bool {
        return AppLanguage.allCases.contains(where: { $0.rawValue == code })
    }
    
    // 私有方法：检测系统语言
    private func detectSystemLanguage() -> String {
        return Locale.current.language.languageCode?.identifier ?? "en"
    }
    
    // 私有方法：执行语言配置
    private func executeLanguageConfiguration(code: String) {
        // 更新系统偏好
        updateSystemPreferences(code: code)
        
        // 加载语言包
        loadLanguageBundle(code: code)
        
        // 更新缓存
        cacheManager.updateCache(code: code)
    }
    
    // 私有方法：更新系统偏好
    private func updateSystemPreferences(code: String) {
        UserDefaults.standard.set([code], forKey: appleKey)
        UserDefaults.standard.set(code, forKey: userKey)
    }
    
    // 私有方法：加载语言包
    private func loadLanguageBundle(code: String) {
        if let bundlePath = Bundle.main.path(forResource: code, ofType: "lproj"),
           let languageBundle = Bundle(path: bundlePath) {
            Bundle._activeBundle = languageBundle
        } else if let fallbackPath = Bundle.main.path(forResource: "en", ofType: "lproj"),
                  let fallbackBundle = Bundle(path: fallbackPath) {
            Bundle._activeBundle = fallbackBundle
        } else {
            Bundle._activeBundle = .main
        }
    }
    
    // 私有方法：获取本地化文本
    private func retrieveLocalizedText(key: String) -> String {
        return Bundle.localizedBundle.localizedString(forKey: key, value: nil, table: nil)
    }
    
    // 私有方法：广播语言变更
    private func broadcastLanguageChange(code: String) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .localeChanged, object: code)
        }
    }
    
    func getLastUpdateTime() -> Date {
        return lastUpdateTime
    }
    
    func isLanguageInitialized() -> Bool {
        return isInitialized
    }
    
    func clearCache() {
        cacheManager.clearCache()
    }
}

// 语言缓存管理器
private struct LanguageCacheManager {
    func updateCache(code: String) {
        // 模拟缓存更新
        UserDefaults.standard.set(Date(), forKey: "lastLanguageUpdate")
    }
    
    func clearCache() {
        UserDefaults.standard.removeObject(forKey: "lastLanguageUpdate")
    }
}

// 语言变更通知
extension Notification.Name {
    static let localeChanged = Notification.Name("localeChanged")
}

// Bundle 扩展：管理本地化资源
extension Bundle {
    static var _activeBundle: Bundle?
    
    static var localizedBundle: Bundle {
        return _activeBundle ?? .main
    }
}

// 全局本地化函数
func LocalizedText(_ key: String) -> String {
    return Bundle.localizedBundle.localizedString(forKey: key, value: nil, table: nil)
}

// 视图修饰符：绑定语言环境
struct LocaleBindingModifier: ViewModifier {
    @ObservedObject private var manager = LocaleDao.shared
    
    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .localeChanged)) { _ in
                // 强制刷新 UI
                DispatchQueue.main.async {
                    manager.objectWillChange.send()
                }
            }
            .onAppear {
                // 确保初始状态正确
                _ = manager.activeCode
            }
    }
}

extension View {
    func bindLocale() -> some View {
        self.modifier(LocaleBindingModifier())
    }
}
