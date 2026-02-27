//
//  YandexEMInterstitialService.swift
//  NeonVPN
//

import Foundation
import YandexMobileAds
import UIKit

/// 管理 Yandex EM 插屏广告的加载与展示（逻辑与原版 Int 一致，仅 key 使用接口 Yandex_EMInt_List）。
final class YandexEMInterstitialService: NSObject {

    // MARK: - Callbacks
    var onContentReady: (() -> Void)?
    var onContentFailed: (() -> Void)?
    var onContentClosed: (() -> Void)?

    // MARK: - Private State
    private var mediaInstance: InterstitialAd?
    private var requestLoader = InterstitialAdLoader()
    private var mediaKeys: [String] = []
    private var isRequesting = false
    private var requestTimestamp: Date?
    private var keyIndex = 0

    override init() {
        super.init()
        requestLoader.delegate = self
    }

    var isReady: Bool {
        return mediaInstance != nil
    }

    func clear() {
        mediaInstance = nil
        isRequesting = false
        requestTimestamp = nil
        keyIndex = 0
    }

    private func extractMediaKeys() {
        let raw = AdVault.shared.emInt()
        mediaKeys = raw
            .split(separator: ";")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func canStartRequest() -> Bool {
        if mediaInstance != nil { return false }
        if isRequesting {
            guard let ts = requestTimestamp else { return false }
            return Date().timeIntervalSince(ts) > 100
        }
        return true
    }

    private func requestMedia(at index: Int) {
        guard index < mediaKeys.count else {
            debugPrint("[ADS][EM插屏] 加载失败: 所有 key 均失败")
            handleRequestFailure()
            return
        }

        let mediaId = mediaKeys[index]
        debugPrint("[ADS][EM插屏] 开始加载: \(mediaId)")
        let config = AdRequestConfiguration(adUnitID: mediaId)
        requestLoader.loadAd(with: config)
    }

    private func handleRequestFailure() {
        isRequesting = false
        requestTimestamp = nil
        onContentFailed?()
    }

    private func attemptNextKey() {
        keyIndex += 1
        requestMedia(at: keyIndex)
    }

    func fetchContent(moment: String? = nil) {
        guard canStartRequest() else {
            debugPrint("[ADS][EM插屏] 跳过加载，状态不满足")
            return
        }

        extractMediaKeys()
        guard !mediaKeys.isEmpty else {
            debugPrint("[ADS][EM插屏] 无可用的广告 key")
            onContentFailed?()
            return
        }

        isRequesting = true
        requestTimestamp = Date()
        keyIndex = 0
        requestMedia(at: keyIndex)
    }

    func refresh(moment: String? = nil) {
        mediaInstance = nil
        fetchContent(moment: moment)
    }

    func display(from controller: UIViewController) {
        guard let ad = mediaInstance else {
            debugPrint("[ADS][EM插屏] 无广告可展示")
            onContentFailed?()
            return
        }
        ad.show(from: controller)
    }
}

// MARK: - InterstitialAdLoaderDelegate

extension YandexEMInterstitialService: InterstitialAdLoaderDelegate {
    func interstitialAdLoader(_ adLoader: InterstitialAdLoader, didLoad interstitialAd: InterstitialAd) {
        let mediaId = interstitialAd.adInfo?.adUnitId ?? "-"
        debugPrint("[ADS][EM插屏] 加载成功: \(mediaId)")
        isRequesting = false
        requestTimestamp = nil
        mediaInstance = interstitialAd
        interstitialAd.delegate = self
        onContentReady?()
    }

    func interstitialAdLoader(_ adLoader: InterstitialAdLoader, didFailToLoadWithError error: AdRequestError) {
        let mediaId = error.adUnitId ?? "-"
        debugPrint("[ADS][EM插屏] 加载失败: \(mediaId) - \(error.error.localizedDescription)")
        attemptNextKey()
    }
}

// MARK: - InterstitialAdDelegate

extension YandexEMInterstitialService: InterstitialAdDelegate {
    func interstitialAd(_ interstitialAd: InterstitialAd, didFailToShowWithError error: Error) {
        debugPrint("[ADS][EM插屏] 展示失败: \(error.localizedDescription)")
        AdCoordinator.instance.isActive = false
        mediaInstance = nil
        refresh()
    }

    func interstitialAdDidShow(_ interstitialAd: InterstitialAd) {
        debugPrint("[ADS][EM插屏] 展示成功")
        AdCoordinator.instance.isActive = true
    }

    func interstitialAdDidDismiss(_ interstitialAd: InterstitialAd) {
        debugPrint("[ADS][EM插屏] 关闭")
        onContentClosed?()
        mediaInstance = nil
        AdCoordinator.instance.isActive = false
        AdCoordinator.instance.loadAllAds(moment: StoreKeys.AdTrigger.closeAd)
    }

    func interstitialAdDidClick(_ interstitialAd: InterstitialAd) {
        debugPrint("[ADS][EM插屏] 点击")
    }

    func interstitialAd(_ interstitialAd: InterstitialAd, didTrackImpressionWith impressionData: ImpressionData?) {
        debugPrint("[ADS][EM插屏] 曝光")
    }
}
