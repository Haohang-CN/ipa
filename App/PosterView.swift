import SwiftUI
import WebKit

@MainActor final class PosterStore: ObservableObject {
    static let shared = PosterStore()
    private let memory = NSCache<NSString, UIImage>()
    private var tasks: [String: Task<UIImage?, Never>] = [:]
    private init() { memory.countLimit = 120 }

    func image(for film: Film, using reader: SourceReader, refresh: Bool = false) async -> UIImage? {
        let key = film.url as NSString
        if !refresh, let cached = memory.object(forKey: key) { return cached }
        if let current = tasks[film.url] { return await current.value }
        let task = Task<UIImage?, Never> { [weak self] in
            guard let self else { return nil }
            let saved = UserDefaults.standard.string(forKey: "poster:" + film.url) ?? ""
            var candidates = [film.cover, saved].filter { !$0.isEmpty }
            for address in candidates {
                if let image = await self.fetch(address, referer: film.url, reader: reader) {
                    self.memory.setObject(image, forKey: key)
                    UserDefaults.standard.set(address, forKey: "poster:" + film.url)
                    return image
                }
            }
            // 列表中的懒加载封面可能没有有效地址：进入详情页再读一次。
            if let data = try? await reader.read(film.url), let address = data["cover"] as? String,
               !address.isEmpty, !candidates.contains(address) {
                candidates.append(address)
                if let image = await self.fetch(address, referer: film.url, reader: reader) {
                    self.memory.setObject(image, forKey: key)
                    UserDefaults.standard.set(address, forKey: "poster:" + film.url)
                    return image
                }
            }
            return nil
        }
        tasks[film.url] = task
        let result = await task.value
        tasks[film.url] = nil
        return result
    }

    private func fetch(_ address: String, referer: String, reader: SourceReader) async -> UIImage? {
        if address.hasPrefix("data:image/"), let comma = address.firstIndex(of: ","),
           let data = Data(base64Encoded: String(address[address.index(after: comma)...])) {
            return UIImage(data: data)
        }
        guard let url = URL(string: address), ["https", "http"].contains(url.scheme ?? "") else { return nil }
        let cookies = await reader.web.configuration.websiteDataStore.httpCookieStore.allCookies()
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.setValue(reader.web.customUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("image/avif,image/webp,image/png,image/jpeg,image/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue(referer, forHTTPHeaderField: "Referer")
        let matching = cookies.filter { url.host?.hasSuffix($0.domain.trimmingCharacters(in: CharacterSet(charactersIn: "."))) == true }
        for (field, value) in HTTPCookie.requestHeaderFields(with: matching) { request.setValue(value, forHTTPHeaderField: field) }
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200, data.count < 8_000_000 else { return nil }
        return UIImage(data: data)
    }
}

@MainActor struct PosterView: View {
    let film: Film
    let reader: SourceReader
    @State private var image: UIImage?
    @State private var failed = false
    @State private var retry = 0
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.08))
                if let image {
                    Image(uiImage: image).resizable().scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height).clipped()
                } else if failed {
                    Button { retry += 1 } label: {
                        VStack(spacing: 5) { Image(systemName: "arrow.clockwise"); Text("封面重试").font(.caption) }
                            .foregroundStyle(.secondary)
                    }
                } else { ProgressView() }
            }.clipShape(RoundedRectangle(cornerRadius: 12))
        }.task(id: film.url + ":" + String(retry)) {
            image = await PosterStore.shared.image(for: film, using: reader, refresh: retry > 0)
            failed = image == nil
        }
    }
}
