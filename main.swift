import SwiftUI
import AppKit
import QuickLookThumbnailing
import UniformTypeIdentifiers

// MARK: - Model

enum Source: String { case desktop = "桌面", downloads = "下载" }

struct ImageItem: Identifiable, Hashable {
    let id: URL
    var url: URL { id }
    let name: String
    let source: Source
    let date: Date
    let size: Int64
    let isScreenshot: Bool
}

enum SidebarFilter: Hashable { case all, desktop, downloads, screenshots }

enum Grouping: String, CaseIterable, Identifiable {
    case day = "按天", month = "按月", none = "不分组"
    var id: String { rawValue }
}

struct Section: Identifiable { let id: String; let title: String; let items: [ImageItem] }

@MainActor
final class Store: ObservableObject {
    @Published var items: [ImageItem] = []
    @Published var loading = false
    @Published var recursive = false { didSet { scan() } }
    @Published var errorMessage: String?

    func scan() {
        loading = true
        let rec = recursive
        Task.detached(priority: .userInitiated) {
            let result = Store.collect(recursive: rec)
            await MainActor.run { self.items = result; self.loading = false }
        }
    }

    nonisolated static func collect(recursive: Bool) -> [ImageItem] {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        let dirs: [(URL, Source)] = [(home.appendingPathComponent("Desktop"), .desktop),
                                     (home.appendingPathComponent("Downloads"), .downloads)]
        let keys: [URLResourceKey] = [.contentTypeKey, .creationDateKey, .contentModificationDateKey,
                                      .fileSizeKey, .isRegularFileKey]
        var out: [ImageItem] = []
        for (dir, src) in dirs {
            var urls: [URL] = []
            if recursive {
                if let en = fm.enumerator(at: dir, includingPropertiesForKeys: keys,
                                          options: [.skipsHiddenFiles, .skipsPackageDescendants]) {
                    for case let u as URL in en { urls.append(u) }
                }
            } else {
                urls = (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: keys,
                                                    options: [.skipsHiddenFiles])) ?? []
            }
            for u in urls {
                guard let v = try? u.resourceValues(forKeys: Set(keys)),
                      v.isRegularFile == true,
                      let t = v.contentType, t.conforms(to: .image) else { continue }
                let name = u.lastPathComponent
                out.append(ImageItem(id: u, name: name, source: src,
                                     date: v.creationDate ?? v.contentModificationDate ?? .distantPast,
                                     size: Int64(v.fileSize ?? 0),
                                     isScreenshot: isScreenshot(u, name: name)))
            }
        }
        return out.sorted { $0.date > $1.date }
    }

    nonisolated static func isScreenshot(_ url: URL, name: String) -> Bool {
        let prefixes = ["截屏", "屏幕快照", "Screenshot", "Screen Shot", "CleanShot", "截图"]
        if prefixes.contains(where: { name.hasPrefix($0) }) { return true }
        return getxattr(url.path, "com.apple.metadata:kMDItemIsScreenCapture", nil, 0, 0, 0) > 0
    }

    func trash(_ urls: Set<URL>) {
        guard !urls.isEmpty else { return }
        // Optimistically hide; restore any that fail.
        let backup = items
        items.removeAll { urls.contains($0.url) }
        NSWorkspace.shared.recycle(Array(urls)) { done, error in
            let ok = Set(done.keys)
            let failed = urls.subtracting(ok)
            Task { @MainActor in
                guard !failed.isEmpty else { return }
                // Fallback: ask Finder (handles iCloud Drive files)
                let stillFailed = failed.filter { !Store.finderTrash($0) }
                if !stillFailed.isEmpty {
                    let restore = Set(stillFailed)
                    self.items = backup.filter { restore.contains($0.url) || self.items.contains($0) }
                    self.errorMessage = "无法删除 \(stillFailed.count) 个文件：\(error?.localizedDescription ?? "未知错误")\n\n如果是权限问题，请到 系统设置 → 隐私与安全性 → 完全磁盘访问权限 中添加「图片清理」。"
                }
            }
        }
    }

    static func finderTrash(_ url: URL) -> Bool {
        let path = url.path.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        let src = "tell application \"Finder\" to delete (POSIX file \"\(path)\" as alias)"
        var err: NSDictionary?
        NSAppleScript(source: src)?.executeAndReturnError(&err)
        return err == nil
    }

    func count(_ f: SidebarFilter) -> Int { filtered(f).count }

    func filtered(_ f: SidebarFilter) -> [ImageItem] {
        switch f {
        case .all: return items
        case .desktop: return items.filter { $0.source == .desktop }
        case .downloads: return items.filter { $0.source == .downloads }
        case .screenshots: return items.filter { $0.isScreenshot }
        }
    }
}

