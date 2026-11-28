import AppKit
import SwiftUI
import PinpointCore

/// The single Pinpoint window: editor + library + recent-captures tray. One capture is open at a time.
@MainActor
final class Workspace: ObservableObject {
    enum Mode { case editor, library }
    let store: LibraryStore
    let library: LibraryModel
    @Published var editor: EditorModel?
    @Published var mode: Mode = .editor
    @Published var sidebarTab = 0   // 0 = Properties, 1 = Assistant

    private var observer: Any?

    init(store: LibraryStore) {
        self.store = store
        self.library = LibraryModel(store: store)
        observer = NotificationCenter.default.addObserver(forName: .pinpointLibraryChanged, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.closeIfDeleted() }
        }
    }

    func open(meta: CaptureMeta, image: CGImage) {
        if editor?.meta.id == meta.id { mode = .editor; return }
        saveCurrent()
        editor = EditorModel(meta: meta, base: image, library: store)
        mode = .editor
    }

    func open(id: UUID) {
        guard let meta = store.meta(id), let img = store.original(id) else { return }
        open(meta: meta, image: img)
    }

    func saveCurrent() {
        guard let e = editor else { return }
        if e.dirty || e.meta.annotations != e.annotations || e.meta.crop != e.crop { e.save() }
        else {
            do { try store.writeMeta(e.meta) } catch { NSAlert(error: error).runModal() }
            NotificationCenter.default.post(name: .pinpointLibraryChanged, object: nil)
        }
    }

    /// Called when the open capture is deleted from the library.
    func closeIfDeleted() {
        if let e = editor, store.meta(e.meta.id) == nil { editor = nil }
    }
}

struct MainView: View {
    @ObservedObject var ws: Workspace
    @ObservedObject var settings = AppSettings.shared

    var body: some View {
        VStack(spacing: 0) {
            TopBar(ws: ws)
            Divider()
            switch ws.mode {
            case .library:
                LibraryView(model: ws.library) { id in ws.open(id: id) }
            case .editor:
                if let e = ws.editor {
                    EditorBody(ws: ws, model: e).id(e.meta.id)
                } else {
                    EmptyEditor(ws: ws)
                }
            }
        }
        .frame(minWidth: 900, minHeight: 560)
    }
}

/// Top toolbar: Capture, Library/Editor switch, tools, history, output.
struct TopBar: View {
    @ObservedObject var ws: Workspace

