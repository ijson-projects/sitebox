//
//  WebView.swift
//  SiteBox
//
//  Created by 崔永旭 on 22/12/2025.
//

import SwiftUI
import WebKit
import Combine
import UserNotifications

/// WebView 封装 - 用于在 SwiftUI 中显示 WKWebView
struct WebView: NSViewRepresentable {
    @ObservedObject var viewModel: WebViewModel
    
    func makeNSView(context: Context) -> WKWebView {
        return viewModel.webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
        // 不需要更新，WebView 由 ViewModel 管理
    }
}

/// WebView 的 ViewModel - 管理 WebView 的状态和行为
class WebViewModel: NSObject, ObservableObject {
    // MARK: - Singleton
    static let shared = WebViewModel()

    // MARK: - Published Properties
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false
    @Published var isLoading: Bool = false
    @Published var currentURL: String = ""
    @Published var loadError: String? = nil

    private var hasLoadedInitialURL = false
    private var hasInjectedImageEnhancements = false
    private var hasInjectedDarkMode = false
    private var notificationObserver: NSObjectProtocol?

    // 定时器引用
    private var autoClearTimer: Timer?

    // 用户设置
    private let defaults = UserDefaults.standard
    
    // 主题管理器
    private let themeManager = ThemeManager.shared

    // MARK: - JS Script Loading
    /// 从 Bundle 加载 JS 脚本内容
    private func loadScript(named name: String) -> String? {
        // 尝试 SiteBox 模块的 bundle
        var bundle = Bundle(for: WebViewModel.self)
        if bundle.bundleIdentifier == nil {
            // Swift Package 或 framework 场景，从主 bundle 加载
            bundle = Bundle.main
        }

        // 查找 Scripts 子目录下的 .js 文件
        if let url = bundle.url(forResource: name, withExtension: "js", subdirectory: "Scripts") {
            return try? String(contentsOf: url, encoding: .utf8)
        }
        // 也支持直接在 Resources 根目录
        if let url = bundle.url(forResource: name, withExtension: "js") {
            return try? String(contentsOf: url, encoding: .utf8)
        }
        print("⚠️ 未找到 JS 脚本: \(name).js")
        return nil
    }

    // 通知权限是否已请求（类级别共享）
    private static var notificationPermissionRequested = false
    
    // MARK: - WebView Configuration
    lazy var webView: WKWebView = {
        // 配置 WebView
        let configuration = WKWebViewConfiguration()

        // 启用持久化存储（保存 Cookie 和登录状态）
        configuration.websiteDataStore = .default()

        // 配置媒体播放策略 - 允许自动播放，隐藏菜单栏音频图标
        configuration.mediaTypesRequiringUserActionForPlayback = []
        
        // 默认启用开发者工具
        configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")
        
        // 注册图片查看器消息处理器
        configuration.userContentController.add(self, name: "imageViewer")
        
        // 创建 WebView
        let webView = CustomWebView(frame: .zero, configuration: configuration)
        
        // 适配 macOS 13.3+ / iOS 16.4+ 的 isInspectable 属性
        if #available(macOS 13.3, iOS 16.4, *) {
            webView.isInspectable = true
        }

        webView.navigationDelegate = self
        webView.uiDelegate = self

        // 允许后退手势
        webView.allowsBackForwardNavigationGestures = true

        // 允许放大缩小
        webView.allowsMagnification = true

