//
//  DownloadPanel.swift
//  SiteBox
//
//  Created on 28/12/2025.
//

import SwiftUI
import AppKit
import Combine

/// 下载面板
struct DownloadPanel: View {
    @ObservedObject var downloadManager = DownloadManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.blue.gradient)
                
                Text("下载管理")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if !downloadManager.downloads.isEmpty {
                    Button(action: clearCompleted) {
                        Text("清除已完成")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                
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
            
            // 下载列表
            if downloadManager.downloads.isEmpty {
                emptyView
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(downloadManager.downloads) { item in
                            DownloadItemView(item: item)
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(width: 500, height: 400)
    }
    
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text("暂无下载")
                .font(.title3)
                .foregroundColor(.secondary)
            
            Text("从网站下载的文件将显示在这里")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func clearCompleted() {
        downloadManager.downloads.removeAll { $0.state == .completed || $0.state == .failed || $0.state == .cancelled }
    }
}

/// 下载项视图
struct DownloadItemView: View {
    @ObservedObject var item: DownloadItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // 文件图标
                Image(systemName: fileIcon)
                    .font(.title2)
                    .foregroundColor(iconColor)
                    .frame(width: 40, height: 40)
                    .background(iconColor.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.fileName)
                        .font(.body)
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        Text(item.stateText)
                            .font(.caption)
                            .foregroundColor(stateColor)
                        
                        if item.state == .downloading {
                            Text(item.progressText)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if let error = item.error {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                                .lineLimit(1)
                        }
                    }
                }
                
                Spacer()
                
                // 操作按钮
                HStack(spacing: 8) {
                    if item.state == .completed, let url = item.destinationURL {
                        Button(action: { openFile(url) }) {
                            Image(systemName: "folder")
                        }
                        .buttonStyle(.bordered)
                        .help("在访达中显示")

                        Button(action: { saveToDownloads(item, from: url) }) {
                            Image(systemName: "arrow.down.to.line")
                        }
                        .buttonStyle(.bordered)
                        .help("保存到下载文件夹")
                    }
                    
                    if item.state == .downloading {
                        Button(action: { DownloadManager.shared.cancelDownload(item) }) {
                            Image(systemName: "xmark")
                        }
                        .buttonStyle(.bordered)
                        .help("取消")
                    }
                }
            }
            
            // 进度条
            if item.state == .downloading {
                ProgressView(value: item.progress)
                    .progressViewStyle(.linear)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var fileIcon: String {
        let ext = (item.fileName as NSString).pathExtension.lowercased()
        switch ext {
        case "pdf": return "doc.fill"
        case "zip", "rar", "7z": return "doc.zipper"
        case "jpg", "jpeg", "png", "gif", "webp": return "photo.fill"
        case "mp4", "mov", "avi": return "video.fill"
        case "mp3", "wav", "m4a": return "music.note"
        case "doc", "docx": return "doc.text.fill"
        case "xls", "xlsx": return "tablecells.fill"
        case "ppt", "pptx": return "rectangle.stack.fill"
        default: return "doc.fill"
        }
    }

    private var iconColor: Color {
        switch item.state {
        case .downloading: return .blue
        case .completed: return .green
        case .failed: return .red
        case .cancelled: return .gray
        case .paused: return .orange
        }
    }

    private var stateColor: Color {
        switch item.state {
        case .downloading: return .blue
        case .completed: return .green
        case .failed: return .red
        case .cancelled: return .secondary
        case .paused: return .orange
        }
    }

    private func openFile(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private func saveToDownloads(_ item: DownloadItem, from sourceURL: URL) {
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            print("❌ 源文件不存在: \(sourceURL.path)")
            return
        }

        let panel = NSSavePanel()
        panel.message = "选择保存位置"
        panel.prompt = "保存"
        panel.nameFieldStringValue = item.fileName
        panel.canCreateDirectories = true

        // 默认目录为 Downloads
        panel.directoryURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first

        if panel.runModal() == .OK, let destinationURL = panel.url {
            do {
                // 如果目标文件已存在，先删除
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }

                // 复制文件
                try FileManager.default.copyItem(at: sourceURL, to: destinationURL)

                // 更新下载项的目标 URL
                item.destinationURL = destinationURL

                // 在访达中显示
                NSWorkspace.shared.activateFileViewerSelecting([destinationURL])

                print("✅ 文件已保存到: \(destinationURL.path)")
            } catch {
                print("❌ 保存文件失败: \(error.localizedDescription)")
            }
        }
    }
}

#Preview {
    DownloadPanel()
}

