//
//  DownloadManager.swift
//  SiteBox
//
//  Created on 28/12/2025.
//

import SwiftUI
import WebKit
import UserNotifications
import Combine

/// 下载项
class DownloadItem: NSObject, ObservableObject, Identifiable {
    let id = UUID()
    @Published var fileName: String
    @Published var progress: Double = 0.0
    @Published var totalSize: Int64 = 0
    @Published var downloadedSize: Int64 = 0
    @Published var state: DownloadState = .downloading
    @Published var error: String?
    
    var download: WKDownload?
    var destinationURL: URL?
    
    enum DownloadState {
        case downloading
        case paused
        case completed
        case failed
        case cancelled
    }
    
    init(fileName: String) {
        self.fileName = fileName
        super.init()
    }
    
    var progressText: String {
        let downloaded = ByteCountFormatter.string(fromByteCount: downloadedSize, countStyle: .file)
        let total = ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
        return "\(downloaded) / \(total)"
    }
    
    var stateText: String {
        switch state {
        case .downloading: return "下载中"
        case .paused: return "已暂停"
        case .completed: return "已完成"
        case .failed: return "失败"
        case .cancelled: return "已取消"
        }
    }
}

/// 下载管理器
class DownloadManager: NSObject, ObservableObject {
    static let shared = DownloadManager()

    @Published var downloads: [DownloadItem] = []
    @Published var showDownloadPanel = false

    // 通知权限是否已请求（类级别共享）
    private static var notificationPermissionRequested = false

    private var downloadFolder: URL {
        FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
    }

    override init() {
        super.init()
        requestNotificationPermission()
    }

    /// 请求通知权限（仅请求一次）
    private func requestNotificationPermission() {
        guard !DownloadManager.notificationPermissionRequested else { return }
        DownloadManager.notificationPermissionRequested = true

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("✅ 通知权限已授予")
            } else if let error = error {
                print("❌ 通知权限请求失败: \(error.localizedDescription)")
            }
        }
    }
    
    /// 开始下载
    func startDownload(_ download: WKDownload, suggestedFilename: String, destinationURL: URL) {
        let item = DownloadItem(fileName: suggestedFilename)
        item.download = download
        item.destinationURL = destinationURL

        print("📥 下载管理器：添加下载项 - \(suggestedFilename)")
        print("📁 目标 URL: \(destinationURL.path)")

        DispatchQueue.main.async {
            self.downloads.insert(item, at: 0)
            self.showDownloadPanel = true
            print("📊 当前下载数量: \(self.downloads.count)")
        }
    }
    
    /// 更新下载进度
    func updateProgress(for download: WKDownload, bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let item = downloads.first(where: { $0.download === download }) else { return }
        
        DispatchQueue.main.async {
            item.downloadedSize = totalBytesWritten
            item.totalSize = totalBytesExpectedToWrite
            
            if totalBytesExpectedToWrite > 0 {
                item.progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            }
        }
    }
    
    /// 下载完成
    func downloadCompleted(for download: WKDownload, destinationURL: URL) {
        guard let item = downloads.first(where: { $0.download === download }) else { return }

        DispatchQueue.main.async {
            item.state = .completed
            item.progress = 1.0
            item.destinationURL = destinationURL

            print("✅ 下载完成: \(item.fileName)")
            print("📁 文件位置: \(destinationURL.path)")

            // 发送通知
            self.sendNotification(title: "下载完成", body: item.fileName)
        }
    }
    
    /// 下载失败
    func downloadFailed(for download: WKDownload, error: Error) {
        guard let item = downloads.first(where: { $0.download === download }) else { return }
        
        DispatchQueue.main.async {
            item.state = .failed
            item.error = error.localizedDescription
            
            // 发送通知
            self.sendNotification(title: "下载失败", body: item.fileName)
        }
    }
    
    /// 取消下载
    func cancelDownload(_ item: DownloadItem) {
        item.download?.cancel { _ in
            DispatchQueue.main.async {
                item.state = .cancelled
            }
        }
    }
    
    /// 发送系统通知
    private func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}