        return webView
    }()
    
    // MARK: - Initialization
    override init() {
        super.init()
        loadWebsite()
        requestNotificationPermission()
        setupThemeObserver()
    }
    
    /// 设置主题监听
    private func setupThemeObserver() {
        // 监听主题变化通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleThemeChanged),
            name: NSNotification.Name("WebViewThemeChanged"),
            object: nil
        )
    }

    /// 通知网页视口尺寸已变化（供 AppDelegate 调用）
    func notifyViewportChanged(width: CGFloat, height: CGFloat) {
        let script = """
        (function() {
            var event = new CustomEvent('webapp-viewport-resize', {
                detail: { width: \(Int(width)), height: \(Int(height)) }
            });
            window.dispatchEvent(event);
            // 同时更新 viewport meta（如果有）
            var vp = document.querySelector('meta[name="viewport"]');
            if (vp) {
                vp.setAttribute('content', 'width=\(Int(width)), initial-scale=1.0, maximum-scale=1.0, user-scalable=no');
            }
        })();
        """
        webView.evaluateJavaScript(script) { _, _ in }
    }

    /// 处理主题变化
    @objc private func handleThemeChanged() {
        injectDarkModeCSS()
    }
    
    /// 移除通知监听
    func removeNotificationObserver() {
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
            notificationObserver = nil
        }
    }
    
    deinit {
        removeNotificationObserver()
    }

    /// 请求通知权限（仅请求一次）
    private func requestNotificationPermission() {
        guard !WebViewModel.notificationPermissionRequested else { return }
        WebViewModel.notificationPermissionRequested = true

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("✅ 通知权限已授予")
            } else if let error = error {
                print("❌ 通知权限请求失败: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Public Methods

    /// 加载网站（仅首次）
    func loadWebsite() {
        guard !hasLoadedInitialURL else { return }
        hasLoadedInitialURL = true

        let urlString = defaults.string(forKey: AppConstants.UserDefaultsKeys.webAppURL) ?? AppConstants.DefaultValues.webAppURL
        guard let url = URL(string: urlString) else { return }
        let request = URLRequest(url: url)
        webView.load(request)
    }

    /// 加载指定 URL
    func loadURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        let request = URLRequest(url: url)
        webView.load(request)

        // 保存到设置
        defaults.set(urlString, forKey: AppConstants.UserDefaultsKeys.webAppURL)
    }

    /// 获取当前设置的 URL
    func getSavedURL() -> String {
        return defaults.string(forKey: AppConstants.UserDefaultsKeys.webAppURL) ?? AppConstants.DefaultValues.webAppURL
    }
    
    /// 后退
    func goBack() {
        webView.goBack()
    }
    
    /// 前进
    func goForward() {
        webView.goForward()
    }
    
    /// 刷新
    func reload() {
        if isLoading {
            webView.stopLoading()
        } else {
            webView.reload()
        }
    }

    /// 清除所有缓存和数据
    func clearAllCache(completion: @escaping (Bool) -> Void) {
        let dataStore = WKWebsiteDataStore.default()

        // 清除所有类型的数据
        let dataTypes = WKWebsiteDataStore.allWebsiteDataTypes()
        let date = Date(timeIntervalSince1970: 0)

        dataStore.removeData(ofTypes: dataTypes, modifiedSince: date) {
            DispatchQueue.main.async {
                completion(true)
            }
        }
    }

    /// 清除特定类型的缓存
    func clearCache(types: Set<String>, completion: @escaping (Bool) -> Void) {
        let dataStore = WKWebsiteDataStore.default()
        let date = Date(timeIntervalSince1970: 0)

        dataStore.removeData(ofTypes: types, modifiedSince: date) {
            DispatchQueue.main.async {
                completion(true)
            }
        }
    }

    /// 清除 Cookies
    func clearCookies(completion: @escaping (Bool) -> Void) {
        let dataStore = WKWebsiteDataStore.default()
        let cookieTypes = Set([WKWebsiteDataTypeCookies])
        let date = Date(timeIntervalSince1970: 0)

        dataStore.removeData(ofTypes: cookieTypes, modifiedSince: date) {
            DispatchQueue.main.async {
                completion(true)
            }
        }
    }

    /// 清除运行时内存缓存（不影响持久化数据）
    func clearRuntimeCache() {
        let dataStore = WKWebsiteDataStore.default()

        // 只清除内存缓存，不清除磁盘缓存和 Cookie
        let memoryTypes = Set([WKWebsiteDataTypeMemoryCache])
        let date = Date(timeIntervalSince1970: 0)

        dataStore.removeData(ofTypes: memoryTypes, modifiedSince: date) {
            print("✅ 运行时内存缓存已清除")
        }

        // 清理 URL 缓存
        URLCache.shared.removeAllCachedResponses()

        // 建议系统进行垃圾回收
        #if DEBUG
        print("💾 当前内存使用: \(self.getMemoryUsage()) MB")
        #endif
    }

    /// 获取当前内存使用情况（MB）
    /// 获取当前进程内存占用（MB）- 使用 getrusage 兼容 macOS 14+
    func getMemoryUsage() -> Double {
        var usage = rusage()
        if getrusage(RUSAGE_SELF, &usage) == 0 {
            return Double(usage.ru_maxrss) / 1024.0 / 1024.0
        }
        return 0
    }

    /// 设置自动清理定时器
    func setupAutoClearTimer() {
        // 每5分钟自动清理一次运行时缓存
        autoClearTimer?.invalidate()
        autoClearTimer = Timer.scheduledTimer(withTimeInterval: AppConstants.CacheManagement.autoCleanInterval, repeats: true) { [weak self] _ in
            self?.clearRuntimeCache()
        }
    }

    /// 开发者工具 (现在仅用于显示帮助提示)
    func toggleDevTools() {
        // 确保它已启用
        webView.configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")
        
        if #available(macOS 13.3, iOS 16.4, *) {
            webView.isInspectable = true
        }
        
        // 提示用户
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "开发者工具已启用"
            alert.informativeText = "请在网页上点击右键，选择 '检查元素' (Inspect Element) 即可使用。"
            alert.alertStyle = .informational
            alert.addButton(withTitle: "我知道了")
            alert.runModal()
        }
    }

    /// 缩放
    func zoomIn() {
        webView.pageZoom += 0.1
    }

    func zoomOut() {
        webView.pageZoom -= 0.1
    }

    func resetZoom() {
        webView.pageZoom = 1.0
    }
    
    /// 更新导航状态
    private func updateNavigationState() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.canGoBack = self.webView.canGoBack
            self.canGoForward = self.webView.canGoForward
        }
    }
    
    /// 更新当前 URL 显示
    private func updateCurrentURL() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let url = self.webView.url {
                self.currentURL = url.absoluteString
            }
        }
    }
}

