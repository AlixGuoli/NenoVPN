//
//  AdmobInterstitialService.swift
//  NeonVPN
//
//  Created by Stephen Schaaf on 2025/11/18.
//

import Foundation
import GoogleMobileAds
import UIKit

/// 负责管理 Google AdMob 插屏广告的加载与展示。
final class AdmobInterstitialService: NSObject {
    
    // MARK: - Callbacks
    
    /// 广告拉取成功时回调。
    var onContentReady: (() -> Void)?
    /// 广告拉取失败时回调。
    var onContentFailed: (() -> Void)?
    
    /// 本次展示后是否再拉一条（断开场景由 AdCoordinator 设为 false）
    var reloadAfterPresent: Bool = true
    
    // MARK: - Private State
    private var contentKeys: [String] = []
    private var isFetching = false
    private var currentContent: InterstitialAd?
    private var activeContent: InterstitialAd?
    private var fetchTimestamp: Date?
    
    // MARK: - Internal Utilities
    
    private func extractKeys() {
        let rawKeys = AdVault.shared.admobInt()
        contentKeys = rawKeys
            .split(separator: ";")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
    
    private func handleFailure() {
        isFetching = false
        fetchTimestamp = nil
        onContentFailed?()
    }
    
    private func canStartFetch() -> Bool {
        if currentContent != nil { return false }
        if isFetching {
            guard let ts = fetchTimestamp else { return false }
            return Date().timeIntervalSince(ts) > 120
        }
        return true
    }
    
    // MARK: - Public Helpers
    
    var isReady: Bool {
        return currentContent != nil
    }
    
    func clear() {
        currentContent = nil
        activeContent = nil
        isFetching = false
        fetchTimestamp = nil
    }
    
    // MARK: - Load
    
    /// 触发插屏加载流程。
    func fetchContent(moment: String? = nil) {
        guard canStartFetch() else {
            debugPrint("[ADS] [AdMob] 跳过加载，正在加载或已有缓存")
            return
        }
        
        extractKeys()
        guard !contentKeys.isEmpty else {
            debugPrint("[ADS] [AdMob] 无可用的广告 key")
            onContentFailed?()
            return
        }
        
        isFetching = true
        fetchTimestamp = Date()
        tryFetch(at: 0, moment: moment)
    }
    
    private func tryFetch(at index: Int, moment: String?) {
        guard index < contentKeys.count else {
            debugPrint("[ADS] [AdMob] 加载失败: 所有 key 均失败")
            handleFailure()
            return
        }
        
        let contentId = contentKeys[index]
        debugPrint("[ADS] [AdMob] 开始加载: \(contentId)")
        
        EventLogger.shared.logAdvertisement(moment: NetProfile.EventKeys.KEY_AD_START, adMoment: moment)
        
        let request = Request()
        InterstitialAd.load(with: contentId, request: request) { [weak self] ad, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let ad = ad {
                    self.currentContent = ad
                    ad.fullScreenContentDelegate = self
                    self.isFetching = false
                    self.fetchTimestamp = nil
                    EventLogger.shared.logAdvertisement(moment: NetProfile.EventKeys.KEY_AD_SUCCESS, key: contentId, adMoment: moment)
                    self.onContentReady?()
                    debugPrint("[ADS] [AdMob] 加载成功: \(contentId)")
                } else {
                    debugPrint("[ADS] [AdMob] 加载失败: \(contentId) - \(error?.localizedDescription ?? "未知错误")")
                    self.tryFetch(at: index + 1, moment: moment)
                }
            }
        }
    }
    
    func refresh(moment: String? = nil) {
        currentContent = nil
        fetchContent(moment: moment)
    }
    
    // MARK: - Present
    
    func display(from controller: UIViewController, moment: String?) {
        guard let ad = currentContent else {
            debugPrint("[ADS] [AdMob] 无广告可展示")
            onContentFailed?()
            return
        }
        let contentUnitId = ad.adUnitID
        activeContent = ad
        currentContent = nil
        // 上报展示广告
        EventLogger.shared.logAdvertisement(moment: NetProfile.EventKeys.KEY_AD_SHOW, key: contentUnitId, adMoment: moment)
        ad.present(from: controller)
    }
}

// MARK: - GADFullScreenContentDelegate

extension AdmobInterstitialService: FullScreenContentDelegate {
    
    func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {
        debugPrint("[ADS] [AdMob] 展示成功")
        AdCoordinator.instance.isActive = true
        activeContent = currentContent
        currentContent = nil
        if reloadAfterPresent {
            refresh(moment: StoreKeys.AdTrigger.closeAd)
        } else {
            debugPrint("[ADS] [AdMob] 断开场景，展示后不重新加载")
            reloadAfterPresent = true
        }
    }
    
    func adDidRecordImpression(_ ad: FullScreenPresentingAd) {
        debugPrint("[ADS] [AdMob] 曝光")
    }
    
    func adDidRecordClick(_ ad: FullScreenPresentingAd) {
        debugPrint("[ADS] [AdMob] 点击")
    }
    
    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        debugPrint("[ADS] [AdMob] 展示失败: \(error.localizedDescription)")
        AdCoordinator.instance.isActive = false
        activeContent = nil
        refresh()
    }
    
    func adWillDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        debugPrint("[ADS] [AdMob] 关闭")
        AdCoordinator.instance.isActive = false
    }
    
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        activeContent = nil
    }
}

