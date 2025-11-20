//
//  YandexBannerService.swift
//  NeonVPN
//
//  Created by Stephen Schaaf on 2025/11/18.
//

import Foundation
import UIKit
import YandexMobileAds

/// 负责加载与展示 Yandex Banner 广告。
final class YandexBannerService: NSObject {
    
    // MARK: - Callbacks
    var onAdReady: (() -> Void)?
    var onAdFailed: (() -> Void)?
    var onAdClicked: (() -> Void)?
    
    // MARK: - Private State
    private var bannerView: AdView?
    private var adKeys: [String] = []
    private var isLoading = false
    private var loadTimestamp: Date?
    private var currentIndex = 0
    private var prepared = false
    private var overlayClickRelay: (() -> Void)?
    
    // MARK: - Public Helpers
    var isPrepared: Bool { prepared && bannerView != nil }
    
    func reset() {
        bannerView = nil
        prepared = false
        isLoading = false
        loadTimestamp = nil
        currentIndex = 0
    }
    
    func loadBanner() {
        guard shouldBeginLoading() else {
            debugPrint("[ADS] [YandexBanner] 跳过加载，正在加载或已有缓存")
            return
        }
        
        prepareKeys()
        guard !adKeys.isEmpty else {
            debugPrint("[ADS] [YandexBanner] 无可用的广告 key")
            onAdFailed?()
            return
        }
        
        isLoading = true
        loadTimestamp = Date()
        currentIndex = 0
        load(at: currentIndex)
    }
    
    func reload() {
        reset()
        loadBanner()
    }
    
    func currentAdView() -> AdView? {
        return bannerView
    }
    
    func present(from controller: UIViewController) {
        guard let view = bannerView else {
            debugPrint("[ADS] [YandexBanner] 无广告可展示")
            onAdFailed?()
            return
        }
        debugPrint("[ADS] [YandexBanner] 展示成功")
        AdsManager.shared.isShowingAd = true
        let overlay = BannerOverlayController(banner: view,
                                              penetration: AdVault.shared.penetration(),
                                              clickDelay: AdVault.shared.clickDelay())
        overlay.modalPresentationStyle = .fullScreen
        overlay.onClosed = { [weak self] in
            debugPrint("[ADS] [YandexBanner] 关闭")
            AdsManager.shared.isShowingAd = false
            // 每次展示结束后需要准备新广告
            self?.prepared = false
            self?.bannerView = nil
            self?.loadBanner()
        }
        overlayClickRelay = { [weak overlay] in
            overlay?.notifyAdTapped()
        }
        controller.present(overlay, animated: true)
    }
    
    // MARK: - Internal Loading
    private func prepareKeys() {
        adKeys = AdVault.shared.banner()
            .split(separator: ";")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
    
    private func shouldBeginLoading() -> Bool {
        if prepared { return false }
        if isLoading {
            guard let timestamp = loadTimestamp else { return false }
            return Date().timeIntervalSince(timestamp) > 100
        }
        return true
    }
    
    private func load(at index: Int) {
        guard index < adKeys.count else {
            debugPrint("[ADS] [YandexBanner] 加载失败: 所有 key 均失败")
            finishFailure()
            return
        }
        
        let key = adKeys[index]
        debugPrint("[ADS] [YandexBanner] 开始加载: \(key)")
        
        let adSize = calculateAdSize()
        let view = AdView(adUnitID: key, adSize: adSize)
        view.delegate = self
        view.translatesAutoresizingMaskIntoConstraints = false
        view.loadAd()
        bannerView = view
    }
    
    private func calculateAdSize() -> BannerAdSize {
        let width = UIScreen.main.bounds.width
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first
        let safeInsets = window?.safeAreaInsets ?? .zero
        let height = UIScreen.main.bounds.height - safeInsets.top - safeInsets.bottom
        return BannerAdSize.inlineSize(withWidth: width, maxHeight: height)
    }
    
    private func finishFailure() {
        isLoading = false
        loadTimestamp = nil
        bannerView = nil
        onAdFailed?()
    }
    
    private func tryNextKey() {
        currentIndex += 1
        load(at: currentIndex)
    }
}

// MARK: - AdViewDelegate

extension YandexBannerService: AdViewDelegate {
    func adViewDidLoad(_ adView: AdView) {
        debugPrint("[ADS] [YandexBanner] 加载成功: \(adView.adUnitID)")
        prepared = true
        isLoading = false
        loadTimestamp = nil
        onAdReady?()
    }
    
    func adViewDidFailLoading(_ adView: AdView, error: Error) {
        debugPrint("[ADS] [YandexBanner] 加载失败: \(adView.adUnitID) - \(error.localizedDescription)")
        tryNextKey()
    }
    
    func adViewDidClick(_ adView: AdView) {
        debugPrint("[ADS] [YandexBanner] 点击")
        overlayClickRelay?()
        onAdClicked?()
    }
}

// MARK: - Overlay Controller

final class BannerOverlayController: UIViewController {
    
