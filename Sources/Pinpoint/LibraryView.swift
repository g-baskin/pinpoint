import AppKit
import SwiftUI
import PinpointCore

@MainActor
final class LibraryModel: ObservableObject {
    let store: LibraryStore
    @Published var all: [CaptureMeta] = []
    @Published var query = ""
    @Published var selection: [UUID] = []   // ordered: becomes the step order for guides
    @Published var status = ""
    @Published var busy = false
    private var observer: Any?
    let thumbs = NSCache<NSUUID, NSImage>()

    init(store: LibraryStore) {
        self.store = store
        reload()
        observer = NotificationCenter.default.addObserver(forName: .pinpointLibraryChanged, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.thumbs.removeAllObjects(); self?.reload() }
        }
    }

    var filtered: [CaptureMeta] { LibraryStore.search(all, query: query) }

    func reload() {
        let s = store
        Task.detached {
            let metas = s.loadAll()
            await MainActor.run { self.all = metas; self.selection.removeAll { id in !metas.contains { $0.id == id } } }
        }
    }

    func thumb(_ id: UUID) -> NSImage? {
        if let t = thumbs.object(forKey: id as NSUUID) { return t }
        guard let img = NSImage(contentsOf: store.thumbURL(id)) else { return nil }
        thumbs.setObject(img, forKey: id as NSUUID)
        return img
    }

    func toggle(_ id: UUID, extend: Bool) {
        if extend { if let i = selection.firstIndex(of: id) { selection.remove(at: i) } else { selection.append(id) } }
        else { selection = selection == [id] ? [] : [id] }
    }

    func copy(_ id: UUID) {
        guard let img = store.bestImage(id), let d = ImageFiles.encode(img) else { return }
        NSPasteboard.general.clearContents(); NSPasteboard.general.setData(d, forType: .png)
        status = "Copied."
    }

    func delete(_ ids: [UUID]) {
        var failed: [String] = []
        for id in ids {
            do { try store.delete(id) } catch { failed.append(error.localizedDescription) }
        }
        selection.removeAll { ids.contains($0) }
        let moved = ids.count - failed.count
        status = failed.isEmpty ? "Moved \(moved) to Trash."
            : "Moved \(moved) to Trash; \(failed.count) couldn't be moved: \(failed[0])"
        NotificationCenter.default.post(name: .pinpointLibraryChanged, object: nil)
    }

    /// AI name & tag for selected captures (or all un-named ones).
    func autoTag() {
        let targets = selection.isEmpty ? all.filter { !$0.aiNamed }.map(\.id) : selection
        guard !targets.isEmpty else { status = "Everything is already named."; return }
        let client: LLMClient
        do { client = try AppSettings.shared.makeClient(fast: true) } catch { status = error.localizedDescription; return }
        busy = true
        Task {
            var done = 0
            var lastError: String?
            for id in targets {
                guard var m = store.meta(id), let img = store.original(id) else { continue }
                status = "Naming \(done + 1) of \(targets.count)…"
                do {
                    let r = try await Assistants(client: client).nameAndTags(image: img, ocrText: m.ocrText, app: m.sourceApp)
                    m.name = r.name; m.tags = r.tags; m.aiNamed = true
                    try store.writeMeta(m); done += 1
                } catch { lastError = error.localizedDescription }
            }
            busy = false
            status = "Named \(done) of \(targets.count)." + (lastError.map { " Last error: \($0)" } ?? "")
            reload()
        }
    }

    func makeGuide() {
        let ids = selection
        guard !ids.isEmpty else { status = "Select captures in step order first (⌘-click)."; return }
        let steps: [GuideStep] = ids.compactMap { id in
            guard let m = store.meta(id), let img = store.bestImage(id) else { return nil }
            return GuideStep(image: img, name: m.name, ocrText: m.ocrText)
        }
        let title = steps.first.map { "How to: \($0.name)" } ?? "Guide"
        let parent = store.root.appendingPathComponent("Guides", isDirectory: true)
        busy = true
        status = "Writing guide…"
        Task {
            var md: String
            if AppSettings.shared.isAIConfigured, let client = try? AppSettings.shared.makeClient() {
                do { md = try await Assistants(client: client).writeGuide(steps: steps, title: nil) }
                catch { status = "AI failed (\(error.localizedDescription)); made a basic guide."; md = GuideBuilder.fallbackMarkdown(steps: steps, title: title) }
            } else {
                md = GuideBuilder.fallbackMarkdown(steps: steps, title: title)
            }
            let guideTitle = md.split(separator: "\n").first { $0.hasPrefix("# ") }.map { String($0.dropFirst(2)) } ?? title
            do {
                let folder = try GuideBuilder.write(markdown: md, steps: steps, title: guideTitle, to: parent)
                NSWorkspace.shared.open(folder.appendingPathComponent("guide.html"))
                NSWorkspace.shared.activateFileViewerSelecting([folder.appendingPathComponent("guide.md")])
                status = "Guide saved: \(folder.lastPathComponent)"
            } catch { status = "Couldn't write guide: \(error.localizedDescription)" }
            busy = false
        }
    }
}

