//
//  ImageViewer.swift
//  SiteBox
//
//  独立浮动图片查看窗口（类似飞书）
//  窗口自动适配图片尺寸，可在桌面任意拖动
//

import SwiftUI
import AppKit

/// 图片查看器
class ImageViewerModel {
    static let shared = ImageViewerModel()
    
    private var viewerWindow: NSWindow?
    private var hostingController: NSHostingController<ImageViewerContent>?
    
    func show(imageURL url: String) {
        close()
        
        // 先用默认尺寸，图片加载后自动调整
        guard let screen = NSScreen.main else { return }
        let visibleFrame = screen.visibleFrame
        let windowRect = NSRect(
            x: visibleFrame.midX - 400,
            y: visibleFrame.midY - 300,
            width: 800,
            height: 600
        )
        
        let window = NSWindow(
            contentRect: windowRect,
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        window.title = "图片查看"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.backgroundColor = .black
        window.isOpaque = false
        window.hasShadow = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.minSize = NSSize(width: 200, height: 150)
        window.isReleasedWhenClosed = false
        
        self.viewerWindow = window
        
        // 内容视图
        let contentView = ImageViewerContent(
            imageURL: url,
            onClose: { [weak self] in self?.close() },
            onImageLoaded: { [weak self] imageSize in
                self?.resizeWindowToFit(imageSize: imageSize, screen: screen)
            }
        )
        
        let hostingController = NSHostingController(rootView: contentView)
        self.hostingController = hostingController
        window.contentViewController = hostingController
        
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: false)
    }
    
    func close() {
        viewerWindow?.close()
        viewerWindow = nil
        hostingController = nil
    }
    
