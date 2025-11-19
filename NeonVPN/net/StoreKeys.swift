//
//  StoreKeys.swift
//  NeonVPN
//
//  Created by Stephen Schaaf on 2025/11/11.
//

import Foundation

enum StoreKeys {
    enum Source {
        static let sourceProfile = "nvSourceProfile"
        static let sourceSavedAt = "nvSourceSavedAt"
    }
    
    enum Base {
        static let baseProfile = "nvBaseProfile"
        static let baseSavedAt = "nvBaseSavedAt"
        static let contactLink = "nvContactLink"
        static let profileGitRev = "nvProfileGitRev"
        static let serviceFlag = "nvServiceFlag"
    }
    
    enum Ads {
        static let adYandexBanner = "nvAdYandexBanner"
        static let adYandexInterstitial = "nvAdYandexInterstitial"
        static let adAdmobInterstitial = "nvAdAdmobInterstitial"
        static let adPenetration = "nvAdPenetration"
        static let adClickDelay = "nvAdClickDelay"
        static let adDisabled = "nvAdDisabled"
        static let adVariant = "nvAdVariant"
        static let adSavedAt = "nvAdSavedAt"
    }
    
    enum Service {
        static let serviceProfile = "nvServiceProfile"
    }
    
    enum Server {
        static let chosenServerId = "nvChosenServerId"
    }
}


