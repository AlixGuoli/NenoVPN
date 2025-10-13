import Foundation

enum AppLanguage: String, CaseIterable {
    case english = "en"
    case chineseSimplified = "zh-Hans"
    
    var name: String {
        switch self {
        case .english: return "English"
        case .chineseSimplified: return "简体中文"
        }
    }
    
    var flag: String {
        switch self {
        case .english: return "🇺🇸"
        case .chineseSimplified: return "🇨🇳"
        }
    }
}
