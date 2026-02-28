//
//  NetCenter.swift
//  NeonVPN
//
//  Created by Stephen Schaaf on 2025/11/10.
//

import Foundation
import Alamofire

final class NetCenter {
    static let shared = NetCenter()
    
    // MARK: - 配置
    
    private let baseURL = "" // TODO: 待配置
    private lazy var session: Session = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 5
        cfg.timeoutIntervalForResource = 5
        return Session(configuration: cfg)
    }()
    
    private init() {}
    
    // MARK: - 接口方法
    
    /// 获取配置策略
    func getConfigPolicy() async {
        debugPrint("[NET] 开始请求基本配置")
        let params = NetProfile.shared.params()
        
        guard let baseConf = await requestWithRetry(path: NetProfile.API.configPolicy, params: params),
              !baseConf.isEmpty else {
            debugPrint("[NET] !!! 获取基本配置失败")
            return
        }
        
        debugPrint("[NET] ✅ 获取基本配置成功")
        debugPrint("[NET] 配置内容: \(baseConf)")
        
        await processBaseConfig(baseConf)
    }
    
    /// 获取广告配置
    func getAdsProxy() async {
        debugPrint("[NET] 开始请求广告配置")
        let params = NetProfile.shared.params()
        
        guard let adsConf = await requestWithRetry(path: NetProfile.API.adsProxy, params: params),
              !adsConf.isEmpty else {
            debugPrint("[NET] !!! 获取广告配置失败")
            return
        }
        
        debugPrint("[NET] ✅ 获取广告配置成功")
        debugPrint("[NET] 配置内容: \(adsConf)")
        
        await processAdsConfig(adsConf)
    }
    
    /// 获取服务端点配置
    /// - Parameters:
    ///   - group: 节点分组 ID（-1 表示 Auto/随机）
    ///   - vip: 是否会员，1=是 0=否
    /// - Returns: 配置字符串（加密的），失败返回 nil
    func getServiceEndpoint(group: Int = -1, vip: Int = 0) async -> String? {
        debugPrint("[NET] 开始请求服务端点配置 group=\(group) vip=\(vip)")
        
        // 合并基本参数和额外参数
        var allParams: [String: Any] = [:]
        for (key, value) in NetProfile.shared.params() {
            allParams[key] = value
        }
        allParams["group"] = group
        allParams["vip"] = vip
        
        guard let serviceConf = await requestWithRetry(path: NetProfile.API.serviceEndpoint, params: allParams),
              !serviceConf.isEmpty else {
            debugPrint("[NET] !!! 获取服务端点配置失败")
            return nil
        }
        
        debugPrint("[NET] ✅ 获取服务端点配置成功")
        debugPrint("[NET] 配置内容: \(serviceConf)")
        
        return serviceConf
    }

    // MARK: - 节点拓扑

    /// 获取节点拓扑列表：调用 /mesh/category/circuit，解析为 NodeVault.Node 数组并保存到 NodeVault。
    func fetchNodeTopology() async -> [NodeVault.Node] {
        debugPrint("[NET] 开始请求节点拓扑 /mesh/category/circuit")

        let params = NetProfile.shared.params()
        guard let json = await requestWithRetry(path: NetProfile.API.groupTopology, params: params),
              !json.isEmpty else {
            debugPrint("[NET] !!! 获取节点拓扑失败")
            return []
        }

        guard let data = json.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let categories = root["categories"] as? [[String: Any]] else {
            debugPrint("[NET] !!! 节点拓扑 JSON 解析失败")
            return []
        }

        var nodes: [NodeVault.Node] = []

        for category in categories {
            guard let nodeArray = category["nodes"] as? [[String: Any]] else { continue }
            for nodeDict in nodeArray {
                guard let id = nodeDict["id"] as? Int,
                      let name = nodeDict["name"] as? String,
                      let country = nodeDict["country"] as? String else {
                    continue
                }
                let countryCode = country.uppercased()
                nodes.append(NodeVault.Node(id: id, name: name, countryCode: countryCode))
            }
        }

        guard !nodes.isEmpty else {
            debugPrint("[NET] 节点拓扑解析结果为空")
            return []
        }

        NodeVault.shared.storeNodes(nodes)
        debugPrint("[NET] ✅ 节点拓扑解析成功: \(nodes.count) 个节点")
        return nodes
    }
    
    // MARK: - 主请求流程
    
    // 请求并重试：获取配置 → 尝试请求 → 失败则更新Git → 重试
    private func requestWithRetry(
        path: String,
        params: [String: Any]
    ) async -> String? {
        debugPrint("[NET] 获取配置信息")
        guard let cfg = SourceVault.shared.ensure() else {
            debugPrint("[NET] !!! 获取配置失败，无可用配置")
            return nil
        }
        debugPrint("[NET] 配置获取成功")
        
        // 第一次尝试
        debugPrint("[NET] 使用配置尝试请求")
        if let result = await requestWithHosts(path: path, params: params, config: cfg) {
            return result
        }
        
        // 失败则更新Git
        debugPrint("[NET] !!! 请求失败，更新 Git 配置")
        let updateSuccess = await refreshConfigFromGit(currentConfig: cfg)
        guard updateSuccess else {
            debugPrint("[NET] !!! Git 更新失败，请求终止")
            return nil
        }
        
        // 用新配置重试
        debugPrint("[NET] 使用更新后的配置重试")
        guard let refreshedConfig = SourceVault.shared.load() else {
            return nil
        }
        return await requestWithHosts(path: path, params: params, config: refreshedConfig)
    }
    
    // MARK: - 使用配置请求
    
    // 遍历host列表请求
    private func requestWithHosts(
        path: String,
        params: [String: Any],
        config: String
    ) async -> String? {
        let hostList = SourceVault.shared.endpoints(from: config)
        guard !hostList.isEmpty else {
            debugPrint("[NET] !!! 无法获取 host 列表")
            return nil
        }
        debugPrint("[NET] 获取到 \(hostList.count) 个 host，开始遍历")
        
        for (index, host) in hostList.enumerated() {
            debugPrint("[NET] 尝试第 \(index + 1) 个 host: \(host)")
            let requestUrl = assembleUrl(base: "\(host)\(path)", params: params)
            debugPrint("[NET] 完整请求 URL: \(requestUrl)")
            
            if let response = await sendRequest(url: requestUrl) {
                // 判断是否是服务配置接口
                let isValid: Bool
                if path.contains(NetProfile.API.serviceEndpoint) {
                    // 服务配置接口：先解密再验证
                    debugPrint("[NET] 检测到服务配置接口，先解密再验证")
                    guard let decrypted = NetProfile.Sec.reveal(response) else {
                        debugPrint("[NET] !!! 服务配置解密失败")
                        continue
                    }
                    isValid = isValidJson(decrypted)
                } else {
                    // 其他接口：直接验证
                    isValid = isValidJson(response)
                }
                
                if isValid {
                    debugPrint("[NET] ✅ 请求成功，url: \(requestUrl)")
                    return response  // 返回原始响应（加密的）
                } else {
                    debugPrint("[NET] ❌ 响应格式无效，url: \(requestUrl)")
                }
            } else {
                debugPrint("[NET] ❌ 请求失败，url: \(requestUrl)")
            }
        }
        
        return nil
    }
    
    // MARK: - 底层请求
    
    // 发送HTTP请求
    private func sendRequest(url: String) async -> String? {
        guard let urlObj = URL(string: url) else {
            debugPrint("[NET] !!! URL 格式错误: \(url)")
            return nil
        }
        
        var urlRequest = URLRequest(url: urlObj)
        urlRequest.timeoutInterval = 5.0
        
        var completed = false
        
        // 倒计时
        Task {
            for countdown in (1...5).reversed() {
                if completed { break }
                debugPrint("[NET] 请求超时倒计时: \(countdown) 秒")
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
        
        return await withCheckedContinuation { continuation in
            session.request(urlRequest)
                .validate(statusCode: 200..<300)
                .responseString { response in
                    completed = true
                    let result = response.value
                    continuation.resume(returning: result)
                }
        }
    }
    
    // MARK: - Git更新
    
    // 从Git源刷新配置
    private func refreshConfigFromGit(currentConfig: String) async -> Bool {
        // 先尝试当前配置的Git源
        let currentGitSources = SourceVault.shared.sources(from: currentConfig)
        if !currentGitSources.isEmpty {
            debugPrint("[NET] 从当前配置获取到 \(currentGitSources.count) 个 Git 源")
            if await tryRefreshFromGitList(currentGitSources) {
                return true
            }
        }
        
        // 再尝试本地配置的Git源
        debugPrint("[NET] 当前配置 Git 源失败，尝试本地配置的 Git 源")
        guard let localConfig = SourceVault.shared.load() ?? SourceVault.shared.ensure() else {
            return false
        }
        
        let localGitSources = SourceVault.shared.sources(from: localConfig)
        if !localGitSources.isEmpty {
            debugPrint("[NET] 从本地配置获取到 \(localGitSources.count) 个 Git 源")
            return await tryRefreshFromGitList(localGitSources)
        }
        
        debugPrint("[NET] !!! 所有 Git 源更新失败")
        return false
    }
    
    // 尝试从Git源列表刷新
    private func tryRefreshFromGitList(_ gitSources: [String]) async -> Bool {
        for gitUrl in gitSources {
            debugPrint("[NET] 尝试 Git 源: \(gitUrl)")
            if await refreshFromSingleGit(gitUrl: gitUrl) {
                return true
            }
        }
        return false
    }
    
    // 从单个Git源刷新：请求 → 解密 → 验证 → 保存
    private func refreshFromSingleGit(gitUrl: String) async -> Bool {
        guard let encryptedData = await sendRequest(url: gitUrl) else {
            debugPrint("[NET] ❌ Git 源请求失败: \(gitUrl)")
            return false
        }
        
        debugPrint("[NET] Git 请求成功")
        debugPrint("[NET] Git 返回原始内容（加密）: \(encryptedData)")
        debugPrint("[NET] Git 返回内容长度: \(encryptedData.count)")
        
        guard let decryptedData = NetProfile.Sec.reveal(encryptedData) else {
            debugPrint("[NET] !!! Git 配置解密失败")
            return false
        }
        
        debugPrint("[NET] Git 配置解密成功")
        debugPrint("[NET] Git 解密后内容: \(decryptedData)")
        debugPrint("[NET] Git 解密后内容长度: \(decryptedData.count)")
        
        guard isValidJson(decryptedData) else {
            debugPrint("[NET] !!! Git 配置格式无效")
            return false
        }
        
        debugPrint("[NET] Git 配置格式有效，保存配置")
        SourceVault.shared.store(decryptedData)
        return true
    }
    
    // MARK: - 基本配置处理
    
    private func processBaseConfig(_ baseConf: String) async {
        // 保存配置
        BaseVault.shared.store(baseConf)
        let savedTime = UserDefaults.standard.object(forKey: StoreKeys.Base.baseSavedAt) as? Date ?? Date()
        debugPrint("[NET] 基本配置时间戳已保存: \(formatDate(savedTime))")
        
        // 检查 Git 版本并更新
        guard let newGitVersion = BaseVault.shared.rev() else {
            debugPrint("[NET] !!! 无法获取 Git 版本")
            return
        }
        
        let currentGitVersion = UserDefaults.standard.integer(forKey: StoreKeys.Base.profileGitRev)
        debugPrint("[NET] 当前 Git 版本: \(currentGitVersion), 新版本: \(newGitVersion)")
        
        if newGitVersion > currentGitVersion {
            debugPrint("[NET] 检测到新版本，开始更新 Git 配置")
            let updateSuccess = await refreshConfigFromGit(currentConfig: baseConf)
            
            if updateSuccess {
                UserDefaults.standard.set(newGitVersion, forKey: StoreKeys.Base.profileGitRev)
                UserDefaults.standard.synchronize()
                debugPrint("[NET] ✅ Git 更新成功，版本号已更新: \(newGitVersion)")
            } else {
                debugPrint("[NET] ❌ Git 更新失败，版本号未更新")
            }
        } else {
            debugPrint("[NET] Git 版本未变化，跳过更新")
        }
        
        // 提取并保存各种配置字段
        let adIsOff = BaseVault.shared.adState()
        let adType = BaseVault.shared.adVariant()
        let tgLink = BaseVault.shared.contactLink()
        let hotcode = BaseVault.shared.serviceFlag()
        
        debugPrint("[NET] 提取的配置字段:")
        debugPrint("[NET]   adIsOff: \(String(describing: adIsOff))")
        debugPrint("[NET]   adType: \(String(describing: adType))")
        debugPrint("[NET]   tgLink: \(String(describing: tgLink))")
        debugPrint("[NET]   hotcode: \(String(describing: hotcode))")
        
        if let adIsOff = adIsOff {
            AdVault.shared.storeDisabled(adIsOff)
        }
        
        if let adType = adType {
            AdVault.shared.storeVariant(adType)
        }
        
        if let tgLink = tgLink {
            BaseVault.shared.storeContactLink(tgLink)
            debugPrint("[NET] ✅ contactLink 已保存")
        }
        
        BaseVault.shared.persistFlagIfNeeded(hotcode)
        if BaseVault.shared.savedFlag() != nil {
            debugPrint("[NET] ✅ flag 已保存（永久）")
        }
        
        debugPrint("[NET] ✅ 基本配置处理完成")
    }
    
    /// 处理广告配置
    private func processAdsConfig(_ adsConf: String) async {
        // 1. 解析配置
        guard let config = AdVault.shared.parseConfig(from: adsConf),
              let adMixed = AdVault.shared.parseMixed(from: config) else {
            debugPrint("[NET] !!! 广告配置解析失败")
            return
        }
        
        debugPrint("[NET] 广告配置解析成功，adMixed 数量: \(adMixed.count)")
        
        // 2. 提取并保存 Yandex Banner 配置
        if let bannerConfig = AdVault.shared.parseBannerConfig(from: adMixed) {
            AdVault.shared.storeBannerKey(bannerConfig.key)
            AdVault.shared.storePenetration(penetrate: bannerConfig.penetrate, clickDelay: bannerConfig.clickDelay)
            debugPrint("[NET] ✅ Yandex Banner 配置已保存")
            debugPrint("[NET]   key: \(bannerConfig.key ?? "nil")")
            debugPrint("[NET]   penetrate: \(bannerConfig.penetrate ?? -1)")
            debugPrint("[NET]   clickDelay: \(bannerConfig.clickDelay ?? -1)")
        }
        
        // 3. 提取并保存 Yandex Int 配置
        if let intKey = AdVault.shared.parseYandexInt(from: adMixed) {
            AdVault.shared.storeYandexIntKey(intKey)
            debugPrint("[NET] ✅ Yandex Int 配置已保存")
            debugPrint("[NET]   key: \(intKey)")
        }
        
        // 3b. 提取并保存 EM Int 配置（Yandex_EMInt_List）
        if let emIntKey = AdVault.shared.parseEMInt(from: adMixed) {
            AdVault.shared.storeEMIntKey(emIntKey)
            debugPrint("[NET] ✅ Yandex EM Int 配置已保存")
            debugPrint("[NET]   key: \(emIntKey)")
        }
        
        // 4. 提取并保存 AdMob Int 配置
        if let admobKey = AdVault.shared.parseAdmobInt(from: adMixed) {
            AdVault.shared.storeAdmobIntKey(admobKey)
            debugPrint("[NET] ✅ AdMob Int 配置已保存")
            debugPrint("[NET]   key: \(admobKey)")
        }
        
        // 5. 保存配置时间戳
        AdVault.shared.saveTimestamp()
        let savedTime = AdVault.shared.savedTimestamp() ?? Date()
        debugPrint("[NET] 广告配置时间戳已保存: \(formatDate(savedTime))")
        
        debugPrint("[NET] ✅ 广告配置处理完成")
    }
    
    // MARK: - 工具方法
    
    // 格式化日期
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }
    
    // 组装完整 URL（手动拼接参数）
    private func assembleUrl(base: String, params: [String: Any]) -> String {
        guard !params.isEmpty else { return base }
        let query = params.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        return "\(base)?\(query)"
    }
    
    // 验证 JSON 格式
    private func isValidJson(_ jsonString: String) -> Bool {
        guard !jsonString.isEmpty, jsonString != "{}" else {
            return false
        }
        guard let data = jsonString.data(using: .utf8) else {
            return false
        }
        do {
            _ = try JSONSerialization.jsonObject(with: data)
            return true
        } catch {
            return false
        }
    }
    
    // MARK: - 连接验证
    
    /// 检查网络连通性
    func checkConnectivity() async -> Bool {
        debugPrint("[NET] ----- 开始测试 Google -----")
        let targetUrls = obtainTestUrls()
        return await runConcurrentCheck(urls: targetUrls)
    }
    
    /// 获取测试 URL 列表
    private func obtainTestUrls() -> [String] {
        var targetUrls: [String] = []
        
        if let serverList = BaseVault.shared.nodes(), !serverList.isEmpty {
            targetUrls = serverList
            debugPrint("[NET] 使用服务器列表进行验证，数量: \(serverList.count)")
        } else {
            targetUrls = ["", ""]
            debugPrint("[NET] 使用默认 URL 进行验证")
        }
        
        debugPrint("[NET] 目标 URL: \(targetUrls)")
        return targetUrls
    }
    
    /// 并发检查 URL 连通性
    private func runConcurrentCheck(urls: [String]) async -> Bool {
        let syncGroup = DispatchGroup()
        var connectionEstablished = false
        var pendingRequests: [URLSessionTask] = []
        var requestUrlMapping: [URLSessionTask: String] = [:]
        
        debugPrint("[NET] 开始并发网络请求...")
        
        for url in urls {
            syncGroup.enter()
            let networkTask = AF.request(url, method: .get)
                .validate(statusCode: 0..<1000)
                .response { response in
                    switch response.result {
                    case .success:
                        debugPrint("[NET] 网络检查成功，URL: \(url)")
                        connectionEstablished = true
                        AF.session.getAllTasks { tasks in
                            tasks.forEach { task in
                                if let url = requestUrlMapping[task] {
                                    debugPrint("[NET] 取消任务，URL: \(url)")
                                }
                                task.cancel()
                            }
                        }
                    case .failure(let error):
                        debugPrint("[NET] 网络检查失败，URL: \(url), 错误: \(error.localizedDescription)")
                    }
                    syncGroup.leave()
                }
            
            if let task = networkTask.task {
                pendingRequests.append(task)
                requestUrlMapping[task] = url
                debugPrint("[NET] 添加网络任务，URL: \(url)")
            }
        }
        
        debugPrint("[NET] 等待网络响应，10 秒超时...")
        let timeoutResult = syncGroup.wait(timeout: .now() + 10)
        
        if timeoutResult == .timedOut {
            debugPrint("[NET] 网络验证超时，取消所有任务")
            AF.session.getAllTasks { tasks in
                tasks.forEach { task in
                    if let url = requestUrlMapping[task] {
                        debugPrint("[NET] 取消超时任务，URL: \(url)")
                    }
                    task.cancel()
                }
            }
        } else {
            debugPrint("[NET] 网络验证在超时内完成")
        }
        
        debugPrint("[NET] 网络验证结果: \(connectionEstablished ? "成功" : "失败")")
        debugPrint("[NET] ----- 网络连接验证完成 -----")
        
        return connectionEstablished
    }
}