    private let bannerView: UIView
    private let penetrationThreshold: Int
    private let delayThreshold: Int
    
    private var penetrationEnabled = false
    private var delayEnabled = false
    private var countdownTimer = 6
    private var skipContainer = UIView()
    private var skipLabel = UILabel()
    private var timer: Timer?
    private var adTapped = false
    
    var onClosed: (() -> Void)?
    
    init(banner: UIView, penetration: Int, clickDelay: Int) {
        self.bannerView = banner
        self.penetrationThreshold = penetration
        self.delayThreshold = clickDelay
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        registerNotifications()
        setupFlags()
        buildLayout()
        setupSkipUI()
        initializeCountdown()
    }
    
    private func initializeCountdown() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else { return }
            self.processCountdownTick(timer)
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        timer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
    
    func notifyAdTapped() {
        adTapped = true
    }
    
    private func setupFlags() {
        let penetrationThreshold = Int.random(in: 1...100)
        let delayThreshold = Int.random(in: 1...100)
        
        penetrationEnabled = self.penetrationThreshold >= penetrationThreshold
        delayEnabled = self.delayThreshold >= delayThreshold
        
        debugPrint("[ADS] [YandexBanner] 穿透阈值: \(self.penetrationThreshold) | 随机值: \(penetrationThreshold)")
        debugPrint("[ADS] [YandexBanner] 延迟阈值: \(self.delayThreshold) | 随机值: \(delayThreshold)")
    }
    
    private func buildLayout() {
        view.backgroundColor = .white
        view.addSubview(bannerView)
        bannerView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            bannerView.topAnchor.constraint(equalTo: view.topAnchor),
            bannerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bannerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bannerView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func setupSkipUI() {
        skipContainer.translatesAutoresizingMaskIntoConstraints = false
        skipContainer.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        skipContainer.layer.cornerRadius = 10
        view.addSubview(skipContainer)
        
        skipLabel.translatesAutoresizingMaskIntoConstraints = false
        skipLabel.textColor = .white
        skipLabel.font = UIFont(name: "PingFangSC-Regular", size: 14) ?? UIFont.systemFont(ofSize: 14)
        skipLabel.textAlignment = .center
        skipContainer.addSubview(skipLabel)
        
        NSLayoutConstraint.activate([
            skipContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 80),
            skipContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            
            skipLabel.topAnchor.constraint(equalTo: skipContainer.topAnchor, constant: 4),
            skipLabel.leadingAnchor.constraint(equalTo: skipContainer.leadingAnchor, constant: 10),
            skipLabel.bottomAnchor.constraint(equalTo: skipContainer.bottomAnchor, constant: -4),
            skipLabel.trailingAnchor.constraint(equalTo: skipContainer.trailingAnchor, constant: -10),
            skipLabel.heightAnchor.constraint(equalToConstant: 30)
        ])
        
        skipLabel.text = String(format: LocalizedText("Skip_Ad_Time"), countdownTimer)
        
        let interactionEnabled = !penetrationEnabled
        skipLabel.isUserInteractionEnabled = interactionEnabled
        skipContainer.isUserInteractionEnabled = interactionEnabled
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(skipButtonTapped))
        skipLabel.addGestureRecognizer(tapGesture)
    }
    
    private func processCountdownTick(_ timer: Timer) {
        let hasTimeRemaining = countdownTimer > 0
        
        if hasTimeRemaining {
            countdownTimer -= 1
            refreshSkipButtonText()
        } else {
            skipLabel.isUserInteractionEnabled = true
            skipContainer.isUserInteractionEnabled = true
            refreshSkipButtonText()
            timer.invalidate()
        }
    }
    
    private func enableSkipButton() {
        let shouldEnable = !delayEnabled || !penetrationEnabled
        
        if shouldEnable {
            skipLabel.isUserInteractionEnabled = true
            skipContainer.isUserInteractionEnabled = true
        }
    }
    
    private func refreshSkipButtonText() {
        let timeExpired = countdownTimer <= 0
        
        if timeExpired {
            enableSkipButton()
            skipLabel.text = LocalizedText("Skip_Ad")
        } else {
            skipLabel.text = String(format: LocalizedText("Skip_Ad_Time"), countdownTimer)
        }
    }
    
    @objc private func skipButtonTapped() {
        let canSkip = countdownTimer <= 1
        if canSkip {
            dismissOverlay()
        }
    }
    
    private func dismissOverlay() {
        dismiss(animated: true) { [weak self] in
            self?.onClosed?()
        }
    }
    
    private func registerNotifications() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleForeground),
                                               name: UIApplication.willEnterForegroundNotification,
                                               object: nil)
    }
    
    @objc private func handleForeground() {
        guard adTapped else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.dismissOverlay()
        }
    }
}

