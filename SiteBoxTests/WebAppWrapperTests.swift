//
//  SiteBoxTests.swift
//  SiteBoxTests
//
//  Created by 崔永旭 on 22/12/2025.
//

import Testing
@testable import SiteBox

struct SiteBoxTests {

    // MARK: - DownloadItem Tests

    @Test func downloadItemInitialState() {
        let item = DownloadItem(fileName: "test.pdf")
        #expect(item.fileName == "test.pdf")
        #expect(item.progress == 0.0)
        #expect(item.totalSize == 0)
        #expect(item.downloadedSize == 0)
        #expect(item.state == .downloading)
        #expect(item.error == nil)
    }

    @Test func downloadItemProgressText() {
        let item = DownloadItem(fileName: "large.zip")
        item.downloadedSize = 5_242_880   // 5 MB
        item.totalSize = 10_485_760        // 10 MB

        let text = item.progressText
        #expect(text.contains("/"))
    }

    @Test func downloadItemStateText() {
        let item = DownloadItem(fileName: "doc.pdf")

        item.state = .downloading
        #expect(item.stateText == "下载中")

        item.state = .completed
        #expect(item.stateText == "已完成")

        item.state = .failed
        #expect(item.stateText == "失败")

        item.state = .cancelled
        #expect(item.stateText == "已取消")

        item.state = .paused
        #expect(item.stateText == "已暂停")
    }

    // MARK: - AppConstants Tests

    @Test func appConstantsDefaultValues() {
        // URL 默认值
        #expect(AppConstants.DefaultValues.webAppURL == "https://www.apple.com")
        #expect(AppConstants.DefaultValues.appName == "Web App")
        #expect(AppConstants.DefaultValues.windowWidth == 1200.0)
        #expect(AppConstants.DefaultValues.windowHeight == 800.0)
    }

    @Test func appConstantsWindowSizeBounds() {
        #expect(AppConstants.DefaultValues.minWindowWidth == 400.0)
        #expect(AppConstants.DefaultValues.maxWindowWidth == 5000.0)
        #expect(AppConstants.DefaultValues.minWindowHeight == 300.0)
        #expect(AppConstants.DefaultValues.maxWindowHeight == 5000.0)
    }

    @Test func appConstantsNotificationNames() {
        #expect(AppConstants.Notifications.toggleDevTools == "ToggleDevTools")
        #expect(AppConstants.Notifications.showSettings == "ShowSettings")
        #expect(AppConstants.Notifications.showDownloads == "ShowDownloads")
    }

    @Test func appConstantsCacheManagementDefaults() {
        #expect(AppConstants.CacheManagement.autoCleanInterval == 300)  // 5分钟
        #expect(AppConstants.CacheManagement.clearOnMemoryWarning == true)
        #expect(AppConstants.CacheManagement.clearOnBackground == true)
        #expect(AppConstants.CacheManagement.maxMemoryCacheAge == 600)  // 10分钟
    }

    // MARK: - ThemeManager Tests

    @Test func themeManagerColorSchemeDisplayNames() {
        #expect(ThemeManager.AppColorScheme.auto.displayName == "跟随系统")
        #expect(ThemeManager.AppColorScheme.light.displayName == "浅色模式")
        #expect(ThemeManager.AppColorScheme.dark.displayName == "暗色模式")
    }

    @Test func themeManagerSingleton() {
        let tm1 = ThemeManager.shared
        let tm2 = ThemeManager.shared
        #expect(tm1 === tm2)  // 同一实例
    }

    @Test func themeManagerIsDarkMode() {
        let tm = ThemeManager.shared
        let original = tm.colorScheme

        tm.colorScheme = .dark
        #expect(tm.isDarkMode == true)

        tm.colorScheme = .light
        #expect(tm.isDarkMode == false)

        // 恢复原值
        tm.colorScheme = original
    }

    // MARK: - UserDefaultsKeys Tests

    @Test func userDefaultsKeysAreValidStrings() {
        #expect(!AppConstants.UserDefaultsKeys.webAppURL.isEmpty)
        #expect(!AppConstants.UserDefaultsKeys.appName.isEmpty)
        #expect(!AppConstants.UserDefaultsKeys.colorScheme.isEmpty)
        #expect(!AppConstants.UserDefaultsKeys.showToolbar.isEmpty)
    }
}