struct LibraryView: View {
    @ObservedObject var model: LibraryModel
    let open: (UUID) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search names, tags and text inside screenshots", text: $model.query).textFieldStyle(.plain)
                Spacer()
                if model.busy { ProgressView().controlSize(.small) }
                Button { model.autoTag() } label: { Label("Auto-name", systemImage: "sparkles") }
                    .help("AI names & tags the selected captures (or all un-named ones)")
                Button { model.makeGuide() } label: { Label("Make Guide", systemImage: "list.number") }
                    .help("Turn the selected captures, in the order you picked them, into a step-by-step guide")
                    .disabled(model.selection.isEmpty)
                Button { NSWorkspace.shared.open(model.store.root) } label: { Image(systemName: "folder") }.help("Open library folder")
            }
            .padding(10)
            Divider()
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 14)], spacing: 14) {
                    ForEach(model.filtered) { m in
                        card(m)
                    }
                }
                .padding(14)
            }
            .overlay {
                if model.filtered.isEmpty {
                    Text(model.all.isEmpty ? "No captures yet. Press ⌃⇧1 to grab part of the screen." : "Nothing matches “\(model.query)”.")
                        .foregroundStyle(.secondary)
                }
            }
            Divider()
            HStack {
                Text(model.status.isEmpty ? "\(model.filtered.count) captures • \(model.selection.count) selected" : model.status)
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                Spacer()
            }.padding(.horizontal, 10).padding(.vertical, 5)
        }
    }

    private func card(_ m: CaptureMeta) -> some View {
        let order = model.selection.firstIndex(of: m.id)
        return VStack(alignment: .leading, spacing: 4) {
            ZStack(alignment: .topTrailing) {
                Group {
                    if let img = model.thumb(m.id) { Image(nsImage: img).resizable().aspectRatio(contentMode: .fit) }
                    else { Color.gray.opacity(0.2) }
                }
                .frame(height: 120).frame(maxWidth: .infinity)
                .background(Color.black.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                if let o = order {
                    Text("\(o + 1)").font(.caption.bold()).foregroundStyle(.white)
                        .frame(width: 22, height: 22).background(Circle().fill(Color.accentColor)).padding(5)
                }
            }
            Text(m.name).font(.callout.weight(.medium)).lineLimit(1)
            Text(([m.created.formatted(date: .abbreviated, time: .shortened)] + m.tags.prefix(3).map { "#" + $0 }).joined(separator: "  "))
                .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
        }
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 10).stroke(order != nil ? Color.accentColor : .clear, lineWidth: 2))
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { open(m.id) }
        .onTapGesture { model.toggle(m.id, extend: NSEvent.modifierFlags.contains(.command) || NSEvent.modifierFlags.contains(.shift)) }
        .contextMenu {
            Button("Open in Editor") { open(m.id) }
            Button("Copy Image") { model.copy(m.id) }
            Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([model.store.folder(m.id)]) }
            Divider()
            Button("Move to Trash", role: .destructive) { model.delete(model.selection.contains(m.id) ? model.selection : [m.id]) }
        }
        .onDrag {
            NSItemProvider(contentsOf: FileManager.default.fileExists(atPath: model.store.renderedURL(m.id).path)
                           ? model.store.renderedURL(m.id) : model.store.originalURL(m.id)) ?? NSItemProvider()
        }
    }
}