    /// 根据图片实际尺寸调整窗口大小
    private func resizeWindowToFit(imageSize: NSSize, screen: NSScreen) {
        guard let window = viewerWindow else { return }
        
        let visibleFrame = screen.visibleFrame
        let maxWidth = visibleFrame.width * 0.9
        let maxHeight = visibleFrame.height * 0.85
        
        // 加上标题栏高度（fullSizeContentView 模式下约 28pt）
        let titleBarHeight: CGFloat = 28
        
        // 计算适配尺寸
        var displayWidth = imageSize.width
        var displayHeight = imageSize.height + titleBarHeight
        
        // 如果图片超过最大尺寸，等比缩放
        if displayWidth > maxWidth || displayHeight > maxHeight {
            let widthRatio = maxWidth / displayWidth
            let heightRatio = maxHeight / displayHeight
            let ratio = min(widthRatio, heightRatio)
            displayWidth = imageSize.width * ratio
            displayHeight = imageSize.height * ratio + titleBarHeight
        }
        
        // 最小尺寸
        displayWidth = max(displayWidth, 300)
        displayHeight = max(displayHeight, 200)
        
        // 居中
        let newX = visibleFrame.midX - displayWidth / 2
        let newY = visibleFrame.midY - displayHeight / 2
        let newRect = NSRect(x: newX, y: newY, width: displayWidth, height: displayHeight)
        
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().setFrame(newRect, display: true)
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

/// 图片查看器窗口内容
struct ImageViewerContent: View {
    let imageURL: String
    let onClose: () -> Void
    let onImageLoaded: (NSSize) -> Void
    
    @State private var nsImage: NSImage? = nil
    @State private var isLoading = true
    @State private var loadError: String? = nil
    @State private var scale: CGFloat = 1.0
    @State private var dragOffset: CGSize = .zero
    @State private var accumulatedOffset: CGSize = .zero
    @State private var isHoveringImage: Bool = false
    @State private var showHUD = true
    @State private var hudTimer: Timer?
    private let hudAutoHideDelay: TimeInterval = 2.5
    
    var body: some View {
        ZStack {
            Color.black
            
            GeometryReader { geometry in
                if isLoading {
                    loadingView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = loadError {
                    errorView(error)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let image = nsImage {
                    imageView(image: image, containerSize: geometry.size)
                }
            }
            
            // HUD（底部）
            if showHUD && nsImage != nil {
                VStack {
                    Spacer()
                    bottomBar
                }
                .transition(.opacity)
            }
            
            // 右下角浮动缩放控件
            if showHUD && nsImage != nil {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        zoomControls
                            .padding(.trailing, 16)
                            .padding(.bottom, 16)
                    }
                }
            }
            
            // 关闭按钮
            VStack {
                HStack {
                    closeButton
                    Spacer()
                }
                Spacer()
            }
            .padding(8)
        }
        .onAppear {
            loadImage()
            resetHUDTimer()
        }
        .onDisappear { hudTimer?.invalidate() }
        .onHover { hovering in
            if hovering {
                showHUD = true
                resetHUDTimer()
            }
        }
        .onKeyPress(.escape) { onClose(); return .handled }
        .onKeyPress(.leftArrow) {
            let s = max(scale - 0.25, 0.25)
            withAnimation(.easeInOut(duration: 0.12)) { scale = s }
            return .handled
        }
        .onKeyPress(.rightArrow) {
            let s = min(scale + 0.25, 5.0)
            withAnimation(.easeInOut(duration: 0.12)) { scale = s }
            return .handled
        }
        .onKeyPress("0") {
            withAnimation(.easeInOut(duration: 0.12)) { scale = 1.0; accumulatedOffset = .zero }
            return .handled
        }
        .onKeyPress("s") { saveImage(); return .handled }
        .onScrollWheel { event in
            if event.modifierFlags.contains(.command) || event.modifierFlags.contains(.control) {
                if event.deltaY > 0 {
                    let s = min(scale + 0.25, 5.0)
                    withAnimation(.easeInOut(duration: 0.12)) { scale = s }
                } else if event.deltaY < 0 {
                    let s = max(scale - 0.25, 0.25)
                    withAnimation(.easeInOut(duration: 0.12)) { scale = s; if s <= 1.0 { accumulatedOffset = .zero } }
                }
                showHUD = true
                resetHUDTimer()
            }
        }
    }
    
    // MARK: - 图片显示
    
    private func imageView(image: NSImage, containerSize: CGSize) -> some View {
        let imgSize = image.size
        // 计算让图片填满容器且不超出的缩放
        let fitScale = min(containerSize.width / imgSize.width, containerSize.height / imgSize.height)
        let displayScale = fitScale * scale
        
        // 总偏移 = 累积位移 + 当前拖拽位移
        let totalOffset = CGSize(
            width: accumulatedOffset.width + dragOffset.width,
            height: accumulatedOffset.height + dragOffset.height
        )
        
        return Image(nsImage: image)
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fill)
            .frame(
                width: imgSize.width * displayScale,
                height: imgSize.height * displayScale
            )
            .clipped()
            .position(
                x: containerSize.width / 2 + totalOffset.width,
                y: containerSize.height / 2 + totalOffset.height
            )
            .gesture(
                scale > 1.0 ?
                    DragGesture()
                        .onChanged { value in
                            dragOffset = value.translation
                        }
                        .onEnded { value in
                            accumulatedOffset.width += value.translation.width
                            accumulatedOffset.height += value.translation.height
                            dragOffset = .zero
                        }
                    : nil
            )
            .onHover { hovering in
                isHoveringImage = hovering
                if hovering && scale > 1.0 {
                    NSCursor.openHand.set()
                } else {
                    NSCursor.arrow.set()
                }
            }
            .onTapGesture(count: 2) {
                if scale > 1.0 {
                    withAnimation(.easeInOut(duration: 0.15)) { scale = 1.0; accumulatedOffset = .zero }
                } else {
                    withAnimation(.easeInOut(duration: 0.15)) { scale = 2.5 }
                }
                showHUD = true
                resetHUDTimer()
            }
            .onTapGesture(count: 1) {
                withAnimation(.easeInOut(duration: 0.2)) { showHUD.toggle() }
                if showHUD { resetHUDTimer() }
            }
    }
    
    // MARK: - 加载 / 错误视图
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.3)
                .tint(.white)
            Text("加载中...")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.5))
        }
    }
    
    private func errorView(_ msg: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36))
                .foregroundColor(.white.opacity(0.5))
            Text(msg)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.6))
        }
    }
    
    // MARK: - 底部信息栏
    
    private var bottomBar: some View {
        HStack(spacing: 0) {
            // 左侧：文件名 + 尺寸
            HStack(spacing: 8) {
                Text(displayFileName)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                if let img = nsImage {
                    Text("\(Int(img.size.width))×\(Int(img.size.height))")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.white.opacity(0.35))
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [.black.opacity(0), .black.opacity(0.55)]),
                startPoint: .top, endPoint: .bottom
            )
        )
    }
    
    /// 右下角浮动缩放控件 — 大且醒目
    private var zoomControls: some View {
        VStack(spacing: 0) {
            Button(action: {
                let s = min(scale + 0.25, 5.0)
                withAnimation(.easeInOut(duration: 0.12)) { scale = s }
                resetHUDTimer()
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 48, height: 48)
            }
            .buttonStyle(.plain)
            .help("放大 (⌘↑)")
            
            Divider()
                .frame(width: 30)
                .background(Color.white.opacity(0.15))
            
            // 百分比（点击重置）
            Text("\(Int(scale * 100))%")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(.white.opacity(0.8))
                .frame(width: 48, height: 28)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.15)) { scale = 1.0; accumulatedOffset = .zero }
                }
            
            Divider()
                .frame(width: 30)
                .background(Color.white.opacity(0.15))
            
            Button(action: {
                let s = max(scale - 0.25, 0.25)
                withAnimation(.easeInOut(duration: 0.12)) { scale = s }
                resetHUDTimer()
            }) {
                Image(systemName: "minus")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 48, height: 48)
            }
            .buttonStyle(.plain)
            .help("缩小 (⌘↓)")
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
    }
    
    // MARK: - 关闭按钮
    
    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white.opacity(0.75))
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.white.opacity(0.12)))
        }
        .buttonStyle(.plain)
        .help("关闭 (ESC)")
    }
    
    // MARK: - 辅助
    
    private var displayFileName: String {
        let comps = imageURL.components(separatedBy: "/")
        let raw = comps.last ?? "image"
        return raw.components(separatedBy: "?").first ?? raw
    }
    
    private func resetHUDTimer() {
        hudTimer?.invalidate()
        hudTimer = Timer.scheduledTimer(withTimeInterval: hudAutoHideDelay, repeats: false) { _ in
            withAnimation(.easeInOut(duration: 0.25)) { showHUD = false }
        }
    }
    
    private func saveImage() {
        guard let image = nsImage else { return }
        let panel = NSSavePanel()
        panel.message = "保存图片"
        panel.prompt = "保存"
        panel.canCreateDirectories = true
        panel.directoryURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        panel.nameFieldStringValue = displayFileName
        
        if panel.runModal() == .OK, let dest = panel.url {
            guard let tiff = image.tiffRepresentation,
                  let bmp = NSBitmapImageRep(data: tiff) else { return }
            let ext = dest.pathExtension.lowercased()
            let data: Data?
            switch ext {
            case "png": data = bmp.representation(using: .png, properties: [:])
            case "jpg", "jpeg": data = bmp.representation(using: .jpeg, properties: [.compressionFactor: 0.9])
            default: data = bmp.representation(using: .png, properties: [:])
            }
            if let d = data { try? d.write(to: dest); NSWorkspace.shared.activateFileViewerSelecting([dest]) }
        }
    }
    
    // MARK: - 图片加载
    
    private func loadImage() {
        if let cached = ImageCache.shared.get(imageURL) {
            self.nsImage = cached
            self.isLoading = false
            self.onImageLoaded(cached.size)
            return
        }
        
        guard let url = URL(string: imageURL) else {
            self.loadError = "无效的图片地址"
            self.isLoading = false
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, _, error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    self.loadError = "加载失败"
                    return
                }
                
                guard let data = data, let image = NSImage(data: data) else {
                    self.loadError = "无法解析图片"
                    return
                }
                
                self.nsImage = image
                ImageCache.shared.set(self.imageURL, image: image)
                self.onImageLoaded(image.size)
            }
        }.resume()
    }
}

/// 简单内存缓存
class ImageCache {
    static let shared = ImageCache()
    private let cache = NSCache<NSString, NSImage>()
    
    private init() {
        cache.countLimit = 50
        cache.totalCostLimit = 100 * 1024 * 1024
    }
    
    func get(_ url: String) -> NSImage? { cache.object(forKey: url as NSString) }
    func set(_ url: String, image: NSImage) { cache.setObject(image, forKey: url as NSString) }
    func clear() { cache.removeAllObjects() }
}

// MARK: - 滚轮

extension View {
    func onScrollWheel(perform action: @escaping (NSEvent) -> Void) -> some View {
        background(ScrollWheelCatcher(action: action))
    }
}

struct ScrollWheelCatcher: NSViewRepresentable {
    let action: (NSEvent) -> Void
    
    func makeNSView(context: Context) -> ScrollWheelView {
        let v = ScrollWheelView(); v.onScrollWheel = action; return v
    }
    
    func updateNSView(_ nsView: ScrollWheelView, context: Context) {}
    
    class ScrollWheelView: NSView {
        var onScrollWheel: ((NSEvent) -> Void)?
        override func scrollWheel(with event: NSEvent) { onScrollWheel?(event) }
    }
}