// MARK: - Formatting

enum Fmt {
    static let cal = Calendar.current
    static func size(_ b: Int64) -> String { ByteCountFormatter.string(fromByteCount: b, countStyle: .file) }
    static func df(_ f: String) -> DateFormatter {
        let d = DateFormatter(); d.locale = Locale(identifier: "zh_CN"); d.dateFormat = f; return d
    }
    static let dayThisYear = df("M月d日 EEEE")
    static let dayOther = df("yyyy年M月d日 EEEE")
    static let month = df("yyyy年M月")
    static let full = df("yyyy-MM-dd HH:mm")

    static func dayTitle(_ d: Date) -> String {
        if cal.isDateInToday(d) { return "今天" }
        if cal.isDateInYesterday(d) { return "昨天" }
        return cal.isDate(d, equalTo: Date(), toGranularity: .year) ? dayThisYear.string(from: d) : dayOther.string(from: d)
    }

    static func sections(_ items: [ImageItem], _ g: Grouping) -> [Section] {
        switch g {
        case .none: return [Section(id: "all", title: "全部图片", items: items)]
        case .day, .month:
            var order: [String] = []; var map: [String: [ImageItem]] = [:]; var titles: [String: String] = [:]
            for it in items {
                let c = cal.dateComponents([.year, .month, .day], from: it.date)
                let key = g == .day ? "\(c.year!)-\(c.month!)-\(c.day!)" : "\(c.year!)-\(c.month!)"
                if map[key] == nil {
                    order.append(key)
                    titles[key] = g == .day ? dayTitle(it.date) : month.string(from: it.date)
                }
                map[key, default: []].append(it)
            }
            return order.map { Section(id: $0, title: titles[$0]!, items: map[$0]!) }
        }
    }
}

// MARK: - Thumbnails

final class ThumbCache {
    static let shared: NSCache<NSURL, NSImage> = { let c = NSCache<NSURL, NSImage>(); c.countLimit = 800; return c }()
    static func load(_ url: URL) async -> NSImage? {
        if let c = shared.object(forKey: url as NSURL) { return c }
        let req = QLThumbnailGenerator.Request(fileAt: url, size: CGSize(width: 220, height: 220),
                                               scale: 2, representationTypes: .thumbnail)
        guard let rep = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: req) else { return nil }
        let img = rep.nsImage
        shared.setObject(img, forKey: url as NSURL)
        return img
    }
}

struct Thumb: View {
    let url: URL
    @State private var img: NSImage?
    var body: some View {
        ZStack {
            Rectangle().fill(Color.primary.opacity(0.05))
            if let img {
                Image(nsImage: img).resizable().scaledToFill().transition(.opacity)
            } else {
                Image(systemName: "photo").font(.title2).foregroundStyle(.tertiary)
            }
        }
        .task(id: url) {
            let i = await ThumbCache.load(url)
            withAnimation(.easeOut(duration: 0.2)) { img = i }
        }
    }
}

// MARK: - Cell

