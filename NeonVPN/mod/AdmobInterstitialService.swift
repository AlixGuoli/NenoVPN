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
    var onAdReady: (() -> Void)?
    /// 广告拉取失败时回调。
    var onAdFailed: (() -> Void)?
    
    // MARK: - Private State
    
    private var interstitial: InterstitialAd?
    private var presentingAd: InterstitialAd?
    private var availableKeys: [String] = []
    private var isLoading = false
    private var loadTimestamp: Date?
    
    // MARK: - Public Helpers
    
    var isPrepared: Bool {
        return interstitial != nil
    }
    
    func reset() {
        interstitial = nil
        presentingAd = nil
        isLoading = false
        loadTimestamp = nil
    }
    
    // MARK: - Load
    
    /// 触发插屏加载流程。
    func loadAd(moment: String? = nil) {
        guard shouldBeginLoading() else {
            debugPrint("[ADS] [AdMob] 跳过加载，正在加载或已有缓存")
            return
        }
        
        prepareKeys()
        guard !availableKeys.isEmpty else {
            debugPrint("[ADS] [AdMob] 无可用的广告 key")
            onAdFailed?()
            return
        }
        
        isLoading = true
        loadTimestamp = Date()
        attemptLoad(at: 0, moment: moment)
    }
    
    func reload(moment: String? = nil) {
        interstitial = nil
        loadAd(moment: moment)
    }
    
    // MARK: - Present
    
    func present(from controller: UIViewController, moment: String?) {
        guard let ad = interstitial else {
            debugPrint("[ADS] [AdMob] 无广告可展示")
            onAdFailed?()
            return
        }
        let adUnitID = ad.adUnitID
        presentingAd = ad
        interstitial = nil
        // 上报展示广告
        EventLogger.shared.logAdvertisement(moment: NetProfile.EventKeys.KEY_AD_SHOW, key: adUnitID, adMoment: moment)
        ad.present(from: controller)
    }
    
    // MARK: - Private
    
    private func prepareKeys() {
        let rawKeys = AdVault.shared.admobInt()
        availableKeys = rawKeys
            .split(separator: ";")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
    
    private func shouldBeginLoading() -> Bool {
        if interstitial != nil { return false }
        if isLoading {
            guard let ts = loadTimestamp else { return false }
            // 若加载超过 120 秒仍未完成，允许重试
            return Date().timeIntervalSince(ts) > 120
        }
        return true
    }
    
    private func attemptLoad(at index: Int, moment: String?) {
        guard index < availableKeys.count else {
            debugPrint("[ADS] [AdMob] 加载失败: 所有 key 均失败")
            finishFailure()
            return
        }
        
        let unitID = availableKeys[index]
        debugPrint("[ADS] [AdMob] 开始加载: \(unitID)")
        
        // 上报开始加载
        EventLogger.shared.logAdvertisement(moment: NetProfile.EventKeys.KEY_AD_START, adMoment: moment)
        
        let request = Request()
        InterstitialAd.load(with: unitID, request: request) { [weak self] ad, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let ad = ad {
                    self.interstitial = ad
                    ad.fullScreenContentDelegate = self
                    self.isLoading = false
                    self.loadTimestamp = nil
                    // 上报加载成功
                    EventLogger.shared.logAdvertisement(moment: NetProfile.EventKeys.KEY_AD_SUCCESS, key: unitID, adMoment: moment)
                    self.onAdReady?()
                    debugPrint("[ADS] [AdMob] 加载成功: \(unitID)")
                } else {
                    debugPrint("[ADS] [AdMob] 加载失败: \(unitID) - \(error?.localizedDescription ?? "未知错误")")
                    self.attemptLoad(at: index + 1, moment: moment)
                }
            }
        }
    }
    
    private func finishFailure() {
        isLoading = false
        loadTimestamp = nil
        onAdFailed?()
    }
}

// MARK: - GADFullScreenContentDelegate

extension AdmobInterstitialService: FullScreenContentDelegate {
    
    func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {
        debugPrint("[ADS] [AdMob] 展示成功")
        AdsManager.shared.isShowingAd = true
        presentingAd = interstitial
        interstitial = nil
        reload(moment: AdMoment.closeAd)
    }
    
    func adDidRecordImpression(_ ad: FullScreenPresentingAd) {
        debugPrint("[ADS] [AdMob] 曝光")
    }
    
    func adDidRecordClick(_ ad: FullScreenPresentingAd) {
        debugPrint("[ADS] [AdMob] 点击")
    }
    
    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        debugPrint("[ADS] [AdMob] 展示失败: \(error.localizedDescription)")
        AdsManager.shared.isShowingAd = false
        presentingAd = nil
        reload()
    }
    
    func adWillDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        debugPrint("[ADS] [AdMob] 关闭")
        AdsManager.shared.isShowingAd = false
    }
    
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        presentingAd = nil
    }
}

