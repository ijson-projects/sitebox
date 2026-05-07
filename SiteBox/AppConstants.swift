//
//  AppConstants.swift
//  SiteBox
//
//  Created on 27/12/2025.
//

import Foundation

/// 应用常量 - 统一管理配置键和默认值
enum AppConstants {
    
    // MARK: - UserDefaults Keys
    enum UserDefaultsKeys {
        static let webAppURL = "webAppURL"
        static let appName = "appName"
        static let windowWidth = "windowWidth"
        static let windowHeight = "windowHeight"
        static let colorScheme = "colorScheme" // "auto", "light", "dark"
        static let showToolbar = "showToolbar" // 是否显示顶部工具栏
    }
    
    // MARK: - Default Values
    enum DefaultValues {
        static let webAppURL = "https://www.apple.com"
        static let appName = "Web App"
        static let windowWidth = 1200.0
        static let windowHeight = 800.0
        static let minWindowWidth = 400.0
        static let maxWindowWidth = 5000.0
        static let minWindowHeight = 300.0
        static let maxWindowHeight = 5000.0
        static let showToolbar = true // 默认显示工具栏
    }
    
    // MARK: - Notification Names
    enum Notifications {
        static let toggleDevTools = "ToggleDevTools"
        static let showSettings = "ShowSettings"
        static let showDownloads = "ShowDownloads"
    }
    
    // MARK: - Network
    enum Network {
        static let requestTimeout: TimeInterval = 10.0
    }

    // MARK: - Cache Management
    enum CacheManagement {
        /// 自动清理内存缓存的时间间隔（秒）
        static let autoCleanInterval: TimeInterval = 300 // 5分钟

        /// 内存警告时是否自动清理缓存
        static let clearOnMemoryWarning = true

        /// 应用进入后台时是否清理内存缓存
        static let clearOnBackground = true

        /// 内存缓存最大保留时间（秒）
        static let maxMemoryCacheAge: TimeInterval = 600 // 10分钟
    }
}

