//
//  ContentView.swift
//  SiteBox
//
//  Created by 崔永旭 on 22/12/2025.
//

import SwiftUI
import WebKit
import AppKit

struct ContentView: View {
    @StateObject private var webViewModel = WebViewModel.shared
    @StateObject private var downloadManager = DownloadManager.shared
    @StateObject private var themeManager = ThemeManager.shared
    @AppStorage(AppConstants.UserDefaultsKeys.showToolbar) private var showToolbar = AppConstants.DefaultValues.showToolbar
    @State private var showSettings = false
    @State private var showCopiedToast = false
    @State private var isHoveringBack = false
    @State private var isHoveringForward = false
    @State private var isHoveringRefresh = false
    @State private var isHoveringCopyURL = false
    @State private var isHoveringOpenBrowser = false
    @State private var isHoveringDownload = false
    @State private var isHoveringSettings = false

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                // 顶部工具栏
            if showToolbar {
                HStack(spacing: 12) {
                // 后退按钮
                Button(action: {
                    webViewModel.goBack()
                }) {
                    HoverTrackingImage(
                        systemName: "chevron.left",
                        fontSize: 14,
                        isHovered: isHoveringBack,
                        isPointingHand: webViewModel.canGoBack,
                        hovered: $isHoveringBack
                    )
                    .frame(width: 20, height: 20)
                }
                .disabled(!webViewModel.canGoBack)
                .buttonStyle(.plain)
                .help("后退")

                // 前进按钮
                Button(action: {
                    webViewModel.goForward()
                }) {
                    HoverTrackingImage(
                        systemName: "chevron.right",
                        fontSize: 14,
                        isHovered: isHoveringForward,
                        isPointingHand: webViewModel.canGoForward,
                        hovered: $isHoveringForward
                    )
                    .frame(width: 20, height: 20)
                }
                .disabled(!webViewModel.canGoForward)
                .buttonStyle(.plain)
                .help("前进")

                // 刷新按钮
                Button(action: {
                    webViewModel.reload()
                }) {
                    HoverTrackingImage(
                        systemName: webViewModel.isLoading ? "stop.circle" : "arrow.clockwise",
                        fontSize: 14,
                        isHovered: isHoveringRefresh,
                        isPointingHand: true,
                        hovered: $isHoveringRefresh
                    )
                    .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .help(webViewModel.isLoading ? "停止" : "刷新")

                // 地址栏（显示完整 URL，支持复制）
                HStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.green)

                    TextField("", text: .constant(webViewModel.currentURL))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .textFieldStyle(.plain)
                        .disabled(true) // 禁用编辑，但允许选择和复制
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // 复制按钮
                    Button(action: {
                        let pasteboard = NSPasteboard.general
                        pasteboard.clearContents()
                        pasteboard.setString(webViewModel.currentURL, forType: .string)
                        
                        showCopiedToast = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            showCopiedToast = false
                        }
                    }) {
                        HoverTrackingImage(
                            systemName: showCopiedToast ? "checkmark.circle.fill" : "doc.on.doc",
                            fontSize: 11,
                            isHovered: isHoveringCopyURL,
                            isPointingHand: true,
                            hovered: $isHoveringCopyURL
                        )
                        .frame(width: 16, height: 16)
                        .foregroundColor(showCopiedToast ? .green : .secondary)
                    }
                    .buttonStyle(.plain)
                    .help("复制 URL")
                    
                    // 在系统浏览器中打开按钮
                    Button(action: {
                        if let url = URL(string: webViewModel.currentURL) {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        HoverTrackingImage(
                            systemName: "arrow.up.right.square",
                            fontSize: 11,
                            isHovered: isHoveringOpenBrowser,
                            isPointingHand: true,
                            hovered: $isHoveringOpenBrowser
                        )
                        .frame(width: 16, height: 16)
                        .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("在系统默认浏览器中打开")
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)

                Spacer()

                // 下载按钮
                Button(action: {
                    downloadManager.showDownloadPanel = true
                }) {
                    ZStack(alignment: .topTrailing) {
                        HoverTrackingImage(
                            systemName: "arrow.down.circle",
                            fontSize: 14,
                            isHovered: isHoveringDownload,
                            isPointingHand: true,
                            hovered: $isHoveringDownload
                        )
                        .frame(width: 20, height: 20)

                        // 下载数量徽章
                        if !downloadManager.downloads.isEmpty {
                            let activeCount = downloadManager.downloads.filter { $0.state == .downloading }.count
                            if activeCount > 0 {
                                Text("\(activeCount)")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(2)
                                    .background(Color.blue)
                                    .clipShape(Circle())
                                    .offset(x: 6, y: -6)
                            }
                        }
                    }
                }
                .buttonStyle(.plain)
                .help("下载管理")

                // 设置按钮
                Button(action: {
                    showSettings = true
                }) {
                    HoverTrackingImage(
                        systemName: "gearshape",
                        fontSize: 14,
                        isHovered: isHoveringSettings,
                        isPointingHand: true,
                        hovered: $isHoveringSettings
                    )
                    .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .help("设置")

                // 加载进度指示器
                if webViewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 20, height: 20)
                }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(NSColor.windowBackgroundColor))

                Divider()
            }

