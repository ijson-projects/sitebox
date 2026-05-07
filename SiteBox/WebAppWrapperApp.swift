//
//  SiteBoxApp.swift
//  SiteBox
//
//  Created by 崔永旭 on 22/12/2025.
//

import SwiftUI
import AppKit

@main
struct SiteBoxApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage("appName") private var appName = "Web App"
    @AppStorage("windowWidth") private var windowWidth = 1200.0
    @AppStorage("windowHeight") private var windowHeight = 800.0
    @StateObject private var themeManager = ThemeManager.shared

    var body: some Scene {
        Window(appName, id: "main") {
            ContentView()
                .preferredColorScheme(themeManager.effectiveColorScheme == .dark ? .dark : .light)
        }
        .defaultSize(width: windowWidth, height: windowHeight)
        .commands {
            // 移除默认的 File 菜单
            CommandGroup(replacing: .newItem) { }
            
            // 移除编辑菜单中的默认项（撤销、自动填充、听写等）
            // 注意：保留复制粘贴功能，不替换 .pasteboard
            CommandGroup(replacing: .undoRedo) { }
            
            // 移除 Format 菜单（文本格式化相关）
            CommandGroup(replacing: .textFormatting) { }
            CommandGroup(after: .textFormatting) { }
            
            // 完全替换编辑菜单 - 移除所有默认项，只保留我们需要的
            CommandGroup(replacing: .textEditing) {
                Button("后退") {
                    WebViewModel.shared.goBack()
                }
                .keyboardShortcut("[", modifiers: .command)

                Button("前进") {
                    WebViewModel.shared.goForward()
                }
                .keyboardShortcut("]", modifiers: .command)

                Button("刷新") {
                    WebViewModel.shared.reload()
                }
                .keyboardShortcut("r", modifiers: .command)

                Divider()

                Button("放大") {
                    WebViewModel.shared.zoomIn()
                }
                .keyboardShortcut("+", modifiers: .command)

                Button("缩小") {
                    WebViewModel.shared.zoomOut()
                }
                .keyboardShortcut("-", modifiers: .command)

                Button("实际大小") {
                    WebViewModel.shared.resetZoom()
                }
                .keyboardShortcut("0", modifiers: .command)

                Divider()

                Button("设置...") {
                    NotificationCenter.default.post(name: NSNotification.Name(AppConstants.Notifications.showSettings), object: nil)
                }
                .keyboardShortcut(",", modifiers: .command)
                
                Divider()
                
                Button("开发者工具") {
                    NotificationCenter.default.post(name: NSNotification.Name(AppConstants.Notifications.toggleDevTools), object: nil)
                }
                .keyboardShortcut("i", modifiers: [.command, .option])

                Button("下载管理") {
                    NotificationCenter.default.post(name: NSNotification.Name(AppConstants.Notifications.showDownloads), object: nil)
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])
            }
            
            // 移除 View 菜单
            CommandGroup(replacing: .sidebar) { }
            CommandGroup(replacing: .toolbar) { }
            
            // 窗口菜单 - 移除不需要的项
            CommandGroup(replacing: .windowSize) { }
            CommandGroup(replacing: .windowArrangement) { }
            
            // Help 菜单 - 添加关于选项（如果系统支持）
            // 注意：Help 菜单项通常由系统管理，无法直接替换
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow?
    var statusItem: NSStatusItem?
    private var formatMenuRemovalTimer: Timer?
    private var memoryPressureSource: DispatchSourceMemoryPressure?
    private var notificationObservers: [NSObjectProtocol] = []
    // 防抖：记录上次清理时间，5 秒内不重复清理
    private var lastMemoryClearTime: Date?
    // 窗口 resize 监听
    private var windowResizeObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 延迟获取主窗口，确保 SwiftUI Scene 已完成窗口创建
        DispatchQueue.main.async { [weak self] in
            self?.window = NSApplication.shared.windows.first
            self?.window?.setFrameAutosaveName("MainWindow")
            self?.setupWindowResizeObserver()
        }
        
        // 初始化主题管理器并更新主题
        ThemeManager.shared.updateEffectiveColorScheme()
        
        // 移除 Format 菜单（立即执行）
        removeFormatMenu()
        
        // 监听菜单变化，持续移除 Format 菜单
        setupFormatMenuRemoval()

        // 创建菜单栏图标
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            // 使用自定义图标
            if let icon = NSImage(named: "StatusBarIcon") {
                icon.isTemplate = true  // 自动适配深色/浅色模式
                button.image = icon
            } else {
                // 如果没有自定义图标，使用系统图标
                button.image = NSImage(systemSymbolName: "globe", accessibilityDescription: "Web App")
            }
            button.action = #selector(toggleWindow)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        // 创建右键菜单
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "显示/隐藏", action: #selector(toggleWindow), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "下载管理", action: #selector(showDownloads), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "设置...", action: #selector(showSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "清除缓存", action: #selector(clearCache), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "清理内存", action: #selector(clearRuntimeMemory), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem?.menu = menu

        // 设置为常规应用（在 Finder 和 Dock 中显示）
        // 如果只想在 Finder 中显示而不在 Dock 显示，可以使用 .accessory
        // 但 .accessory 策略下 Finder 不会显示运行状态
        NSApp.setActivationPolicy(.regular)

        // 设置运行时缓存自动清理
        setupRuntimeCacheManagement()
    }

    @objc func toggleWindow() {
        if window?.isVisible == true {
            window?.orderOut(nil)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            window?.makeKeyAndOrderFront(nil)
        }
    }

    @objc func showSettings() {
        NotificationCenter.default.post(name: NSNotification.Name(AppConstants.Notifications.showSettings), object: nil)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    @objc func showDownloads() {
        NotificationCenter.default.post(name: NSNotification.Name(AppConstants.Notifications.showDownloads), object: nil)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    @objc func clearCache() {
        let alert = NSAlert()
        alert.messageText = "清除缓存"
        alert.informativeText = "确定要清除所有缓存和浏览数据吗？\n清除后需要重新登录网站。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "清除")
        alert.addButton(withTitle: "取消")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            WebViewModel.shared.clearAllCache { success in
                DispatchQueue.main.async {
                    let resultAlert = NSAlert()
                    if success {
                        resultAlert.messageText = "清除成功"
                        resultAlert.informativeText = "缓存已清除，下次访问网站时需要重新登录。"
                        resultAlert.alertStyle = .informational
                    } else {
                        resultAlert.messageText = "清除失败"
                        resultAlert.informativeText = "清除缓存失败，请重试。"
                        resultAlert.alertStyle = .critical
                    }
                    resultAlert.runModal()
                }
            }
        }
    }

    @objc func clearRuntimeMemory() {
        let memoryBefore = WebViewModel.shared.getMemoryUsage()
        WebViewModel.shared.clearRuntimeCache()

        // 延迟一下再获取内存，让系统有时间回收
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let memoryAfter = WebViewModel.shared.getMemoryUsage()
            let saved = memoryBefore - memoryAfter

            let alert = NSAlert()
            alert.messageText = "内存已清理"
            alert.informativeText = String(format: "清理前: %.1f MB\n清理后: %.1f MB\n释放: %.1f MB",
                                          memoryBefore, memoryAfter, saved)
            alert.alertStyle = .informational
            alert.runModal()
        }
    }

    /// 设置运行时缓存管理
    func setupRuntimeCacheManagement() {
        // 启动自动清理定时器
        if AppConstants.CacheManagement.autoCleanInterval > 0 {
            WebViewModel.shared.setupAutoClearTimer()
            print("✅ 已启动自动清理定时器，间隔: \(AppConstants.CacheManagement.autoCleanInterval)秒")
        }

        // 监听应用进入后台通知
        if AppConstants.CacheManagement.clearOnBackground {
            let observer = NotificationCenter.default.addObserver(
                forName: NSApplication.didResignActiveNotification,
                object: nil,
                queue: .main
            ) { _ in
                print("📱 应用进入后台，清理运行时缓存")
                WebViewModel.shared.clearRuntimeCache()
            }
            notificationObservers.append(observer)
        }

        // 监听内存警告（macOS 使用内存压力通知）
        if AppConstants.CacheManagement.clearOnMemoryWarning {
            // 注册内存压力监听
            let source = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical], queue: .main)
            source.setEventHandler { [weak self, source] in
                guard let self = self else { return }

                // 防抖：5 秒内不重复清理
                let now = Date()
                if let last = self.lastMemoryClearTime, now.timeIntervalSince(last) < 5.0 {
                    print("ℹ️ 内存压力事件过于频繁，跳过本次清理（防抖）")
                    return
                }
                self.lastMemoryClearTime = now

                let event = source.data
                if event.contains(.warning) {
                    print("⚠️ 内存警告，清理运行时缓存")
                    WebViewModel.shared.clearRuntimeCache()
                } else if event.contains(.critical) {
                    print("🚨 内存严重不足，强制清理缓存")
                    WebViewModel.shared.clearRuntimeCache()
                }
            }
            source.resume()
            memoryPressureSource = source
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        window?.makeKeyAndOrderFront(nil)
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        formatMenuRemovalTimer?.invalidate()
        formatMenuRemovalTimer = nil
        memoryPressureSource?.cancel()
        memoryPressureSource = nil
        for observer in notificationObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        notificationObservers.removeAll()
        WebViewModel.shared.removeNotificationObserver()
    }
    
    /// 移除 Format 菜单
    private func removeFormatMenu() {
        if let mainMenu = NSApp.mainMenu {
            // 查找 Format 菜单
            if let formatMenuIndex = mainMenu.items.firstIndex(where: { $0.title == "Format" }) {
                mainMenu.removeItem(at: formatMenuIndex)
                print("✅ 已移除 Format 菜单")
            }
        }
    }
    
    /// 设置 Format 菜单的持续移除机制
    private func setupFormatMenuRemoval() {
        // 监听窗口状态变化
        let enterFSObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didEnterFullScreenNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.removeFormatMenu()
        }
        notificationObservers.append(enterFSObserver)

        let exitFSObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didExitFullScreenNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.removeFormatMenu()
        }
        notificationObservers.append(exitFSObserver)

        // 监听应用激活
        let activeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.removeFormatMenu()
        }
        notificationObservers.append(activeObserver)

        // 定期检查并移除（每2秒检查一次）
        formatMenuRemovalTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.removeFormatMenu()
        }
    }

    /// 监听窗口尺寸变化并通知网页刷新视口
    private func setupWindowResizeObserver() {
        guard let window = window else { return }

        // 清理旧的监听
        if let observer = windowResizeObserver {
            NotificationCenter.default.removeObserver(observer)
        }

        windowResizeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResizeNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            guard let self = self, let window = self.window else { return }
            let size = window.frame.size
            WebViewModel.shared.notifyViewportChanged(width: size.width, height: size.height)
        }
    }
}
