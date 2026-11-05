import SwiftUI
import AVKit

struct Video: Codable, Identifiable, Hashable {
    let cid: String
    let name: String
    var summary: String?
    var photo_url: String?
    var cover_url: String?
    var id: String { cid }
}
struct CatalogResponse: Decodable { let resultList: [Video]; let total: Int? }
struct DetailResponse: Decodable { struct Detail: Decodable { let content: String? }; let vo: Detail }

enum Source {
    static let host = "https://baike.azpdl.net/"
    static let categories = ["1.10.1", "1.10.6", "1.10.8", "1.10.2", "1.10.4", "1.10.5"]
    static func include(_ item: Video, category: String) -> Bool {
        let value = item.name + " " + (item.summary ?? "")
        return !value.contains("俊总") && (["1.10.1", "1.10.6"].contains(category) || value.contains("于东来") || value.contains("东来哥"))
    }
    static func fetch<T: Decodable>(_ url: URL) async throws -> T {
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.setValue("Mozilla/5.0 Android", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(T.self, from: data)
    }
    static func catalog() async -> ([Video], Bool) {
        var result: [Video] = [], seen = Set<String>(), partial = false
        for category in categories {
            do {
                var page = 1
                while true {
                    let url = URL(string: host + "selectWikiPageForCategory_WikiPageAction.pdl!?category_id=\(category)&limit=100&page=\(page)&start=\((page-1)*100)&query_json=%5B%5D")!
                    let response: CatalogResponse = try await fetch(url)
                    for item in response.resultList where !item.cid.isEmpty && include(item, category: category) && seen.insert(item.cid).inserted { result.append(item) }
                    if response.resultList.isEmpty || page * 100 >= (response.total ?? response.resultList.count) { break }
                    page += 1
                }
            } catch { partial = true }
        }
        return (result, partial)
    }
    static func videoURL(id: String) async throws -> URL {
        var components = URLComponents(string: host + "selectWikiPageById_WikiPageAction.pdl!")!
        components.queryItems = [URLQueryItem(name: "cid", value: id)]
        let detail: DetailResponse = try await fetch(components.url!)
        let html = detail.vo.content ?? ""
        let regex = try NSRegularExpression(pattern: "(?:data-url|src)=[\\\"'](https?://[^\\\"']+\\.m3u8[^\\\"']*)[\\\"']", options: .caseInsensitive)
        guard let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)), let range = Range(match.range(at: 1), in: html) else { throw URLError(.cannotParseResponse) }
        var value = String(html[range]).replacingOccurrences(of: "&amp;", with: "&")
        if value.lowercased().hasPrefix("http://") { value = "https://" + value.dropFirst(7) }
        guard let url = URL(string: value) else { throw URLError(.badURL) }
        return url
    }
}