// MARK: - WKScriptMessageHandler (图片查看器)
extension WebViewModel: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "imageViewer",
              let body = message.body as? [String: Any],
              let imageURL = body["url"] as? String else {
            return
        }
        
        print("🖼️ 收到图片查看请求: \(imageURL)")
        DispatchQueue.main.async {
            ImageViewerModel.shared.show(imageURL: imageURL)
        }
    }
}

// MARK: - WKNavigationDelegate
extension WebViewModel: WKNavigationDelegate {
    /// 决定是否允许导航
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }

        // 拦截 about:blank 和空链接
        if url.absoluteString == "about:blank" || url.absoluteString.isEmpty {
            decisionHandler(.cancel)
            return
        }
        
        // 检查是否是首次加载或用户主动的导航操作（后退、前进、刷新）
        let isInitialOrUserNavigation = navigationAction.navigationType == .reload || 
                                        navigationAction.navigationType == .backForward ||
                                        navigationAction.navigationType == .formSubmitted ||
                                        webView.url == nil // 首次加载
        
        // 首次加载时立即注入暗色模式（不等 didFinish），避免页面闪烁
        if isInitialOrUserNavigation && !hasInjectedDarkMode {
            DispatchQueue.main.async { [weak self] in
                self?.hasInjectedDarkMode = true
                self?.injectDarkModeCSS()
            }
        }
        
        // 对于首次加载、后退、前进、刷新、表单提交，不进行域名检查，直接允许
        if isInitialOrUserNavigation {
            decisionHandler(.allow)
            return
        }

        // 对所有其他类型的导航（包括点击链接、JavaScript 跳转等）进行域名检查
        // 获取设置中配置的域名
        let savedURLString = getSavedURL()
        guard let savedURL = URL(string: savedURLString),
              let savedHost = savedURL.host,
              let targetHost = url.host else {
            // 如果无法解析域名，默认在当前应用内打开
            decisionHandler(.allow)
            return
        }
        
        // 比较域名（不区分大小写）
        // 支持主域名匹配：例如 www.example.com 和 example.com 视为相同
        let savedHostParts = savedHost.lowercased().components(separatedBy: ".")
        let targetHostParts = targetHost.lowercased().components(separatedBy: ".")
        
        // 获取主域名（支持 .com/.org/.net 等常规域名以及 .co.uk/.com.cn 等二级域名）
        // 常见二级域名后缀列表
        let secondLevelDomains = Set(["co", "com", "ac", "org", "net", "gov", "edu", "mil", "ne", "ac"])
        let savedMainDomain: String
        let targetMainDomain: String
        
        // 尝试提取主域名：取最后一部分 + 倒数第二部分（如果倒数第二部分是二级域名）
        let savedLastPart = savedHostParts.last ?? ""
        let savedSecondLastPart = savedHostParts.dropLast().last ?? ""
        
        if secondLevelDomains.contains(savedSecondLastPart.lowercased()) && savedHostParts.count >= 3 {
            // 倒数第二部分是二级域名，主域名取倒数第3和第2部分，如 example.co.uk -> example.co.uk
            savedMainDomain = savedHostParts.dropLast(2).joined(separator: ".") + "." + savedSecondLastPart + "." + savedLastPart
        } else {
            // 常规域名，取最后两部分
            savedMainDomain = savedHostParts.suffix(2).joined(separator: ".")
        }
        
        let targetLastPart = targetHostParts.last ?? ""
        let targetSecondLastPart = targetHostParts.dropLast().last ?? ""
        
        if secondLevelDomains.contains(targetSecondLastPart.lowercased()) && targetHostParts.count >= 3 {
            targetMainDomain = targetHostParts.dropLast(2).joined(separator: ".") + "." + targetSecondLastPart + "." + targetLastPart
        } else {
            targetMainDomain = targetHostParts.suffix(2).joined(separator: ".")
        }
        
        if savedHost.lowercased() == targetHost.lowercased() || 
           savedMainDomain == targetMainDomain {
            // 域名一致或主域名一致，在当前应用内打开
            decisionHandler(.allow)
            print("✅ 域名匹配，应用内打开: \(targetHost)")
        } else {
            // 域名不一致，在系统默认浏览器中打开
            print("🌐 域名不匹配，使用系统浏览器打开: \(targetHost) (配置域名: \(savedHost))")
            NSWorkspace.shared.open(url)
            decisionHandler(.cancel)
        }
    }

    /// 决定是否允许导航响应（处理下载）
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        guard let response = navigationResponse.response as? HTTPURLResponse else {
            decisionHandler(.allow)
            return
        }

        // 检查是否是下载文件
        let contentDisposition = response.value(forHTTPHeaderField: "Content-Disposition") ?? ""

        // 只有明确标记为 attachment 时才触发下载
        if contentDisposition.contains("attachment") {
            decisionHandler(.download)
            return
        }

        decisionHandler(.allow)
    }

    /// 处理导航动作变为下载
    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        print("📥 导航动作变为下载")
        download.delegate = self
    }

    /// 处理导航响应变为下载
    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        print("📥 导航响应变为下载")
        download.delegate = self
    }

    /// 开始加载
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        DispatchQueue.main.async { [weak self] in
            self?.isLoading = true
        }
        updateCurrentURL()
    }
    
    /// 加载完成
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        DispatchQueue.main.async { [weak self] in
            self?.isLoading = false
        }
        updateNavigationState()
        updateCurrentURL()
        // 注入暗色模式 CSS（每次都调用，因为主题可能切换）
        injectDarkModeCSS()
        // 注入图片查看器增强功能（仅首次加载，防止重复注入）。
        // 注意：SPA 页面的路由变化不会触发 didFinish，刷新/后退前进会触发，
        // 但增强脚本内部已有状态管理（imageViewerActive）可跨路由复用。
        if !hasInjectedImageEnhancements {
            hasInjectedImageEnhancements = true
            injectImageViewerEnhancements()
        }
    }
    
    /// 注入暗色模式 CSS
    private func injectDarkModeCSS() {
        guard themeManager.isDarkMode else {
            removeDarkModeCSS()
            return
        }

        // 尝试从 Bundle 加载脚本
        if let script = loadScript(named: "darkmode") {
            webView.evaluateJavaScript(script) { [weak self] result, error in
                if let error = error {
                    print("⚠️ 注入暗色模式 CSS 失败: \(error.localizedDescription)")
                } else {
                    self?.hasInjectedDarkMode = true
                    print("✅ 暗色模式 CSS 已注入")
                }
            }
            return
        }

        // Bundle 加载失败时回退到硬编码 CSS
        let css = ThemeManager.getSmartDarkModeCSS()
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "$", with: "\\$")

        let script = """
        (function() {
            var oldStyle = document.getElementById('webappwrapper-dark-mode');
            if (oldStyle) { oldStyle.remove(); }
            setTimeout(function() {
                var style = document.createElement('style');
                style.id = 'webappwrapper-dark-mode';
                style.type = 'text/css';
                style.innerHTML = `\(css)`;
                document.head.appendChild(style);
            }, 0);
        })();
        """

        webView.evaluateJavaScript(script) { [weak self] result, error in
            if let error = error {
                print("⚠️ 注入暗色模式 CSS 失败: \(error.localizedDescription)")
            } else {
                self?.hasInjectedDarkMode = true
                print("✅ 暗色模式 CSS 已注入")
            }
        }
    }

    /// 移除暗色模式 CSS
    private func removeDarkModeCSS() {
        if let script = loadScript(named: "removedarkmode") {
            webView.evaluateJavaScript(script) { [weak self] result, error in
                if let error = error {
                    print("⚠️ 移除暗色模式 CSS 失败: \(error.localizedDescription)")
                }
                self?.hasInjectedDarkMode = false
            }
            return
        }

        // Bundle 加载失败时回退
        let script = """
        (function() {
            var style = document.getElementById('webappwrapper-dark-mode');
            if (style) { style.remove(); }
        })();
        """

        webView.evaluateJavaScript(script) { [weak self] result, error in
            self?.hasInjectedDarkMode = false
        }
    }
    
    /// 注入图片查看器增强功能（ESC 关闭、关闭按钮、点击背景关闭、缩放控制）
    private func injectImageViewerEnhancements() {
        // 优先从 Bundle 加载 JS 文件
        if let script = loadScript(named: "imageviewer") {
            webView.evaluateJavaScript(script) { result, error in
                if let error = error {
                    print("⚠️ 注入图片查看器增强脚本失败: \(error.localizedDescription)")
                } else {
                    print("✅ 图片查看器增强脚本已注入")
                }
            }
            return
        }

        // Bundle 加载失败时回退（保留硬编码版本作为后备）
        let fallbackScript = """
        (function() {
            var imageViewerActive = false;
            var lastKnownImageViewer = null;

            function activateImageViewer(viewer) {
                if (viewer === lastKnownImageViewer) return;
                lastKnownImageViewer = viewer;
                imageViewerActive = true;
                document.body.classList.add('webapp-iv-active');
                console.log('Image viewer activated');
            }

            function deactivateImageViewer() {
                imageViewerActive = false;
                lastKnownImageViewer = null;
                document.body.classList.remove('webapp-iv-active');
                document.body.classList.remove('webapp-iv-zoomed');
            }

            function findImageViewer() {
                var selectors = ['[class*="lightbox"]', '[class*="viewer"]', '.pswp', '.mfp-bg', '.fancybox-overlay'];
                for (var i = 0; i < selectors.length; i++) {
                    var el = document.querySelector(selectors[i]);
                    if (el && window.getComputedStyle(el).display !== 'none') return el;
                }
                return null;
            }

            function findFullscreenImage() {
                var imgs = document.querySelectorAll('img');
                for (var i = 0; i < imgs.length; i++) {
                    var style = window.getComputedStyle(imgs[i]);
                    if (style.position === 'fixed' && parseInt(style.zIndex, 10) > 100) return imgs[i];
                }
                return null;
            }

            function checkAndActivate() {
                var viewer = findImageViewer() || findFullscreenImage();
                if (viewer) activateImageViewer(viewer);
                else deactivateImageViewer();
            }

            document.addEventListener('keydown', function(e) {
                if ((e.key === 'Escape' || e.keyCode === 27) && imageViewerActive) {
                    var allEls = document.querySelectorAll('*');
                    for (var i = 0; i < allEls.length; i++) {
                        var style = window.getComputedStyle(allEls[i]);
                        if (style.position === 'fixed' && parseInt(style.zIndex, 10) > 100 && (allEls[i].querySelector('img') || allEls[i].tagName === 'IMG')) {
                            allEls[i].remove();
                            document.body.style.overflow = '';
                            document.documentElement.style.overflow = '';
                            deactivateImageViewer();
                            e.preventDefault();
                            e.stopPropagation();
                            return;
                        }
                    }
                }
                if (imageViewerActive && (e.metaKey || e.ctrlKey) && (e.key === '+' || e.key === '-' || e.key === '=' || e.key === '0')) {
                    e.preventDefault();
                    e.stopPropagation();
                    var viewer = findImageViewer() || findFullscreenImage();
                    var img = viewer ? (viewer.querySelector('img') || (viewer.tagName === 'IMG' ? viewer : null)) : null;
                    if (img) {
                        var delta = (e.key === '+' || e.key === '=') ? 0.25 : (e.key === '0' ? 0 : -0.25);
                        var currentTransform = window.getComputedStyle(img).transform;
                        var currentScale = 1;
                        if (currentTransform !== 'none') currentScale = new DOMMatrix(currentTransform).a;
                        var newScale = e.key === '0' ? 1 : Math.min(Math.max(currentScale + delta, 0.25), 5);
                        img.style.transform = 'scale(' + newScale + ')';
                        img.style.transition = 'transform 0.2s ease';
                    }
                }
            }, true);

            document.addEventListener('wheel', function(e) {
                if (!imageViewerActive || (!e.ctrlKey && !e.metaKey)) return;
                e.preventDefault();
                e.stopPropagation();
                var viewer = findImageViewer() || findFullscreenImage();
                var img = viewer ? (viewer.querySelector('img') || (viewer.tagName === 'IMG' ? viewer : null)) : null;
                if (img) {
                    var currentTransform = window.getComputedStyle(img).transform;
                    var currentScale = 1;
                    if (currentTransform !== 'none') currentScale = new DOMMatrix(currentTransform).a;
                    var newScale = Math.min(Math.max(currentScale + (e.deltaY < 0 ? 0.15 : -0.15), 0.25), 5);
                    img.style.transform = 'scale(' + newScale + ')';
                    img.style.transition = 'transform 0.15s ease';
                }
            }, { passive: false });

            var observer = new MutationObserver(function() {
                setTimeout(checkAndActivate, 150);
            });
            if (document.body) {
                observer.observe(document.body, { childList: true, subtree: true, attributes: true, attributeFilter: ['style', 'class'] });
                setTimeout(checkAndActivate, 300);
            } else {
                document.addEventListener('DOMContentLoaded', function() {
                    observer.observe(document.body, { childList: true, subtree: true, attributes: true, attributeFilter: ['style', 'class'] });
                    setTimeout(checkAndActivate, 300);
                });
            }
            console.log('Image viewer fallback mode loaded');
        })();
        """

        webView.evaluateJavaScript(fallbackScript) { result, error in
            if let error = error {
                print("⚠️ 注入图片查看器增强脚本失败: \(error.localizedDescription)")
            } else {
                print("✅ 图片查看器增强脚本已注入")
            }
        }
    }
    
    /// 加载失败
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("❌ 页面加载失败: \(error.localizedDescription)")
        DispatchQueue.main.async { [weak self] in
            self?.isLoading = false
            self?.showLoadError("页面加载失败")
        }
        updateNavigationState()
    }

    /// 临时加载失败
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        let nsError = error as NSError
        // 忽略取消错误（错误代码 102 - 通常是因为触发了下载）
        if nsError.domain == "WebKitErrorDomain" && nsError.code == 102 {
            print("ℹ️ 页面加载被取消（可能是下载）")
            return
        }
        print("❌ 临时加载失败: \(error.localizedDescription)")
        DispatchQueue.main.async { [weak self] in
            self?.isLoading = false
            // 根据错误类型给出友好提示
            let message = self?.friendlyErrorMessage(for: nsError) ?? "网络连接失败"
            self?.showLoadError(message)
        }
    }

    /// 显示加载错误 toast
    private func showLoadError(_ message: String) {
        loadError = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            if self?.loadError == message {
                self?.loadError = nil
            }
        }
    }

    /// 将错误码转为友好提示
    private func friendlyErrorMessage(for error: NSError) -> String {
        if error.domain == NSURLErrorDomain {
            switch error.code {
            case NSURLErrorNotConnectedToInternet:
                return "网络连接已断开，请检查网络设置"
            case NSURLErrorTimedOut:
                return "请求超时，请稍后重试"
            case NSURLErrorCannotFindHost, NSURLErrorDNSLookupFailed:
                return "无法找到服务器，请检查网址是否正确"
            case NSURLErrorNetworkConnectionLost:
                return "网络连接已断开"
            case NSURLErrorCannotConnectToHost:
                return "无法连接到服务器"
            case NSURLErrorSecureConnectionFailed, NSURLErrorServerCertificateHasBadDate,
                 NSURLErrorServerCertificateUntrusted, NSURLErrorServerCertificateHasUnknownRoot,
                 NSURLErrorServerCertificateNotYetValid:
                return "安全连接失败，可能是证书问题"
            default:
                return "网络连接失败（错误码: \(error.code)）"
            }
        }
        return "加载失败: \(error.localizedDescription)"
    }

    /// 接收服务器重定向
    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        updateCurrentURL()
    }
}