struct Cell: View {
    let item: ImageItem
    let selected: Bool
    let onToggle: () -> Void
    let onDelete: () -> Void
    let onOpen: () -> Void
    @State private var hover = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .overlay(Thumb(url: item.url))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(selected ? Color.accentColor : Color.primary.opacity(0.08),
                                      lineWidth: selected ? 3 : 1)
                )
                .overlay(alignment: .topLeading) {
                    if selected || hover {
                        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 18, weight: .semibold))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, selected ? Color.accentColor : Color.black.opacity(0.35))
                            .shadow(radius: 2)
                            .padding(8)
                    }
                }
                .overlay(alignment: .bottomLeading) {
                    Text(item.source.rawValue)
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(8)
                }
                .scaleEffect(hover ? 1.02 : 1)

            VStack(alignment: .leading, spacing: 1) {
                Text(item.name).font(.system(size: 11, weight: .medium)).lineLimit(1).truncationMode(.middle)
                Text("\(Fmt.full.string(from: item.date)) · \(Fmt.size(item.size))")
                    .font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
            }
            .padding(.horizontal, 2)
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { onOpen() }
        .onTapGesture(count: 1) { onToggle() }
        .overlay(alignment: .topTrailing) {
            if hover {
                Image(systemName: "trash")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color.red.opacity(0.92)))
                    .shadow(radius: 2)
                    .contentShape(Circle())
                    .onTapGesture { onDelete() }
                    .help("移到废纸篓")
                    .padding(8)
                    .transition(.opacity)
            }
        }
        .onHover { h in withAnimation(.easeOut(duration: 0.12)) { hover = h } }
        .contextMenu {
            Button("放大查看", action: onOpen)
            Button("用默认程序打开") { NSWorkspace.shared.open(item.url) }
            Button("在访达中显示") { NSWorkspace.shared.activateFileViewerSelecting([item.url]) }
            Divider()
            Button("移到废纸篓", role: .destructive, action: onDelete)
        }
    }
}

// MARK: - Preview

struct PreviewOverlay: View {
    let item: ImageItem
    let items: [ImageItem]
    let onSelect: (ImageItem) -> Void
    let onClose: () -> Void
    let onDelete: () -> Void
    @State private var image: NSImage?
    @State private var zoom: CGFloat = 1
    @State private var baseZoom: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var baseOffset: CGSize = .zero
    @FocusState private var focused: Bool

    var index: Int { items.firstIndex(of: item) ?? 0 }

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThickMaterial).ignoresSafeArea()
                .onTapGesture { onClose() }

            if let image {
                Image(nsImage: image)
                    .resizable().scaledToFit()
                    .shadow(color: .black.opacity(0.25), radius: 20, y: 8)
                    .scaleEffect(zoom).offset(offset)
                    .padding(EdgeInsets(top: 56, leading: 70, bottom: 64, trailing: 70))
                    .gesture(MagnificationGesture()
                        .onChanged { zoom = max(1, min(8, baseZoom * $0)) }
                        .onEnded { _ in baseZoom = zoom; if zoom == 1 { resetPan() } })
                    .simultaneousGesture(DragGesture()
                        .onChanged { v in guard zoom > 1 else { return }
                            offset = CGSize(width: baseOffset.width + v.translation.width,
                                            height: baseOffset.height + v.translation.height) }
                        .onEnded { _ in baseOffset = offset })
                    .onTapGesture(count: 2) { withAnimation(.spring(duration: 0.3)) { toggleZoom() } }
            } else {
                ProgressView()
            }

            // top bar
            VStack {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name).font(.system(size: 13, weight: .semibold)).lineLimit(1).truncationMode(.middle)
                        Text("\(item.source.rawValue) · \(Fmt.full.string(from: item.date)) · \(Fmt.size(item.size))\(dims)")
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(index + 1) / \(items.count)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    circleButton("arrow.up.forward.app", "用默认程序打开") { NSWorkspace.shared.open(item.url) }
                    circleButton("folder", "在访达中显示") { NSWorkspace.shared.activateFileViewerSelecting([item.url]) }
                    circleButton("trash", "移到废纸篓 (⌫)", tint: .red, action: onDelete)
                    circleButton("xmark", "关闭 (Esc)", action: onClose)
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
                Spacer()
                Text("双击放大 · 捏合缩放 · ← → 切换 · ⌫ 删除 · Esc 关闭")
                    .font(.caption2).foregroundStyle(.tertiary).padding(.bottom, 14)
            }

            // nav arrows
            HStack {
                navButton("chevron.left", enabled: index > 0) { step(-1) }
                Spacer()
                navButton("chevron.right", enabled: index < items.count - 1) { step(1) }
            }.padding(.horizontal, 14)
        }
        .focusable().focused($focused).focusEffectDisabled()
        .onAppear { focused = true }
        .onKeyPress(.escape) { onClose(); return .handled }
        .onKeyPress(.space) { onClose(); return .handled }
        .onKeyPress(.leftArrow) { step(-1); return .handled }
        .onKeyPress(.rightArrow) { step(1); return .handled }
        .onKeyPress(.delete) { onDelete(); return .handled }
        .onKeyPress(.deleteForward) { onDelete(); return .handled }
        .task(id: item.url) {
            zoom = 1; baseZoom = 1; resetPan()
            if let t = ThumbCache.shared.object(forKey: item.url as NSURL) { image = t }
            let url = item.url
            let full = await Task.detached { NSImage(contentsOf: url) }.value
            if let full { image = full }
        }
    }

    var dims: String {
        guard let rep = image?.representations.first, rep.pixelsWide > 0 else { return "" }
        return " · \(rep.pixelsWide)×\(rep.pixelsHigh)"
    }

    func step(_ d: Int) {
        let n = index + d
        guard items.indices.contains(n) else { return }
        onSelect(items[n])
    }
    func resetPan() { offset = .zero; baseOffset = .zero }
    func toggleZoom() {
        if zoom > 1 { zoom = 1; baseZoom = 1; resetPan() } else { zoom = 2.5; baseZoom = 2.5 }
    }

    func circleButton(_ icon: String, _ help: String, tint: Color = .primary, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 13, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(Circle().fill(Color.primary.opacity(0.07)))
        }.buttonStyle(.plain).help(help)
    }

    func navButton(_ icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 18, weight: .semibold))
                .frame(width: 40, height: 40)
                .background(Circle().fill(Color.primary.opacity(0.08)))
        }
        .buttonStyle(.plain).opacity(enabled ? 1 : 0.2).disabled(!enabled)
    }
}