@MainActor final class Library: ObservableObject {
    @Published var videos: [Video] = []
    @Published var current: Video?
    @Published var message = "正在加载目录…"
    @Published var loading = false
    @Published var speed: Float = UserDefaults.standard.float(forKey: "speed") == 0 ? 1 : UserDefaults.standard.float(forKey: "speed")
    @Published var history: [String] = UserDefaults.standard.stringArray(forKey: "history") ?? []
    let player = AVPlayer()
    private var observer: Any?
    private var endObserver: NSObjectProtocol?
    private var failureObserver: NSObjectProtocol?
    private var generation = 0
    private var completed = false
    private var statusObservation: NSKeyValueObservation?
    private let defaults = UserDefaults.standard
    init() {
        player.defaultRate = speed
        if let data = defaults.data(forKey: "catalog"), let cached = try? JSONDecoder().decode([Video].self, from: data) { videos = cached }
        observer = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 5, preferredTimescale: 600), queue: .main) { [weak self] _ in Task { @MainActor in self?.savePosition() } }
        endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: nil, queue: .main) { [weak self] notification in Task { @MainActor in guard let self, notification.object as? AVPlayerItem === self.player.currentItem, let id = self.current?.id else { return }; self.completed = true; self.defaults.set(0, forKey: "position_" + id); self.message = "播放结束" } }
        failureObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemFailedToPlayToEndTime, object: nil, queue: .main) { [weak self] notification in Task { @MainActor in guard let self, notification.object as? AVPlayerItem === self.player.currentItem else { return }; self.message = "播放失败，请重试" } }
    }
    func load() async {
        loading = true
        let (result, partial) = await Source.catalog()
        loading = false
        if !result.isEmpty {
            videos = result
            if !partial, let data = try? JSONEncoder().encode(result) { defaults.set(data, forKey: "catalog") }
            message = partial ? "部分目录加载失败，点击刷新重试" : "选择视频开始观看"
            if current == nil, let id = defaults.string(forKey: "last"), let item = videos.first(where: { $0.id == id }) { play(item) }
        } else { message = videos.isEmpty ? "目录加载失败，请检查网络后重试" : "目录更新失败，正在显示缓存" }
    }
    func play(_ video: Video) {
        savePosition(); generation += 1; let token = generation
        player.pause(); player.replaceCurrentItem(with: nil); completed = false; statusObservation = nil
        current = video; message = "正在加载视频…"
        history.removeAll { $0 == video.id }; history.insert(video.id, at: 0)
        defaults.set(history, forKey: "history"); defaults.set(video.id, forKey: "last")
        Task {
            do {
                let url = try await Source.videoURL(id: video.id)
                guard token == generation else { return }
                let item = AVPlayerItem(url: url); player.replaceCurrentItem(with: item)
                statusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
                    guard item.status == .failed else { return }
                    Task { @MainActor in if let self, token == self.generation { self.message = "播放失败，请重试" } }
                }
                let saved = defaults.double(forKey: "position_" + video.id)
                if saved > 0 { await player.seek(to: CMTime(seconds: saved, preferredTimescale: 600)) }
                guard token == generation else { return }
                player.playImmediately(atRate: speed); message = ""
            } catch { if token == generation { message = "视频加载失败，请重试" } }
        }
    }
    func savePosition() {
        guard !completed, let id = current?.id, player.currentItem != nil else { return }
        let seconds = player.currentTime().seconds
        let duration = player.currentItem?.duration.seconds ?? .nan
        if seconds.isFinite && seconds >= 0 {
            let position = duration.isFinite && duration > 0 && seconds >= max(0, duration - 2) ? 0 : seconds
            defaults.set(position, forKey: "position_" + id)
        }
    }
    func changeSpeed(_ value: Float) { speed = value; defaults.set(value, forKey: "speed"); player.defaultRate = value; if player.rate != 0 { player.rate = value } }
    func move(_ delta: Int) { guard let current, let index = videos.firstIndex(of: current), !videos.isEmpty else { return }; play(videos[(index + delta + videos.count) % videos.count]) }
    func seek(_ delta: Double) { let time = player.currentTime().seconds; guard time.isFinite else { return }; player.seek(to: CMTime(seconds: max(0, time + delta), preferredTimescale: 600)) }
}

struct NativePlayer: NSViewRepresentable {
    let player: AVPlayer
    func makeNSView(context: Context) -> AVPlayerView { let view = AVPlayerView(); view.player = player; view.controlsStyle = .floating; return view }
    func updateNSView(_ view: AVPlayerView, context: Context) { view.player = player }
}

private enum Theme {
    static let background = Color(red: 0.055, green: 0.09, blue: 0.075)
    static let panel = Color(red: 0.085, green: 0.13, blue: 0.105)
    static let raised = Color(red: 0.14, green: 0.21, blue: 0.17)
    static let accent = Color(red: 0.66, green: 0.87, blue: 0.74)
    static let muted = Color(red: 0.65, green: 0.75, blue: 0.69)
}

struct Cover: View {
    let video: Video
    var url: URL? {
        guard let value = [video.cover_url, video.photo_url].compactMap({ $0 }).first(where: { !$0.isEmpty }) else { return nil }
        return URL(string: value.hasPrefix("/") ? Source.host + value.dropFirst() : value)
    }
    var body: some View {
        ZStack {
            Theme.raised
            Image(systemName: "play.fill").foregroundStyle(Theme.accent.opacity(0.7))
            AsyncImage(url: url) { image in image.resizable().aspectRatio(contentMode: .fill) } placeholder: { Color.clear }
        }.frame(width: 86, height: 50).clipped().cornerRadius(7)
    }
}