// MARK: - Custom WebView
/// 自定义 WebView 以支持扩展右键菜单
class CustomWebView: WKWebView {
    override func willOpenMenu(_ menu: NSMenu, with event: NSEvent) {
        // 添加分割线
        menu.addItem(NSMenuItem.separator())
        
        // 1. 强制刷新
        let refreshTitle = "强制刷新 (清除缓存)"
        let refreshItem = NSMenuItem(title: refreshTitle, action: #selector(forceRefreshAction), keyEquivalent: "r")
        refreshItem.keyEquivalentModifierMask = [.command, .shift]
        refreshItem.target = self
        menu.addItem(refreshItem)
        
        // 2. 开发者工具 - 此处已移除自定义菜单项
        // 因为我们默认启用了 developerExtrasEnabled / isInspectable
        // 系统会自动在右键菜单中添加 "Inspect Element" (检查元素)
        
        // 调用父类方法
        super.willOpenMenu(menu, with: event)
    }
    
    /// 强制刷新动作
    @objc private func forceRefreshAction() {
        print("🔄 执行强制刷新...")
        // 1. 清除运行时缓存
        WebViewModel.shared.clearRuntimeCache()
        
        // 2. 尝试从源重新加载 (相当于 Shift-Reload)
        self.reloadFromOrigin()
        
        // 如果需要更彻底的清理，可以调用 clearAllCache，但可能会清除登录状态
        // WebViewModel.shared.clearAllCache { _ in self.reload() }
    }
}


// MARK: - WKUIDelegate
extension WebViewModel: WKUIDelegate {
    /// 处理新窗口打开请求
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        guard let url = navigationAction.request.url else {
            return nil
        }

