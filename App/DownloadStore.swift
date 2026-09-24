import Foundation
import AVFoundation

struct SavedVideo: Codable, Identifiable {
    var id: String
    var title: String
    var file: String
}

@MainActor final class DownloadStore: NSObject, ObservableObject, URLSessionDownloadDelegate, AVAssetDownloadDelegate {
    @Published var items: [SavedVideo] = []
    @Published var state = ""
    @Published var progress = 0.0
    @Published var downloading = false
    private var activeID: String?
    private var activeTitle = ""
    private var session: AVAssetDownloadURLSession?
    private var httpSession: URLSession?

    override init() {
        super.init()
        if let data = UserDefaults.standard.data(forKey: "downloads"),
           let value = try? JSONDecoder().decode([SavedVideo].self, from: data) { items = value }
    }
    private func directory() throws -> URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Videos", isDirectory: true)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }
    func file(_ video: SavedVideo) -> URL? {
        guard let base = try? directory() else { return nil }
        let url = base.appendingPathComponent(video.file)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
    func start(url: URL, title: String, id: String) {
        guard !downloading else { state = "请等当前下载完成"; return }
        guard ["http", "https"].contains(url.scheme ?? "") else { state = "地址不可下载"; return }
        activeID = id; activeTitle = title; downloading = true; progress = 0; state = "开始下载：" + title
        if url.path.lowercased().hasSuffix(".m3u8") {
            let configuration = URLSessionConfiguration.background(withIdentifier: "com.qingying.ipad.hls." + UUID().uuidString)
            let newSession = AVAssetDownloadURLSession(configuration: configuration, assetDownloadDelegate: self, delegateQueue: .main)
            session = newSession
            let asset = AVURLAsset(url: url)
            guard let task = newSession.makeAssetDownloadTask(asset: asset, assetTitle: title, assetArtworkData: nil, options: nil) else {
                downloading = false; state = "无法建立 HLS 下载任务"; return
            }
            task.resume()
        } else if ["mp4", "m4v"].contains(url.pathExtension.lowercased()) {
            let configuration = URLSessionConfiguration.background(withIdentifier: "com.qingying.ipad.mp4." + UUID().uuidString)
            let newSession = URLSession(configuration: configuration, delegate: self, delegateQueue: .main)
            httpSession = newSession
            newSession.downloadTask(with: url).resume()
        } else { downloading = false; state = "当前格式暂不支持下载" }
    }
    private func complete(location: URL, ext: String) {
        do {
            let name = UUID().uuidString + "." + ext
            let destination = try directory().appendingPathComponent(name)
            try FileManager.default.moveItem(at: location, to: destination)
            items.removeAll { $0.id == activeID }
            items.insert(SavedVideo(id: activeID ?? name, title: activeTitle, file: name), at: 0)
            if let data = try? JSONEncoder().encode(items) { UserDefaults.standard.set(data, forKey: "downloads") }
            progress = 1; state = "已下载：" + activeTitle
        } catch { state = "保存失败：" + error.localizedDescription }
        downloading = false
    }
    func delete(_ video: SavedVideo) {
        if let url = file(video) { try? FileManager.default.removeItem(at: url) }
        items.removeAll { $0.id == video.id }
        if let data = try? JSONEncoder().encode(items) { UserDefaults.standard.set(data, forKey: "downloads") }
    }
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // 系统会在代理回调结束后移除临时文件，需要在回调内复制。
        let target = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp4")
        guard (try? FileManager.default.copyItem(at: location, to: target)) != nil else { return }
        Task { @MainActor in self.complete(location: target, ext: "mp4") }
    }
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        Task { @MainActor in self.progress = totalBytesExpectedToWrite > 0 ? Double(totalBytesWritten) / Double(totalBytesExpectedToWrite) : 0 }
    }
    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error { Task { @MainActor in self.downloading = false; self.state = "下载失败：" + error.localizedDescription } }
    }
    nonisolated func urlSession(_ session: URLSession, assetDownloadTask: AVAssetDownloadTask, didFinishDownloadingTo location: URL) {
        Task { @MainActor in self.complete(location: location, ext: "movpkg") }
    }
    nonisolated func urlSession(_ session: URLSession, assetDownloadTask: AVAssetDownloadTask, didLoad timeRange: CMTimeRange, totalTimeRangesLoaded loadedTimeRanges: [NSValue], timeRangeExpectedToLoad: CMTimeRange) {
        let expected = timeRangeExpectedToLoad.duration.seconds
        let loaded = loadedTimeRanges.reduce(0.0) { $0 + $1.timeRangeValue.duration.seconds }
        Task { @MainActor in self.progress = expected.isFinite && expected > 0 ? min(1, loaded / expected) : 0 }
    }
}