// MARK: - Main View

struct ContentView: View {
    @StateObject private var store = Store()
    @State private var filter: SidebarFilter = .all
    @State private var grouping: Grouping = .day
    @State private var selection = Set<URL>()
    @State private var confirm = false
    @State private var thumbSize: Double = 150
    @State private var preview: ImageItem?

    var current: [ImageItem] { store.filtered(filter) }

    var body: some View {
        NavigationSplitView {
            List(selection: $filter) {
                SwiftUI.Section("位置") {
                    row("全部图片", "photo.on.rectangle.angled", .all)
                    row("桌面", "menubar.dock.rectangle", .desktop)
                    row("下载", "arrow.down.circle", .downloads)
                }
                SwiftUI.Section("类型") {
                    row("截图", "camera.viewfinder", .screenshots)
                }
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
            .safeAreaInset(edge: .bottom) {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("包含子文件夹", isOn: $store.recursive).toggleStyle(.switch).controlSize(.small)
                    HStack {
                        Image(systemName: "photo").font(.caption)
                        Slider(value: $thumbSize, in: 100...260).controlSize(.small)
                        Image(systemName: "photo").font(.body)
                    }.foregroundStyle(.secondary)
                }
                .padding(14)
            }
        } detail: {
            detail
                .overlay {
                    if let p = preview {
                        PreviewOverlay(item: p, items: current, onSelect: { preview = $0 },
                                       onClose: { withAnimation(.easeOut(duration: 0.15)) { preview = nil } },
                                       onDelete: { deleteInPreview(p) })
                            .transition(.opacity)
                    }
                }
        }
        .onAppear { store.scan() }
        .onChange(of: filter) { selection.removeAll() }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("分组", selection: $grouping) {
                    ForEach(Grouping.allCases) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.segmented).frame(width: 200)
            }
            ToolbarItemGroup(placement: .primaryAction) {
                Button { store.scan() } label: { Image(systemName: "arrow.clockwise") }.help("重新扫描")
                if !selection.isEmpty {
                    Button("取消选择") { selection.removeAll() }
                    Button(role: .destructive) {
                        withAnimation { store.trash(selection) }
                        selection.removeAll()
                    } label: {
                        Label("删除 \(selection.count) 张", systemImage: "trash")
                    }
                    .tint(.red)
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("全选") { selection = Set(current.map(\.url)) }.disabled(current.isEmpty)
                }
            }
        }
        .alert("删除失败", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
            Button("好") {}
        } message: { Text(store.errorMessage ?? "") }
        .confirmationDialog("将 \(selection.count) 张图片移到废纸篓？", isPresented: $confirm) {
            Button("移到废纸篓", role: .destructive) {
                withAnimation { store.trash(selection) }
                selection.removeAll()
            }
        } message: {
            Text("共 \(Fmt.size(store.items.filter { selection.contains($0.url) }.reduce(0) { $0 + $1.size }))，可在废纸篓中恢复。")
        }
    }

    func row(_ title: String, _ icon: String, _ f: SidebarFilter) -> some View {
        Label {
            HStack {
                Text(title)
                Spacer()
                Text("\(store.count(f))").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
        } icon: { Image(systemName: icon) }
        .tag(f)
    }

    @ViewBuilder var detail: some View {
        let items = current
        if store.loading && store.items.isEmpty {
            ProgressView("正在扫描…").frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if items.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "sparkles").font(.system(size: 44)).foregroundStyle(.tertiary)
                Text("这里很干净").font(.title3.weight(.medium))
                Text("没有找到图片").foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                header(items)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: thumbSize, maximum: thumbSize * 1.4), spacing: 16)],
                          spacing: 18, pinnedViews: [.sectionHeaders]) {
                    ForEach(Fmt.sections(items, grouping)) { sec in
                        SwiftUI.Section {
                            ForEach(sec.items) { it in
                                Cell(item: it, selected: selection.contains(it.url),
                                     onToggle: { toggle(it.url) },
                                     onDelete: { withAnimation(.spring(duration: 0.3)) { store.trash([it.url]); selection.remove(it.url) } },
                                     onOpen: { withAnimation(.easeOut(duration: 0.2)) { preview = it } })
                            }
                        } header: { sectionHeader(sec) }
                    }
                }
                .padding(.horizontal, 24).padding(.bottom, 24)
            }
        }
    }

    func header(_ items: [ImageItem]) -> some View {
        let total = items.reduce(Int64(0)) { $0 + $1.size }
        let shots = items.filter(\.isScreenshot).count
        return HStack(spacing: 14) {
            stat("\(items.count)", "张图片")
            stat(Fmt.size(total), "占用空间")
            stat("\(shots)", "张截图")
            Spacer()
        }
        .padding(.horizontal, 24).padding(.top, 20).padding(.bottom, 8)
    }

    func stat(_ v: String, _ l: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(v).font(.system(size: 22, weight: .semibold, design: .rounded)).monospacedDigit()
            Text(l).font(.caption).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .frame(minWidth: 120, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.primary.opacity(0.04)))
    }

    func sectionHeader(_ sec: Section) -> some View {
        let urls = Set(sec.items.map(\.url))
        let all = urls.isSubset(of: selection)
        return HStack(alignment: .firstTextBaseline) {
            Text(sec.title).font(.system(size: 15, weight: .semibold))
            Text("\(sec.items.count) 张 · \(Fmt.size(sec.items.reduce(0) { $0 + $1.size }))")
                .font(.caption).foregroundStyle(.secondary)
            Spacer()
            Button(all ? "取消" : "选择本组") {
                if all { selection.subtract(urls) } else { selection.formUnion(urls) }
            }
            .buttonStyle(.borderless).font(.caption)
        }
        .padding(.vertical, 8).padding(.horizontal, 4)
        .background(.bar)
    }

    func deleteInPreview(_ p: ImageItem) {
        let list = current
        let idx = list.firstIndex(of: p) ?? 0
        store.trash([p.url]); selection.remove(p.url)
        let rest = current
        withAnimation(.easeOut(duration: 0.15)) {
            preview = rest.isEmpty ? nil : rest[min(idx, rest.count - 1)]
        }
    }

    func toggle(_ u: URL) { if selection.contains(u) { selection.remove(u) } else { selection.insert(u) } }
}

@main
struct PicSweepApp: App {
    var body: some Scene {
        WindowGroup("图片清理") {
            ContentView().frame(minWidth: 820, minHeight: 540)
        }
        .windowToolbarStyle(.unified)
        .commands { CommandGroup(replacing: .newItem) {} }
    }
}