        // 拦截 about:blank
        if url.absoluteString == "about:blank" || url.absoluteString.isEmpty {
            return nil
        }

        // 在当前窗口打开
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
        }

        return nil
    }

    /// 请求通知权限
    func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType, decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        decisionHandler(.grant)
    }

    /// 处理 JavaScript 警告框
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alert = NSAlert()
        alert.messageText = "网站提示"
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "确定")
        alert.runModal()
        completionHandler()
    }

    /// 处理 JavaScript 确认框
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alert = NSAlert()
        alert.messageText = "网站确认"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "确定")
        alert.addButton(withTitle: "取消")
        let response = alert.runModal()
        completionHandler(response == .alertFirstButtonReturn)
    }

    /// 处理 JavaScript 输入框
    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
        let alert = NSAlert()
        alert.messageText = "网站输入"
        alert.informativeText = prompt
        alert.addButton(withTitle: "确定")
        alert.addButton(withTitle: "取消")

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        textField.stringValue = defaultText ?? ""
        alert.accessoryView = textField

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            completionHandler(textField.stringValue)
        } else {
            completionHandler(nil)
        }
    }
}

// MARK: - WKDownloadDelegate
extension WebViewModel: WKDownloadDelegate {
    /// 下载开始
    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
        print("📥 开始下载: \(suggestedFilename)")

