//
//  LaunchViewModel.swift
//  NeonVPN
//
//  Created by Stephen Schaaf on 2025/11/17.
//

import Foundation
import Alamofire

@MainActor
final class LaunchViewModel: ObservableObject {
    @Published var progress: Double = 0
    @Published var startupAdReady: Bool = false
    
    private weak var launchManager: LaunchManager?
    private var reachability: NetworkReachabilityManager?
    private var progressTimer: Timer?
    private var startDate: Date?
    private var timeoutTask: Task<Void, Never>?
    
    private let totalDuration: TimeInterval = 20.0
    
    private var hasStarted = false
    private var hasTriggeredRequests = false
    private var hasCompleted = false
    
    func begin(with manager: LaunchManager) {
        guard !hasStarted else { return }
        hasStarted = true
        launchManager = manager
        
        startProgressTimer()
        startTimeout()
        startNetworkListening()
    }
    
    private func startNetworkListening() {
        reachability = NetworkReachabilityManager()
        reachability?.startListening(onUpdatePerforming: { [weak self] status in
            guard let self else { return }
            switch status {
            case .reachable(.cellular), .reachable(.ethernetOrWiFi):
                debugPrint("[Launch] 网络已连接，开始请求配置")
                self.beginRequestsIfNeeded()
            case .notReachable:
                debugPrint("[Launch] 当前网络不可达")
            case .unknown:
                debugPrint("[Launch] 网络状态未知")
            }
        })
    }
    
    private func beginRequestsIfNeeded() {
        guard !hasTriggeredRequests else { return }
        hasTriggeredRequests = true
        
        Task {
            await NetCenter.shared.getConfigPolicy()
            await NetCenter.shared.getAdsProxy()
            let adReady = await loadStartupAdsWithPriority()
            startupAdReady = adReady
            completeIfNeeded()
        }
    }
    
    private func startProgressTimer() {
        startDate = Date()
        progressTimer?.invalidate()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self, !self.hasCompleted else { return }
            let elapsed = Date().timeIntervalSince(self.startDate ?? Date())
            let percent = min(100.0, (elapsed / self.totalDuration) * 100.0)
            self.progress = percent
        }
        if let timer = progressTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    private func startTimeout() {
        timeoutTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: UInt64(totalDuration * 1_000_000_000))
            self.completeIfNeeded()
        }
    }
    
    private func completeIfNeeded() {
        guard !hasCompleted else { return }
        hasCompleted = true
        
        timeoutTask?.cancel()
        progressTimer?.invalidate()
        reachability?.stopListening()
        reachability = nil
        
        progress = 100
        launchManager?.completeLaunch()
    }
    
    // MARK: - 广告加载
    
    private func loadStartupAdsWithPriority() async -> Bool {
        return await loadInterstitialAd()
    }
    
    private func loadInterstitialAd() async -> Bool {
        await withCheckedContinuation { continuation in
            var resumed = false
            AdCoordinator.instance.loadInYa {
                guard !resumed else { return }
                resumed = true
                continuation.resume(returning: true)
            } onFailed: {
                guard !resumed else { return }
                resumed = true
                continuation.resume(returning: false)
            }
        }
    }
}

