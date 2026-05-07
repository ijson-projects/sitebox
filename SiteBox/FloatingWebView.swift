//
//  FloatingWebView.swift
//  SiteBox
//
//  浮动子窗口 — 处理 window.open() / target=_blank 请求
//  与主窗口共享 Cookie/Session，保持登录态
//

import SwiftUI
import WebKit

/// 浮动 WebView 子窗口管理器
class FloatingWebViewManager: NSObject, WKNavigationDelegate {
    static let shared = FloatingWebViewManager()
    
    private var childWindows: [NSWindow] = []
    
    /// 创建浮动子窗口加载 URL（与主 WebView 共享 Cookie/Session）
    func open(url: URL, from parentWebView: WKWebView?) {
        let windowWidth: CGFloat = 800
        let windowHeight: CGFloat = 600
        
        // 子窗口居中于屏幕
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - windowWidth / 2
        let y = screenFrame.midY - windowHeight / 2
        
        let window = NSWindow(
            contentRect: NSRect(x: x, y: y, width: windowWidth, height: windowHeight),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = url.host ?? "SiteBox"
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 400, height: 300)
        
        // 创建 WKWebView 配置，共享主窗口的数据存储（保持登录态）
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()  // 与主 WebView 共享 Cookie/Session
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")
        
        let childWebView = WKWebView(frame: .zero, configuration: config)
        if #available(macOS 13.3, *) {
            childWebView.isInspectable = true
        }
        childWebView.navigationDelegate = self
        
        // 包装到 SwiftUI
        let floatingView = FloatingWebContentView(webView: childWebView, url: url, closeAction: { [weak window] in
            window?.close()
        })
        
        window.contentView = NSHostingView(rootView: floatingView)
        window.makeKeyAndOrderFront(nil)
        
        childWindows.append(window)
        
        // 子窗口关闭时清理引用
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self, weak window] _ in
            if let w = window {
                self?.childWindows.removeAll { $0 === w }
            }
            NotificationCenter.default.removeObserver(self, name: NSWindow.willCloseNotification, object: window)
        }
    }
}

// MARK: - SwiftUI Floating WebView Content

/// 浮动 WebView 的内容视图
struct FloatingWebContentView: View {
    let webView: WKWebView
    let url: URL
    let closeAction: () -> Void
    
    @State private var title: String = ""
    @State private var isLoading: Bool = true
    @State private var canGoBack: Bool = false
    @State private var canGoForward: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 导航栏
            HStack(spacing: 8) {
                Button(action: { webView.goBack() }) {
                    Image(systemName: "chevron.left")
                }
                .disabled(!canGoBack)
                
                Button(action: { webView.goForward() }) {
                    Image(systemName: "chevron.right")
                }
                .disabled(!canGoForward)
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 16, height: 16)
                }
                
                Text(title)
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                Spacer()
                
                Button(action: {
                    if let currentURL = webView.url {
                        NSWorkspace.shared.open(currentURL)
                    }
                }) {
                    Image(systemName: "safari")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("在默认浏览器中打开")
                
                Button(action: closeAction) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("关闭窗口")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // WebView
            FloatingWebViewRepresentable(webView: webView)
        }
        .onAppear {
            webView.load(URLRequest(url: url))
            startObserving()
        }
    }
    
    private func startObserving() {
        // 监听标题
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            guard webView.window != nil else {
                timer.invalidate()
                return
            }
            webView.evaluateJavaScript("document.title") { result, _ in
                if let t = result as? String, !t.isEmpty {
                    DispatchQueue.main.async { self.title = t }
                }
            }
        }
        
        // 监听加载状态和导航状态
        Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { timer in
            guard webView.window != nil else {
                timer.invalidate()
                return
            }
            DispatchQueue.main.async {
                self.isLoading = webView.isLoading
                self.canGoBack = webView.canGoBack
                self.canGoForward = webView.canGoForward
            }
        }
    }
}

/// NSViewRepresentable 包装 WKWebView
struct FloatingWebViewRepresentable: NSViewRepresentable {
    let webView: WKWebView
    
    func makeNSView(context: Context) -> WKWebView {
        return webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {}
}