        // 使用下载目录（用户可找到的文件位置）
        let downloadsDir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        let destinationURL = downloadsDir.appendingPathComponent(suggestedFilename)

        // 如果文件已存在，添加数字后缀
        var finalURL = destinationURL
        var counter = 1
        while FileManager.default.fileExists(atPath: finalURL.path) {
            let nameWithoutExt = (suggestedFilename as NSString).deletingPathExtension
            let ext = (suggestedFilename as NSString).pathExtension
            let newName = "\(nameWithoutExt) (\(counter)).\(ext)"
            finalURL = downloadsDir.appendingPathComponent(newName)
            counter += 1
        }

        print("📁 下载目标: \(finalURL.path)")

        // 确保目标目录存在
        let parentDir = finalURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: parentDir.path) {
            do {
                try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
                print("✅ 创建目录: \(parentDir.path)")
            } catch {
                print("❌ 创建目录失败: \(error.localizedDescription)")
            }
        }

        // 通知下载管理器并保存目标 URL
        DownloadManager.shared.startDownload(download, suggestedFilename: finalURL.lastPathComponent, destinationURL: finalURL)

        completionHandler(finalURL)
    }

    /// 下载进度更新
    func download(_ download: WKDownload, didReceiveData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        DownloadManager.shared.updateProgress(for: download, bytesWritten: bytesWritten, totalBytesWritten: totalBytesWritten, totalBytesExpectedToWrite: totalBytesExpectedToWrite)
    }

    /// 下载完成
    func downloadDidFinish(_ download: WKDownload) {
        print("✅ 下载完成回调")
        print("📊 下载管理器中的下载数量: \(DownloadManager.shared.downloads.count)")

        // 查找下载项
        if let item = DownloadManager.shared.downloads.first(where: { $0.download === download }) {
            print("✅ 找到下载项: \(item.fileName)")

            if let destinationURL = item.destinationURL {
                print("📁 检查文件: \(destinationURL.path)")
                let fileExists = FileManager.default.fileExists(atPath: destinationURL.path)
                print("📊 文件存在: \(fileExists)")

                if fileExists {
                    do {
                        let attributes = try FileManager.default.attributesOfItem(atPath: destinationURL.path)
                        let fileSize = attributes[.size] as? Int64 ?? 0
                        print("📦 文件大小: \(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file))")
                    } catch {
                        print("❌ 获取文件属性失败: \(error.localizedDescription)")
                    }
                }

                DownloadManager.shared.downloadCompleted(for: download, destinationURL: destinationURL)
            } else {
                print("❌ 下载项的 destinationURL 为 nil")
            }
        } else {
            print("❌ 未找到下载项")
            print("   当前下载列表:")
            for (index, item) in DownloadManager.shared.downloads.enumerated() {
                print("   [\(index)] \(item.fileName) - download: \(item.download != nil)")
            }
        }
    }

    /// 下载失败
    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        DownloadManager.shared.downloadFailed(for: download, error: error)
    }
}

