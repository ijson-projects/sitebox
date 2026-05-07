//
//  SettingsView.swift
//  SiteBox
//
//  Created by 崔永旭 on 25/12/2025.
//

import SwiftUI
import UniformTypeIdentifiers
import AppKit

/// 设置界面
struct SettingsView: View {
    @AppStorage("webAppURL") private var webAppURL = "https://www.ijson.com"
    @AppStorage("appName") private var appName = "Web App"
    @AppStorage("windowWidth") private var windowWidth = 1200.0
    @AppStorage("windowHeight") private var windowHeight = 800.0
    @AppStorage(AppConstants.UserDefaultsKeys.showToolbar) private var showToolbar = AppConstants.DefaultValues.showToolbar
    @StateObject private var themeManager = ThemeManager.shared
    @State private var urlInput = ""
    @State private var nameInput = ""
    @State private var widthInput = ""
    @State private var heightInput = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isClearingCache = false
    @State private var showClearCacheConfirm = false
    @State private var selectedTab = 0
    @State private var currentMemory: Double = 0
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // 顶部标题栏
            HStack {
                Image(systemName: "gearshape.fill")
                    .font(.title2)
                    .foregroundStyle(.blue.gradient)

                Text("应用设置")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("关闭")
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // 标签页选择器
            Picker("", selection: $selectedTab) {
                Label("基本设置", systemImage: "slider.horizontal.3")
                    .tag(0)
                Label("窗口设置", systemImage: "macwindow")
                    .tag(1)
                Label("数据管理", systemImage: "externaldrive")
                    .tag(2)
            }
            .pickerStyle(.segmented)
            .padding()

            // 内容区域
            Group {
                switch selectedTab {
                case 0:
                    basicSettingsTab
                case 1:
                    windowSettingsTab
                case 2:
                    dataManagementTab
                default:
                    basicSettingsTab
                }
            }

            Divider()

            // 底部按钮栏
            HStack(spacing: 12) {
                Spacer()

                Button("取消") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
                .buttonStyle(.bordered)

                Button("保存设置") {
                    saveSettings()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 650, height: 550)
        .onAppear {
            urlInput = webAppURL
            nameInput = appName
            widthInput = String(Int(windowWidth))
            heightInput = String(Int(windowHeight))
            updateMemoryUsage()
        }
        .alert("提示", isPresented: $showAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .alert("清除缓存", isPresented: $showClearCacheConfirm) {
            Button("取消", role: .cancel) { }
            Button("清除", role: .destructive) {
                clearAllCache()
            }
        } message: {
            Text("确定要清除所有缓存和浏览数据吗？\n清除后需要重新登录网站。")
        }
    }

    // MARK: - 基本设置标签页
    private var basicSettingsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 应用名称
                SettingCard(
                    icon: "app.fill",
                    iconColor: .blue,
                    title: "应用名称",
                    description: "设置应用的显示名称"
                ) {
                    TextField("输入应用名称", text: $nameInput)
                        .textFieldStyle(.roundedBorder)
                        .font(.body)
                }

                // 网站地址
                SettingCard(
                    icon: "globe",
                    iconColor: .green,
                    title: "网站地址",
                    description: "输入要打开的网站完整地址（包含 https://）"
                ) {
                    TextField("https://www.example.com", text: $urlInput)
                        .textFieldStyle(.roundedBorder)
                        .font(.body)
                }

                // 预设网站
                SettingCard(
                    icon: "star.fill",
                    iconColor: .orange,
                    title: "快速选择",
                    description: "选择常用网站快速填充"
                ) {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 10) {
                        PresetWebsiteButton(name: "Apple", url: "https://www.apple.com", icon: "apple.logo", urlInput: $urlInput)
                        PresetWebsiteButton(name: "Google", url: "https://www.google.com", icon: "magnifyingglass", urlInput: $urlInput)
                        PresetWebsiteButton(name: "GitHub", url: "https://github.com", icon: "chevron.left.forwardslash.chevron.right", urlInput: $urlInput)
                        PresetWebsiteButton(name: "ShareCRM", url: "https://www.fxiaoke.com", icon: "building.2", urlInput: $urlInput)
                    }
                }
                
                // 主题设置
                SettingCard(
                    icon: "paintbrush.fill",
                    iconColor: .purple,
                    title: "外观主题",
                    description: "选择应用和网站的显示主题"
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("主题模式", selection: $themeManager.colorScheme) {
                            ForEach(ThemeManager.AppColorScheme.allCases, id: \.self) { scheme in
                                Text(scheme.displayName).tag(scheme)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: themeManager.colorScheme) { _, _ in
                            themeManager.updateEffectiveColorScheme()
                        }
                        
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("当前主题: \(themeManager.effectiveColorScheme.displayName)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // 工具栏显示设置
                SettingCard(
                    icon: "menubar.rectangle",
                    iconColor: .blue,
                    title: "显示工具栏",
                    description: "控制顶部工具栏（后退、前进、刷新、下载、设置等按钮）的显示"
                ) {
                    Toggle("显示顶部工具栏", isOn: $showToolbar)
                        .toggleStyle(.switch)
                    
                    if !showToolbar {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle")
                                .font(.caption)
                                .foregroundColor(.orange)
                            Text("工具栏已隐藏，可通过菜单栏「编辑」→「设置」重新打开")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 4)
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - 窗口设置标签页
    private var windowSettingsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 窗口尺寸
                SettingCard(
                    icon: "macwindow",
                    iconColor: .purple,
                    title: "窗口尺寸",
                    description: "设置应用窗口的默认大小（400-5000 像素）"
                ) {
                    VStack(spacing: 16) {
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("宽度", systemImage: "arrow.left.and.right")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                HStack {
                                    TextField("1200", text: $widthInput)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 100)
                                    Text("像素")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Label("高度", systemImage: "arrow.up.and.down")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                HStack {
                                    TextField("800", text: $heightInput)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 100)
                                    Text("像素")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }

                        // 预设尺寸
                        VStack(alignment: .leading, spacing: 8) {
                            Text("常用尺寸")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            HStack(spacing: 8) {
                                PresetSizeButton(width: "1024", height: "768", label: "iPad", widthInput: $widthInput, heightInput: $heightInput)
                                PresetSizeButton(width: "1280", height: "800", label: "笔记本", widthInput: $widthInput, heightInput: $heightInput)
                                PresetSizeButton(width: "1920", height: "1080", label: "全高清", widthInput: $widthInput, heightInput: $heightInput)
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - 数据管理标签页
    private var dataManagementTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 内存使用情况
                SettingCard(
                    icon: "memorychip",
                    iconColor: .cyan,
                    title: "内存使用",
                    description: "当前应用内存占用情况"
                ) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(String(format: "%.1f MB", currentMemory))
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            Text("当前内存占用")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Button(action: updateMemoryUsage) {
                            Label("刷新", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)
                    }
                }

                // 清理运行时内存
                SettingCard(
                    icon: "wind",
                    iconColor: .mint,
                    title: "清理运行时内存",
                    description: "仅清理内存缓存，不影响登录状态"
                ) {
                    Button(action: clearRuntimeMemory) {
                        Label("立即清理", systemImage: "sparkles")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }

                // 清除所有缓存
                SettingCard(
                    icon: "trash.fill",
                    iconColor: .red,
                    title: "清除所有缓存",
                    description: "清除所有浏览数据、Cookie 和缓存（需要重新登录）"
                ) {
                    Button(action: { showClearCacheConfirm = true }) {
                        if isClearingCache {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Label("清除所有数据", systemImage: "exclamationmark.triangle.fill")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .controlSize(.large)
                    .disabled(isClearingCache)
                }
            }
            .padding()
        }
    }

    // MARK: - 辅助方法
    private func updateMemoryUsage() {
        currentMemory = WebViewModel.shared.getMemoryUsage()
    }
    
    private func saveSettings() {
        // 验证 URL
        guard !urlInput.isEmpty else {
            alertMessage = "请输入网站地址"
            showAlert = true
            return
        }

        guard urlInput.hasPrefix("http://") || urlInput.hasPrefix("https://") else {
            alertMessage = "网站地址必须以 http:// 或 https:// 开头"
            showAlert = true
            return
        }

        guard URL(string: urlInput) != nil else {
            alertMessage = "网站地址格式不正确"
            showAlert = true
            return
        }

        // 验证名称
        guard !nameInput.isEmpty else {
            alertMessage = "请输入应用名称"
            showAlert = true
            return
        }

        // 验证窗口大小
        guard let width = Double(widthInput),
              width >= AppConstants.DefaultValues.minWindowWidth,
              width <= AppConstants.DefaultValues.maxWindowWidth else {
            alertMessage = "窗口宽度必须在 \(Int(AppConstants.DefaultValues.minWindowWidth))-\(Int(AppConstants.DefaultValues.maxWindowWidth)) 之间"
            showAlert = true
            return
        }

        guard let height = Double(heightInput),
              height >= AppConstants.DefaultValues.minWindowHeight,
              height <= AppConstants.DefaultValues.maxWindowHeight else {
            alertMessage = "窗口高度必须在 \(Int(AppConstants.DefaultValues.minWindowHeight))-\(Int(AppConstants.DefaultValues.maxWindowHeight)) 之间"
            showAlert = true
            return
        }

        // 保存设置
        webAppURL = urlInput
        appName = nameInput
        windowWidth = width
        windowHeight = height

        // 加载新 URL
        WebViewModel.shared.loadURL(urlInput)

        // 更新窗口大小 - 查找主窗口
        DispatchQueue.main.async {
            // 优先使用主窗口，其次使用当前活跃窗口
            if let mainWindow = NSApp.windows.first(where: { $0.isMainWindow }) {
                mainWindow.setContentSize(NSSize(width: width, height: height))
            } else if let window = NSApp.windows.first {
                window.setContentSize(NSSize(width: width, height: height))
            }
        }

        // 关闭窗口
        dismiss()
    }

    private func clearAllCache() {
        isClearingCache = true

        WebViewModel.shared.clearAllCache { success in
            self.isClearingCache = false
            if success {
                self.alertMessage = """
                ✅ 缓存已清除！

                已清除以下数据：
                • 浏览历史
                • Cookie
                • 缓存文件
                • 本地存储
                • 数据库

                下次访问网站时需要重新登录。
                """
            } else {
                self.alertMessage = "清除缓存失败，请重试"
            }
            self.showAlert = true
        }
    }

    private func clearRuntimeMemory() {
        let memoryBefore = WebViewModel.shared.getMemoryUsage()
        WebViewModel.shared.clearRuntimeCache()

        // 延迟一下再获取内存，让系统有时间回收
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let memoryAfter = WebViewModel.shared.getMemoryUsage()
            let saved = memoryBefore - memoryAfter
            self.currentMemory = memoryAfter

            self.alertMessage = String(format: """
            ✅ 运行时内存已清理！

            清理前: %.1f MB
            清理后: %.1f MB
            释放: %.1f MB

            登录状态未受影响。
            """, memoryBefore, memoryAfter, saved)
            self.showAlert = true
        }
    }
}

// MARK: - 辅助组件

/// 设置卡片组件
struct SettingCard<Content: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    let content: Content

    init(
        icon: String,
        iconColor: Color,
        title: String,
        description: String,
        @ViewBuilder content: () -> Content
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.description = description
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(iconColor.gradient)
                    .frame(width: 32, height: 32)
                    .background(iconColor.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            content
                .padding(.leading, 44)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }
}

/// 预设网站按钮
struct PresetWebsiteButton: View {
    let name: String
    let url: String
    let icon: String
    @Binding var urlInput: String

    var body: some View {
        Button(action: {
            urlInput = url
        }) {
            HStack {
                Image(systemName: icon)
                    .font(.body)
                Text(name)
                    .font(.body)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.bordered)
    }
}

/// 预设尺寸按钮
struct PresetSizeButton: View {
    let width: String
    let height: String
    let label: String
    @Binding var widthInput: String
    @Binding var heightInput: String

    var body: some View {
        Button(action: {
            widthInput = width
            heightInput = height
        }) {
            VStack(spacing: 4) {
                Text(label)
                    .font(.caption)
                    .fontWeight(.medium)
                Text("\(width)×\(height)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        .buttonStyle(.bordered)
    }
}

#Preview {
    SettingsView()
}