    var body: some View {
        HStack(spacing: 10) {
            Menu {
                Button("Area or Window  ⌃⇧1") { AppDelegate.shared?.capture(.area) }
                Button("Window  ⌃⇧2") { AppDelegate.shared?.capture(.window) }
                Button("Full Screen  ⌃⇧3") { AppDelegate.shared?.capture(.screen) }
                Button("All Screens  ⌃⇧4") { AppDelegate.shared?.capture(.allScreens) }
                Divider()
                Button("Open Image…") { AppDelegate.shared?.openImage() }
            } label: {
                Label("Capture", systemImage: "camera.viewfinder")
            } primaryAction: {
                AppDelegate.shared?.capture(.area)
            }
            .menuStyle(.borderedButton)
            .fixedSize()
            .help("Capture (⌃⇧1). Click the arrow for more options.")

            Picker("", selection: $ws.mode) {
                Label("Editor", systemImage: "pencil.and.outline").tag(Workspace.Mode.editor)
                Label("Library", systemImage: "square.grid.2x2").tag(Workspace.Mode.library)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()

            if ws.mode == .editor, let e = ws.editor {
                Divider().frame(height: 20)
                ToolStrip(model: e)
                Spacer(minLength: 8)
                EditorActions(model: e)
            } else {
                Spacer()
            }
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
    }
}

struct ToolStrip: View {
    @ObservedObject var model: EditorModel
    var body: some View {
        HStack(spacing: 1) {
            ForEach(Tool.allCases) { t in
                Button { model.tool = t } label: {
                    Image(systemName: t.symbol).font(.system(size: 14)).frame(width: 28, height: 24)
                }
                .buttonStyle(.borderless)
                .background(RoundedRectangle(cornerRadius: 6).fill(model.tool == t ? Color.accentColor.opacity(0.25) : .clear))
                .help(t.title)
            }
        }
    }
}

struct EditorActions: View {
    @ObservedObject var model: EditorModel
    var body: some View {
        HStack(spacing: 6) {
            Button { model.undo() } label: { Image(systemName: "arrow.uturn.backward") }.disabled(!model.canUndo).help("Undo (⌘Z)")
            Button { model.redo() } label: { Image(systemName: "arrow.uturn.forward") }.disabled(!model.canRedo).help("Redo (⇧⌘Z)")
            if model.crop != nil { Button("Reset Crop") { model.checkpoint(); model.crop = nil } }
            Button { model.copyImage() } label: { Label("Copy", systemImage: "doc.on.doc") }
                .help("Copy the image with all markup and a notes panel (⌘C) — paste it anywhere")
            Menu {
                Button("Copy for AI agent (notes + image path)") { model.copyHandoff() }
                Button("Copy image with notes panel  (⌘C)") { model.copyImage(includeNotesPanel: true) }
                Button("Copy image without notes panel") { model.copyImage(includeNotesPanel: false) }
                Button("Export handoff folder…") { model.exportHandoff() }
            } label: { Label("Handoff", systemImage: "paperplane") }
            .fixedSize()
            .help("Send this capture and its notes to a coding agent or a teammate")
            ShareButton(model: model)
            Button { model.export() } label: { Image(systemName: "square.and.arrow.down") }.help("Export… (⇧⌘E)")
            Button { model.save() } label: { Text(model.dirty ? "Save" : "Saved") }
                .keyboardShortcut("s", modifiers: .command).help("Save to Library (⌘S)")
        }
    }
}

/// macOS share sheet (Mail, Messages, AirDrop, Notes…) with the edited image.
struct ShareButton: NSViewRepresentable {
    let model: EditorModel
    func makeNSView(context: Context) -> NSButton {
        let b = NSButton(image: NSImage(systemSymbolName: "square.and.arrow.up", accessibilityDescription: "Share")!, target: context.coordinator, action: #selector(Coordinator.share(_:)))
        b.bezelStyle = .texturedRounded
        b.toolTip = "Share…"
        return b
    }
    func updateNSView(_ v: NSButton, context: Context) { context.coordinator.model = model }
    func makeCoordinator() -> Coordinator { Coordinator(model: model) }
    @MainActor final class Coordinator: NSObject {
        var model: EditorModel
        init(model: EditorModel) { self.model = model }
        @objc func share(_ sender: NSButton) {
            guard let img = model.flattened() else { return }
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(model.meta.name).png")
            do { try ImageFiles.write(img, to: url) } catch { model.fail("Share failed: \(error.localizedDescription)"); return }
            NSSharingServicePicker(items: [url]).show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
        }
    }
}

struct EditorBody: View {
    @ObservedObject var ws: Workspace
    @ObservedObject var model: EditorModel

    var body: some View {
        VStack(spacing: 0) {
            HSplitView {
                CanvasScrollView(model: model, zoom: model.zoom)
                    .frame(minWidth: 420, minHeight: 300)
                VStack(spacing: 0) {
                    Picker("", selection: $ws.sidebarTab) {
                        Text("Properties").tag(0)
                        Text("Assistant").tag(1)
                    }
                    .pickerStyle(.segmented).labelsHidden().padding(8)
                    Divider()
                    if ws.sidebarTab == 0 { PropertiesPanel(model: model) } else { AssistantPanel(model: model) }
                }
                .frame(minWidth: 270, idealWidth: 300, maxWidth: 440)
            }
            Divider()
            TrayView(ws: ws, library: ws.library, model: model)
        }
    }
}

struct EmptyEditor: View {
    @ObservedObject var ws: Workspace
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 14) {
                Image(systemName: "camera.viewfinder").font(.system(size: 54)).foregroundStyle(.secondary)
                Text("Press ⌃⇧1 to capture, or pick a recent capture below.").foregroundStyle(.secondary)
                Button("Capture Now") { AppDelegate.shared?.capture(.area) }.controlSize(.large)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .canvasBackground))
            Divider()
            TrayView(ws: ws, library: ws.library, model: nil)
        }
    }
}

// MARK: - Properties

struct PropertiesPanel: View {
    @ObservedObject var model: EditorModel