struct ContentView: View {
    @StateObject var library = Library()
    @State private var search = ""
    @State private var historyOnly = false
    @State private var showSpeeds = false
    var filtered: [Video] {
        let items = historyOnly ? library.history.compactMap { id in library.videos.first { $0.id == id } } : library.videos
        return search.isEmpty ? items : items.filter { $0.name.localizedCaseInsensitiveContains(search) }
    }
    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "play.circle.fill").font(.system(size: 28)).foregroundStyle(Theme.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("东来讲堂").font(.system(size: 19, weight: .bold))
                        Text("胖东来百科 · 精选视频").font(.caption).foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    Button { Task { await library.load() } } label: { Image(systemName: "arrow.clockwise").font(.system(size: 14, weight: .semibold)) }
                        .buttonStyle(.plain).foregroundStyle(Theme.muted).help("刷新目录").disabled(library.loading)
                }.padding(.horizontal, 18).padding(.top, 22).padding(.bottom, 20)
                HStack(spacing: 4) {
                    tab("全部视频", icon: "square.grid.2x2", selected: !historyOnly) { historyOnly = false }
                    tab("最近观看", icon: "clock.arrow.circlepath", selected: historyOnly) { historyOnly = true }
                }.padding(4).background(Theme.raised.opacity(0.8), in: RoundedRectangle(cornerRadius: 11)).padding(.horizontal, 16)
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(Theme.muted)
                    TextField("搜索视频", text: $search).textFieldStyle(.plain)
                }.padding(10).background(Theme.raised.opacity(0.7), in: RoundedRectangle(cornerRadius: 10)).padding(16)
                HStack { Text(historyOnly ? "观看记录" : "视频目录").font(.system(size: 12, weight: .semibold)); Spacer(); Text("\(filtered.count)").font(.caption) }
                    .foregroundStyle(Theme.muted).padding(.horizontal, 19).padding(.bottom, 8)
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(filtered) { video in
                            Button { library.play(video) } label: {
                                HStack(spacing: 11) {
                                    Cover(video: video)
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(video.name).font(.system(size: 13, weight: .medium)).lineLimit(2).multilineTextAlignment(.leading)
                                        if historyOnly { Text("继续观看 · \(format(UserDefaults.standard.double(forKey: "position_" + video.id)))").font(.caption2).foregroundStyle(Theme.accent) }
                                    }
                                    Spacer(minLength: 0)
                                }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
                                    .background(library.current?.id == video.id ? Theme.raised : Color.clear, in: RoundedRectangle(cornerRadius: 10))
                            }.buttonStyle(.plain)
                        }
                        if filtered.isEmpty { Text(library.loading ? "正在加载…" : "没有找到视频").font(.callout).foregroundStyle(Theme.muted).padding(.top, 45) }
                    }.padding(.horizontal, 10)
                }
                Text("胖东来百科 · \(library.videos.count) 个视频").font(.caption).foregroundStyle(Theme.muted).padding(18)
            }.background(Theme.panel).navigationSplitViewColumnWidth(min: 280, ideal: 330)
        } detail: {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("东来讲堂").font(.system(size: 14, weight: .semibold))
                    Spacer()
                    if let current = library.current, let index = library.videos.firstIndex(of: current) { Text("\(index + 1) / \(library.videos.count)").font(.caption).foregroundStyle(Theme.muted) }
                }.padding(.horizontal, 24).padding(.vertical, 14).background(Theme.background)
                ZStack {
                    Color.black
                    NativePlayer(player: library.player)
                    if library.current == nil {
                        VStack(spacing: 12) { Image(systemName: "play.circle").font(.system(size: 52)); Text("选择一个视频，开始观看").font(.callout) }.foregroundStyle(Theme.muted).allowsHitTesting(false)
                    }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
                VStack(alignment: .leading, spacing: 14) {
                    Text("胖东来百科 · 东来讲堂").font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.accent)
                    Text(library.current?.name ?? "选择一个视频").font(.system(size: 19, weight: .bold)).lineLimit(2).textSelection(.enabled)
                    if !library.message.isEmpty { HStack { Text(library.message).font(.caption).foregroundStyle(Theme.muted); if library.current != nil && library.message.contains("失败") { Button("重试") { if let video = library.current { library.play(video) } }.foregroundStyle(Theme.accent) } } }
                    HStack(spacing: 8) {
                        control("上一条", icon: "backward.end.fill") { library.move(-1) }
                        control("15 秒", icon: "gobackward.15") { library.seek(-15) }
                        control("15 秒", icon: "goforward.15") { library.seek(15) }
                        control("下一条", icon: "forward.end.fill") { library.move(1) }
                        Spacer(minLength: 4)
                        Button { showSpeeds.toggle() } label: {
                            HStack(spacing: 6) { Image(systemName: "speedometer"); Text("\(library.speed, specifier: "%g")×"); Image(systemName: "chevron.up.chevron.down").font(.system(size: 9, weight: .bold)) }
                                .font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.accent).padding(.horizontal, 12).padding(.vertical, 9).background(Theme.raised, in: RoundedRectangle(cornerRadius: 10))
                        }.buttonStyle(.plain).help("设置播放倍速")
                        .popover(isPresented: $showSpeeds, arrowEdge: .bottom) {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("播放速度").font(.system(size: 19, weight: .bold))
                                    Spacer()
                                    Button("关闭") { showSpeeds = false }
                                        .buttonStyle(.plain).font(.system(size: 12, weight: .semibold))
                                        .padding(.horizontal, 12).padding(.vertical, 7)
                                        .background(Theme.raised, in: Capsule())
                                }
                                Text("选择适合你的观看节奏").font(.system(size: 13)).foregroundStyle(Theme.muted)
                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                    ForEach([Float(0.5), 0.75, 1, 1.25, 1.5, 2], id: \.self) { value in
                                        Button { library.changeSpeed(value); showSpeeds = false } label: {
                                            Text(value == 1 ? "1.0× 标准" : String(format: "%g×", value)).font(.system(size: 14, weight: .semibold)).frame(maxWidth: .infinity).frame(height: 48)
                                                .foregroundStyle(library.speed == value ? Theme.background : Color.white)
                                                .background(library.speed == value ? Theme.accent : Theme.raised, in: RoundedRectangle(cornerRadius: 12))
                                        }.buttonStyle(.plain).accessibilityLabel(Text(value == 1 ? "1.0 倍，标准" : "\(value) 倍"))
                                            .accessibilityValue(Text(library.speed == value ? "当前选中" : ""))
                                    }
                                }
                            }.padding(20).frame(width: 320).background(Theme.panel).preferredColorScheme(.dark)
                        }
                    }.disabled(library.current == nil)
                }.padding(.horizontal, 24).padding(.vertical, 18).background(Theme.background)
            }.background(Theme.background)
        }.frame(minWidth: 850, minHeight: 540).preferredColorScheme(.dark).tint(Theme.accent).task { await library.load() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in library.savePosition() }
    }
    func tab(_ title: String, icon: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) { Label(title, systemImage: icon).font(.system(size: 12, weight: .semibold)).frame(maxWidth: .infinity).padding(.vertical, 8).background(selected ? Theme.background.opacity(0.8) : Color.clear, in: RoundedRectangle(cornerRadius: 8)) }.buttonStyle(.plain).foregroundStyle(selected ? Theme.accent : Theme.muted)
    }
    func control(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Label(title, systemImage: icon).font(.system(size: 12, weight: .semibold)).padding(.horizontal, 11).padding(.vertical, 9).background(Theme.raised, in: RoundedRectangle(cornerRadius: 10)) }.buttonStyle(.plain)
    }
    func format(_ seconds: Double) -> String { let n = Int(max(0, seconds)); return "\(n / 60):" + String(format: "%02d", n % 60) }
}
@main struct DonglaiApp: App { var body: some Scene { WindowGroup { ContentView() }.windowStyle(.titleBar) } }
