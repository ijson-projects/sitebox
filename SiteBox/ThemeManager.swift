//
//  ThemeManager.swift
//  SiteBox
//
//  Created on 28/12/2025.
//

import SwiftUI
import AppKit
import Combine

/// 主题管理器 - 管理应用和网站的暗色模式
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    /// 主题模式
    enum AppColorScheme: String, CaseIterable {
        case auto = "auto"
        case light = "light"
        case dark = "dark"
        
        var displayName: String {
            switch self {
            case .auto: return "跟随系统"
            case .light: return "浅色模式"
            case .dark: return "暗色模式"
            }
        }
    }
    
    @Published var colorScheme: AppColorScheme {
        didSet {
            UserDefaults.standard.set(colorScheme.rawValue, forKey: AppConstants.UserDefaultsKeys.colorScheme)
            updateEffectiveColorScheme()
        }
    }
    
    @Published var effectiveColorScheme: AppColorScheme = .light
    
    private let defaults = UserDefaults.standard
    private var systemObserver: NSObjectProtocol?
    
    private init() {
        // 从 UserDefaults 读取保存的主题设置
        let savedScheme = defaults.string(forKey: AppConstants.UserDefaultsKeys.colorScheme) ?? "auto"
        self.colorScheme = AppColorScheme(rawValue: savedScheme) ?? .auto
        
        // 监听系统主题变化
        observeSystemTheme()
        updateEffectiveColorScheme()
    }
    
    /// 监听系统主题变化
    private func observeSystemTheme() {
        systemObserver = DistributedNotificationCenter.default.addObserver(
            forName: Notification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateEffectiveColorScheme()
        }
    }
    
    /// 更新有效主题（考虑系统主题）
    func updateEffectiveColorScheme() {
        let previousScheme = effectiveColorScheme
        
        if colorScheme == .auto {
            // 跟随系统主题
            let isDark = NSApp.effectiveAppearance.name == .darkAqua
            effectiveColorScheme = isDark ? .dark : .light
        } else {
            effectiveColorScheme = colorScheme
        }
        
        // 如果主题发生变化，通知 WebView 更新
        if previousScheme != effectiveColorScheme {
            updateWebViewTheme()
        }
    }
    
    /// 更新 WebView 主题（注入 CSS）
    private func updateWebViewTheme() {
        NotificationCenter.default.post(
            name: NSNotification.Name("WebViewThemeChanged"),
            object: effectiveColorScheme
        )
    }
    
    /// 获取当前是否暗色模式
    var isDarkMode: Bool {
        return effectiveColorScheme == .dark
    }
    
    /// 获取暗色模式 CSS（用于注入到网页）
    static func getDarkModeCSS() -> String {
        return """
        /* 暗色模式 CSS 注入 */
        @media (prefers-color-scheme: dark) {
            /* 如果网站已经支持暗色模式，这个会生效 */
        }
        
        /* 强制暗色模式（如果网站不支持） */
        html {
            filter: invert(0) hue-rotate(0deg);
        }
        
        /* 图片和视频不反转 */
        img, video, iframe, embed, object, svg, canvas {
            filter: invert(1) hue-rotate(180deg);
        }
        
        /* 某些元素保持原样 */
        [style*="background-image"], [style*="backgroundImage"] {
            filter: invert(1) hue-rotate(180deg);
        }
        """
    }
    
    /// 获取智能暗色模式 CSS（更温和的方式）
    static func getSmartDarkModeCSS() -> String {
        return """
        /* 智能暗色模式 - 只调整背景和文字颜色，不反转图片 */
        html {
            background-color: #1e1e1e !important;
            color: #e0e0e0 !important;
        }
        
        body {
            background-color: #1e1e1e !important;
            color: #e0e0e0 !important;
        }
        
        /* 调整常见元素的颜色 */
        div, section, article, main, header, footer, nav, aside {
            background-color: #1e1e1e !important;
            color: #e0e0e0 !important;
        }
        
        /* 输入框 */
        input, textarea, select {
            background-color: #2d2d2d !important;
            color: #e0e0e0 !important;
            border-color: #404040 !important;
        }
        
        /* 链接 */
        a {
            color: #4a9eff !important;
        }
        
        a:visited {
            color: #b19cd9 !important;
        }
        
        /* 按钮 */
        button, [role="button"] {
            background-color: #2d2d2d !important;
            color: #e0e0e0 !important;
            border-color: #404040 !important;
        }
        
        /* 卡片和面板 */
        .card, .panel, [class*="card"], [class*="panel"] {
            background-color: #252525 !important;
            color: #e0e0e0 !important;
        }
        
        /* 代码块 */
        code, pre {
            background-color: #2d2d2d !important;
            color: #e0e0e0 !important;
        }
        """
    }
}