    /// The kind whose properties are shown: the selected item's, else the current tool's.
    private var kind: AnnotationKind? { model.selected?.kind ?? model.tool.kind }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let k = kind {
                    Text(model.selected != nil ? "Selected \(k.rawValue)" : k.rawValue.capitalized)
                        .font(.headline)
                    let styles = QuickStyle.presets(for: k)
                    if !styles.isEmpty {
                        section("Quick Styles") {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 58), spacing: 6)], spacing: 6) {
                                ForEach(Array(styles.enumerated()), id: \.offset) { _, s in
                                    Button { model.apply(s) } label: {
                                        Image(nsImage: s.preview(for: k)).resizable().frame(width: 58, height: 40)
                                            .clipShape(RoundedRectangle(cornerRadius: 5))
                                            .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.gray.opacity(0.35)))
                                    }.buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    if k != .blur && k != .redact {
                        section(k == .callout ? "Bubble / text colour" : "Colour") {
                            ColorRow(selected: model.color) { model.color = $0; model.styleChanged() }
                        }
                    }
                    if k.supportsFill {
                        section("Fill") {
                            HStack {
                                Button("None") { model.fillColor = nil; model.styleChanged() }
                                    .controlSize(.small).disabled(model.fillColor == nil)
                                ColorRow(selected: model.fillColor) { model.fillColor = $0.with(alpha: k == .callout ? 1 : 0.3); model.styleChanged() }
                            }
                        }
                    }
                    if [.arrow, .line, .rectangle, .ellipse, .callout].contains(k) {
                        section("Width  \(Int(model.lineWidth))") {
                            Slider(value: $model.lineWidth, in: 0...40) { editing in if !editing { model.styleChanged() } }
                        }
                    }
                    if [.text, .callout, .step].contains(k) {
                        section("Size  \(Int(model.fontSize))") {
                            Slider(value: $model.fontSize, in: 10...140) { editing in if !editing { model.styleChanged() } }
                        }
                    }
                    if ![.blur, .redact, .highlight].contains(k) {
                        Toggle("Shadow", isOn: Binding(get: { model.shadow }, set: { model.shadow = $0; model.styleChanged() }))
                    }
                } else if model.tool == .crop {
                    Text("Crop").font(.headline)
                    Text("Drag over the image to choose what to keep. Press Esc to finish.").font(.callout).foregroundStyle(.secondary)
                    if model.crop != nil { Button("Reset Crop") { model.checkpoint(); model.crop = nil } }
                } else {
                    Text("Select").font(.headline)
                    Text("Click an item to select it, drag to move it, and drag its round handles to resize it. Double-click text to edit it.")
                        .font(.callout).foregroundStyle(.secondary)
                }

                if let sel = model.selected, sel.kind != .note {
                    Button { model.promptNote(sel.id, autoListen: true) } label: {
                        Label(sel.hasNote ? "Edit note" : "Add voice note", systemImage: "mic.badge.plus")
                    }
                }
                NotesList(model: model)

                if model.selected != nil {
                    Divider()
                    HStack {
                        Button { model.bringToFront() } label: { Image(systemName: "square.3.layers.3d.top.filled") }.help("Bring to front")
                        Button { model.sendToBack() } label: { Image(systemName: "square.3.layers.3d.bottom.filled") }.help("Send to back")
                        Button { model.duplicateSelected() } label: { Image(systemName: "plus.square.on.square") }.help("Duplicate")
                        Spacer()
                        Button(role: .destructive) { model.deleteSelected() } label: { Image(systemName: "trash") }.help("Delete")
                    }
                }

                Divider()
                section("Capture") {
                    TextField("Name", text: $model.meta.name).textFieldStyle(.roundedBorder)
                    TextField("Tags (comma separated)", text: Binding(
                        get: { model.meta.tags.joined(separator: ", ") },
                        set: { model.meta.tags = $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }.filter { !$0.isEmpty } }
                    )).textFieldStyle(.roundedBorder)
                    Text("\(model.meta.width) × \(model.meta.height) px\(model.meta.sourceApp.map { " • \($0)" } ?? "")")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(12)
        }
    }

    private func section<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            content()
        }
    }
}

struct ColorRow: View {
    let selected: RGBA?
    let pick: (RGBA) -> Void
    @State private var custom = Color.red

    var body: some View {
        HStack(spacing: 5) {
            ForEach(RGBA.presets, id: \.self) { c in
                let isOn = selected.map { $0.with(alpha: 1) == c } ?? false
                Circle().fill(Color(nsColor: c.nsColor))
                    .overlay(Circle().stroke(isOn ? Color.accentColor : Color.gray.opacity(0.5), lineWidth: isOn ? 2.5 : 1))
                    .frame(width: 17, height: 17)
                    .onTapGesture { pick(c) }
            }
            ColorPicker("", selection: Binding(get: { custom }, set: { new in
                custom = new
                if let c = NSColor(new).usingColorSpace(.sRGB) {
                    pick(RGBA(Double(c.redComponent), Double(c.greenComponent), Double(c.blueComponent), Double(c.alphaComponent)))
                }
            }), supportsOpacity: true).labelsHidden().frame(width: 28)
        }
    }
}