            // WebView 内容区域
            WebView(viewModel: webViewModel)
        }
        .overlay(alignment: .top) {
            if let error = webViewModel.loadError {
                HStack(spacing: 8) {
                    Image(systemName: "wifi.exclamationmark")
                        .foregroundColor(.white)
                    Text(error)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.red.opacity(0.9))
                        .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                )
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.easeInOut(duration: 0.3), value: webViewModel.loadError)
            }
        }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $downloadManager.showDownloadPanel) {
            DownloadPanel()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name(AppConstants.Notifications.toggleDevTools))) { _ in
            webViewModel.toggleDevTools()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name(AppConstants.Notifications.showSettings))) { _ in
            showSettings = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name(AppConstants.Notifications.showDownloads))) { _ in
            downloadManager.showDownloadPanel = true
        }
        .focusedSceneValue(\.webViewModel, webViewModel)
    }
}

// 快捷键支持
extension FocusedValues {
    struct WebViewModelKey: FocusedValueKey {
        typealias Value = WebViewModel
    }

    var webViewModel: WebViewModel? {
        get { self[WebViewModelKey.self] }
        set { self[WebViewModelKey.self] = newValue }
    }
}

// MARK: - HoverTrackingImage
// 使用 AppKit NSTrackingArea + resetCursorRects 实现鼠标跟踪，解决 SwiftUI onHover 在某些场景下 cursor 不生效的问题
struct HoverTrackingImage: NSViewRepresentable {
    let systemName: String
    let fontSize: CGFloat
    let isHovered: Bool
    let isPointingHand: Bool
    @Binding var hovered: Bool

    func makeNSView(context: Context) -> CursorTrackingView {
        let view = CursorTrackingView(
            systemName: systemName,
            fontSize: fontSize,
            isHovered: isHovered,
            isPointingHand: isPointingHand,
            onHoverChange: { [weak coordinator = context.coordinator] isHovered in
                coordinator?.parent.hovered = isHovered
            }
        )
        return view
    }

    func updateNSView(_ nsView: CursorTrackingView, context: Context) {
        nsView.update(systemName: systemName, fontSize: fontSize, isHovered: isHovered, isPointingHand: isPointingHand)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator {
        var parent: HoverTrackingImage

        init(_ parent: HoverTrackingImage) {
            self.parent = parent
        }
    }
}

// 内部 NSView 子类，处理图片显示、光标和鼠标跟踪
class CursorTrackingView: NSView {
    private let imageView: NSImageView
    private var trackingArea: NSTrackingArea?
    private var isHovered: Bool = false
    private var isPointingHand: Bool = true
    private var onHoverChange: ((Bool) -> Void)?

    init(systemName: String, fontSize: CGFloat, isHovered: Bool, isPointingHand: Bool, onHoverChange: @escaping (Bool) -> Void) {
        self.imageView = NSImageView()
        self.isHovered = isHovered
        self.isPointingHand = isPointingHand
        self.onHoverChange = onHoverChange

        super.init(frame: .zero)

        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.isEditable = false
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        updateImage(systemName: systemName, fontSize: fontSize)
        updateTrackingArea()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(systemName: String, fontSize: CGFloat, isHovered: Bool, isPointingHand: Bool) {
        self.isHovered = isHovered
        self.isPointingHand = isPointingHand
        updateImage(systemName: systemName, fontSize: fontSize)
        resetCursorRects()
    }

    private func updateImage(systemName: String, fontSize: CGFloat) {
        let config = NSImage.SymbolConfiguration(pointSize: fontSize, weight: .medium)
        imageView.image = NSImage(systemSymbolName: systemName, accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
    }

    private func updateTrackingArea() {
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let newArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect, .enabledDuringMouseDrag],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(newArea)
        trackingArea = newArea
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        onHoverChange?(true)
        resetCursorRects()
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        onHoverChange?(false)
        resetCursorRects()
    }

    override func layout() {
        super.layout()
        updateTrackingArea()
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        if isHovered && isPointingHand {
            addCursorRect(bounds, cursor: .pointingHand)
        } else {
            addCursorRect(bounds, cursor: .arrow)
        }
    }
}

#Preview {
    ContentView()
}
