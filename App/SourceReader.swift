import SwiftUI
import WebKit

struct Film: Identifiable, Codable, Hashable {
    var url: String; var title: String; var cover: String
    var id: String { url }
    init(_ d: [String: Any]) { url = d["url"] as? String ?? ""; title = d["title"] as? String ?? "未命名"; cover = d["cover"] as? String ?? "" }
}
struct Episode: Identifiable, Codable, Hashable {
    var url: String; var title: String; var group: String
    var id: String { url }
    init(_ d: [String: Any]) { url = d["url"] as? String ?? ""; title = d["title"] as? String ?? "正片"; group = d["groupId"] as? String ?? d["group"] as? String ?? "线路1" }
}
enum ReaderError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case let .message(s) = self { return s }; return nil }
}
@MainActor final class SourceReader: NSObject, ObservableObject, WKNavigationDelegate {
    static let home = "https://www.kkys16.com/"
    let web: WKWebView
    private var navigationFailure: String?
    private var cache: [String: [String: Any]] = [:]
    override init() {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        web = WKWebView(frame: CGRect(x: 0, y: 0, width: 900, height: 650), configuration: config)
        super.init()
        web.navigationDelegate = self
        web.customUserAgent = "Mozilla/5.0 (iPad; CPU OS 17_0 like Mac OS X) AppleWebKit/605.1.15 Version/17.0 Mobile/15E148 Safari/604.1"
    }
    func script(_ name: String) throws -> String {
        guard let url = Bundle.main.url(forResource: name, withExtension: "js") else { throw ReaderError.message("缺少页面脚本") }
        return try String(contentsOf: url, encoding: .utf8)
    }
    func evaluate(_ js: String) async throws -> [String: Any] {
        let value = try await web.evaluateJavaScript(js)
        try Task.checkCancellation()
        guard let s = value as? String, let data = s.data(using: .utf8), let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        return obj
    }
    func navigate(_ address: String) throws {
        guard let u = URL(string: address), ["kkys16.com", "www.kkys16.com"].contains(u.host ?? ""), ["https", "http"].contains(u.scheme ?? "") else { throw ReaderError.message("仅支持当前影视站内链接") }
        navigationFailure = nil; web.stopLoading(); web.load(URLRequest(url: u))
    }
    func wait() async throws { try await Task.sleep(nanoseconds: 1_000_000_000); try Task.checkCancellation(); if let e = navigationFailure { throw ReaderError.message(e) } }
    func read(_ url: String, refresh: Bool = false) async throws -> [String: Any] {
        if !refresh, let data = cache[url] { return data }
        try navigate(url)
        let js = try script("extract")
        for _ in 0..<40 {
            try await wait()
            if web.isLoading { continue }
            if let data = try? await evaluate(js), !(data["items"] as? [Any] ?? []).isEmpty || !(data["episodes"] as? [Any] ?? []).isEmpty {
                cache[url] = data; return data
            }
        }
        throw ReaderError.message("页面读取超时，请重试。网站验证页面或改版可能影响读取。")
    }
    func search(_ query: String) async throws -> [String: Any] {
        try navigate(Self.home)
        let json = String(data: try JSONSerialization.data(withJSONObject: [query]), encoding: .utf8)!
        let js = try script("search").replacingOccurrences(of: "__QUERY_JSON__", with: json)
        var submitted = false
        for _ in 0..<40 {
            try await wait()
            if web.isLoading { continue }
            if !submitted { let result = try? await evaluate(js); submitted = result?["state"] as? String == "submitted"; continue }
            if let result = try? await evaluate(script("extract")), !(result["items"] as? [Any] ?? []).isEmpty { return result }
        }
        throw ReaderError.message("搜索失败，请稍后重试")
    }
    func media(_ address: String) async throws -> URL {
        try navigate(address)
        let js = try script("media")
        for _ in 0..<45 {
            try await wait()
            if let data = try? await evaluate(js), let urls = data["urls"] as? [String], let candidate = urls.first(where: { !$0.lowercased().contains(".mpd") }), let u = URL(string: candidate) {
                web.stopLoading(); web.loadHTMLString("", baseURL: nil); return u
            }
        }
        throw ReaderError.message("未取得可播放地址。当前支持系统可解码的 HLS/MP4，请尝试另一线路。")
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { if (error as NSError).code != NSURLErrorCancelled { navigationFailure = error.localizedDescription } }
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        let u = navigationAction.request.url
        let http = ["https", "http", "about"].contains(u?.scheme ?? "")
        let mainAllowed = navigationAction.targetFrame?.isMainFrame != true || ["kkys16.com", "www.kkys16.com"].contains(u?.host ?? "") || u?.scheme == "about"
        decisionHandler(http && mainAllowed ? .allow : .cancel)
    }
}
@MainActor struct ReaderHost: UIViewRepresentable {
    let reader: SourceReader
    func makeUIView(context: Context) -> WKWebView { reader.web }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