// MARK: - Tray

/// Recent captures along the bottom, plus search and zoom.
struct TrayView: View {
    @ObservedObject var ws: Workspace
    @ObservedObject var library: LibraryModel
    let model: EditorModel?

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary).font(.caption)
                    TextField("Search", text: $library.query).textFieldStyle(.plain).font(.caption)
                }
                .frame(width: 140)
                Text("\(library.filtered.count) captures").font(.caption2).foregroundStyle(.secondary)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 8) {
                    ForEach(library.filtered.prefix(150)) { m in
                        let current = model?.meta.id == m.id
                        Group {
                            if let img = library.thumb(m.id) { Image(nsImage: img).resizable().aspectRatio(contentMode: .fill) }
                            else { Color.gray.opacity(0.25) }
                        }
                        .frame(width: 92, height: 62)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(current ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: current ? 3 : 1))
                        .help(m.name)
                        .onTapGesture { ws.open(id: m.id) }
                        .contextMenu {
                            Button("Copy Image") { library.copy(m.id) }
                            Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([library.store.folder(m.id)]) }
                            Divider()
                            Button("Move to Trash", role: .destructive) { library.delete([m.id]); ws.closeIfDeleted() }
                        }
                    }
                }
                .padding(.vertical, 6)
            }
            .frame(height: 76)
            if let model { ZoomControls(zoom: model.zoom) }
        }
        .padding(.horizontal, 10)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

struct ZoomControls: View {
    @ObservedObject var zoom: ZoomController
    var body: some View {
        HStack(spacing: 4) {
            Button { zoom.zoom(by: 1 / 1.25) } label: { Image(systemName: "minus.magnifyingglass") }.help("Zoom out")
            Text("\(zoom.percent)%").font(.caption.monospacedDigit()).frame(width: 44)
            Button { zoom.zoom(by: 1.25) } label: { Image(systemName: "plus.magnifyingglass") }.help("Zoom in")
            Button("Fit") { zoom.fit() }.help("Fit to window")
            Button("100%") { zoom.actualSize() }.help("Actual pixels")
        }
        .buttonStyle(.borderless)
        .controlSize(.small)
    }
}

/// Hosts the single main window.
final class MainWindowController: NSWindowController, NSWindowDelegate {
    let ws: Workspace

    init(ws: Workspace) {
        self.ws = ws
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 1280, height: 820),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "Pinpoint"
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: MainView(ws: ws))
        window.setFrameAutosaveName("PinpointMain")
        if !window.setFrameUsingName("PinpointMain") { window.center() }
        super.init(window: window)
        window.delegate = self
    }
    required init?(coder: NSCoder) { fatalError() }

    func windowWillClose(_ notification: Notification) {
        ws.saveCurrent()
        AppDelegate.shared?.mainWindowClosed()
    }

    // Menu-bar shortcuts when the canvas isn't the first responder.
    @objc func saveDocument(_ sender: Any?) { ws.editor?.save() }
    @objc func exportDocument(_ sender: Any?) { ws.editor?.export() }
    @objc func undo(_ sender: Any?) { ws.editor?.undo() }
    @objc func redo(_ sender: Any?) { ws.editor?.redo() }
}

/// Every note on this capture, numbered like the badges on the image.
struct NotesList: View {
    @ObservedObject var model: EditorModel
    var body: some View {
        let numbers = Renderer.noteNumbers(model.annotations)
        let noted = model.annotations.filter { numbers[$0.id] != nil }
        if !noted.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Notes").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Spacer()
                    Button("Copy for AI") { model.copyHandoff() }.controlSize(.small)
                }
                ForEach(noted) { a in
                    HStack(alignment: .top, spacing: 6) {
                        Text("\(numbers[a.id] ?? 0)").font(.caption.bold()).foregroundStyle(.white)
                            .frame(width: 18, height: 18).background(Circle().fill(Color(white: 0.2)))
                        TextField("Note", text: Binding(get: { a.note ?? "" }, set: { model.setNote(a.id, $0) }), axis: .vertical)
                            .textFieldStyle(.roundedBorder).font(.callout).lineLimit(1...5)
                        Button { model.selectedID = a.id; model.promptNote(a.id, autoListen: true) } label: { Image(systemName: "mic") }
                            .buttonStyle(.borderless).help("Dictate")
                    }
                }
            }
        }
    }
}
