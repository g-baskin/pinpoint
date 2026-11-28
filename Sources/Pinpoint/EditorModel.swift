import AppKit
import Combine
import UniformTypeIdentifiers
import PinpointCore

enum Tool: String, CaseIterable, Identifiable {
    case select, arrow, line, rectangle, ellipse, text, callout, highlight, step, note, blur, redact, crop
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .select: return "cursorarrow"
        case .arrow: return "arrow.up.right"
        case .line: return "line.diagonal"
        case .rectangle: return "rectangle"
        case .ellipse: return "circle"
        case .text: return "textformat"
        case .callout: return "text.bubble"
        case .highlight: return "highlighter"
        case .step: return "1.circle.fill"
        case .note: return "mic.circle"
        case .blur: return "drop.halffull"
        case .redact: return "rectangle.fill"
        case .crop: return "crop"
        }
    }
    var key: Character {
        switch self {
        case .select: return "v"; case .arrow: return "a"; case .line: return "l"; case .rectangle: return "r"
        case .ellipse: return "e"; case .text: return "t"; case .callout: return "o"; case .highlight: return "h"; case .step: return "n"
        case .blur: return "b"; case .redact: return "x"; case .crop: return "c"; case .note: return "m"
        }
    }
    var title: String { (self == .note ? "Voice note" : rawValue.capitalized) + " (\(String(key).uppercased()))" }
    var kind: AnnotationKind? { AnnotationKind(rawValue: rawValue) }
}

struct LogEntry: Identifiable {
    enum Role { case user, assistant, tool, error }
    let id = UUID()
    let role: Role
    let text: String
}

@MainActor
final class EditorModel: ObservableObject {
    let base: CGImage
    let pixelated: CGImage?
    let library: LibraryStore
    var imageSize: CGSize { CGSize(width: base.width, height: base.height) }

    @Published var meta: CaptureMeta
    @Published var annotations: [Annotation]
    @Published var crop: CGRect?
    @Published var tool: Tool = .arrow
    @Published var color: RGBA = .red
    @Published var lineWidth: Double
    @Published var fontSize: Double
    @Published var fillColor: RGBA?
    @Published var shadow = true
    /// Selecting an item loads its style into the Properties panel (like Snagit).
    @Published var selectedID: UUID? {
        didSet {
            guard let id = selectedID, id != oldValue, let a = annotations.first(where: { $0.id == id }) else { return }
            color = a.color; fillColor = a.fillColor; shadow = a.hasShadow; fontSize = a.fontSize
            if a.lineWidth > 0 { lineWidth = a.lineWidth }
        }
    }
    let zoom = ZoomController()
    /// The canvas showing this capture (for anchoring the note prompt).
    weak var canvas: CanvasView?

    func setNote(_ id: UUID, _ text: String) {
        guard let i = annotations.firstIndex(where: { $0.id == id }) else { return }
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let new: String? = t.isEmpty ? nil : t
        guard annotations[i].note != new else { return }
        checkpoint()
        annotations[i].note = new
    }

    func removeAnnotation(_ id: UUID) {
        guard annotations.contains(where: { $0.id == id }) else { return }
        checkpoint(); annotations.removeAll { $0.id == id }
        if selectedID == id { selectedID = nil }
    }

    /// Opens the "Add more context?" prompt next to an item.
    func promptNote(_ id: UUID, autoListen: Bool) { canvas?.showNotePrompt(for: id, autoListen: autoListen) }

    // MARK: Handoff

    var handoffMarkdown: String {
        Handoff.markdown(meta: meta, annotations: annotations, imagePath: library.renderedURL(meta.id).path, ocr: analysis?.lines ?? [])
    }

    /// Saves, then copies text for a coding agent / teammate (with the saved image's path).
    func copyHandoff() {
        save()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(handoffMarkdown, forType: .string)
        info("Copied the handoff (notes + image path). Paste it into your coding agent or a message.")
    }



    /// Saves, then copies the marked-up image's path as text so a coding CLI in the terminal can open it.
    func copyFilePath() {
        save()
        guard !dirty else { return }   // save failed and already said why
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(library.bestURL(meta.id).path, forType: .string)
        info("Copied the image's file path. Paste it into your coding CLI so it can open the image.")
    }

    func exportHandoff() {
        save()
        guard let img = flattened() else { return }
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.canCreateDirectories = true
        panel.prompt = "Export Here"
        panel.message = "Choose where to save the handoff folder (image + notes.md)"
        guard panel.runModal() == .OK, let parent = panel.url else { return }
        let safe = meta.name.components(separatedBy: CharacterSet(charactersIn: "/:\\?%*|\"<>")).joined(separator: "-")
        let folder = parent.appendingPathComponent("\(safe.prefix(60)) handoff", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try ImageFiles.write(img, to: folder.appendingPathComponent("screenshot.png"))
            try ImageFiles.write(Renderer.withNotesPanel(img, annotations: annotations), to: folder.appendingPathComponent("screenshot-with-notes.png"))
            let md = Handoff.markdown(meta: meta, annotations: annotations, imagePath: "screenshot.png", ocr: analysis?.lines ?? [])
                + "\n![screenshot](screenshot.png)\n"
            try md.write(to: folder.appendingPathComponent("notes.md"), atomically: true, encoding: .utf8)
            NSWorkspace.shared.activateFileViewerSelecting([folder.appendingPathComponent("notes.md")])
            info("Exported the handoff to \(folder.lastPathComponent).")
        } catch { fail("Export failed: \(error.localizedDescription)") }
    }
    @Published var analysis: Analysis?
    @Published var log: [LogEntry] = []
    @Published var busy = false
    @Published var dirty = false

    private var undoStack: [([Annotation], CGRect?)] = []
    private var redoStack: [([Annotation], CGRect?)] = []
    private var agentTask: Task<Void, Never>?

    init(meta: CaptureMeta, base: CGImage, library: LibraryStore) {
        self.meta = meta
        self.base = base
        self.library = library
        self.annotations = meta.annotations
        self.crop = meta.crop
        let size = CGSize(width: base.width, height: base.height)
        self.lineWidth = Annotation.defaultLineWidth(for: size)
        self.fontSize = Annotation.defaultFontSize(for: size)
        self.pixelated = Renderer.pixelated(base)
        startAnalysis()
    }

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    func checkpoint() {
        undoStack.append((annotations, crop))
        if undoStack.count > 200 { undoStack.removeFirst() }
        redoStack.removeAll()
        dirty = true
    }

    func undo() {
        guard let s = undoStack.popLast() else { return }
        redoStack.append((annotations, crop)); annotations = s.0; crop = s.1; selectedID = nil; dirty = true
    }

    func redo() {
        guard let s = redoStack.popLast() else { return }
        undoStack.append((annotations, crop)); annotations = s.0; crop = s.1; selectedID = nil; dirty = true
    }

    func add(_ a: Annotation) { checkpoint(); annotations.append(a); selectedID = a.id }

    func deleteSelected() {
        guard let id = selectedID else { return }
        checkpoint(); annotations.removeAll { $0.id == id }; selectedID = nil
    }

    /// Applies the current style to the selected item too.
    func styleChanged() {
        guard let id = selectedID, let i = annotations.firstIndex(where: { $0.id == id }) else { return }
        var a = annotations[i]
        if a.kind != .blur { a.color = color }
        if a.kind != .redact && a.kind != .blur && a.kind != .highlight { a.lineWidth = lineWidth }
        if a.kind.supportsFill { a.fillColor = fillColor }
        a.shadow = shadow
        if [.text, .callout, .step].contains(a.kind) { a.fontSize = fontSize }
        guard a != annotations[i] else { return }
        checkpoint()
        annotations[i] = a
    }

    var selected: Annotation? { selectedID.flatMap { id in annotations.first { $0.id == id } } }

    func apply(_ s: QuickStyle) {
        color = s.color
        fillColor = s.fill
        shadow = s.shadow
        lineWidth = Annotation.defaultLineWidth(for: imageSize) * s.widthScale
        if let f = s.fontScale { fontSize = Annotation.defaultFontSize(for: imageSize) * f }
        styleChanged()
    }

    func bringToFront() {
        guard let id = selectedID, let i = annotations.firstIndex(where: { $0.id == id }) else { return }
        checkpoint(); let a = annotations.remove(at: i); annotations.append(a)
    }
    func sendToBack() {
        guard let id = selectedID, let i = annotations.firstIndex(where: { $0.id == id }) else { return }
        checkpoint(); let a = annotations.remove(at: i); annotations.insert(a, at: 0)
    }
    func duplicateSelected() {
        guard let a = selected else { return }
        var b = a.offset(by: CGSize(width: 20, height: 20)); b.id = UUID()
        add(b)
    }

    var nextStep: Int { (annotations.filter { $0.kind == .step }.compactMap { Int($0.text ?? "") }.max() ?? 0) + 1 }

    func newAnnotation(kind: AnnotationKind, at p: CGPoint) -> Annotation {
        Annotation(kind: kind, start: p, end: p, color: kind == .redact ? .black : kind == .note ? .orange : color, lineWidth: lineWidth,
                   text: kind == .step ? String(nextStep) : nil, fontSize: fontSize,
                   fillColor: kind.supportsFill ? fillColor : nil, shadow: shadow)
    }

    // MARK: Output

    func flattened() -> CGImage? { Renderer.flatten(base: base, annotations: annotations, crop: crop, pixelated: pixelated) }

    /// Copies one picture with everything on it: markup, note badges and (if there are notes) a Notes panel underneath.
    /// Image only on the clipboard, as PNG + TIFF, so every app pastes it as a picture.
    func copyImage(includeNotesPanel: Bool = true) {
        guard let flat = flattened() else { return }
        let img = includeNotesPanel ? Renderer.withNotesPanel(flat, annotations: annotations) : flat
        let ns = NSImage(cgImage: img, size: NSSize(width: img.width, height: img.height))
        let pb = NSPasteboard.general
        pb.clearContents()
        if let png = ImageFiles.encode(img) {
            let item = NSPasteboardItem()
            item.setData(png, forType: .png)
            if let tiff = ns.tiffRepresentation { item.setData(tiff, forType: .tiff) }
            pb.writeObjects([item])
        } else {
            pb.writeObjects([ns])
        }
        let hasNotes = !Renderer.noteNumbers(annotations).isEmpty
        info(includeNotesPanel && hasNotes ? "Copied the image with your markup and notes panel — paste it anywhere." : "Copied the image with your markup.")
    }

    func save() {
        meta.annotations = annotations
        meta.crop = crop
        do {
            try library.save(meta, rendered: flattened())
            dirty = false
            NotificationCenter.default.post(name: .pinpointLibraryChanged, object: nil)
        } catch { fail("Save failed: \(error.localizedDescription)") }
    }

    func export() {
        guard let img = flattened() else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png, .jpeg, .heic]
        panel.nameFieldStringValue = meta.name + ".png"
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let type = UTType(filenameExtension: url.pathExtension) ?? .png
        do { try ImageFiles.write(img, to: url, type: type); info("Exported to \(url.lastPathComponent).") }
        catch { fail("Export failed: \(error.localizedDescription)") }
    }

    // MARK: On-device analysis

    func startAnalysis() {
        let img = base
        let terms = AppSettings.shared.redactTerms
        Task.detached(priority: .userInitiated) {
            let result = (try? Analyzer.analyze(img, customTerms: terms)) ?? Analysis(lines: [], sensitive: [])
            await MainActor.run {
                self.analysis = result
                if self.meta.ocrText.isEmpty && !result.lines.isEmpty {
                    self.meta.ocrText = result.fullText
                    do { try self.library.writeMeta(self.meta) }
                    catch { NSLog("Pinpoint: couldn't save recognised text: \(error.localizedDescription)") }
                }
            }
        }
    }

    func autoRedact(style: AnnotationKind) {
        guard let a = analysis else { info("Still scanning the image — try again in a second."); return }
        if a.sensitive.isEmpty { info("No sensitive info found on-device. Ask the assistant if you can see something it missed."); return }
        checkpoint()
        annotations += Analyzer.redactions(for: a.sensitive, style: style, imageSize: imageSize)
        let counts = Dictionary(grouping: a.sensitive, by: \.kind).map { "\($0.value.count) \($0.key.label.lowercased())" }.sorted()
        info("Covered " + counts.joined(separator: ", ") + ".")
    }

    func extractText() {
        guard let a = analysis else { info("Still scanning the image — try again in a second."); return }
        let text = a.fullText
        guard !text.isEmpty else { info("No text found."); return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        log.append(LogEntry(role: .assistant, text: "Copied \(a.lines.count) lines of text:\n\n" + text))
    }

    // MARK: AI

    private func client() -> LLMClient? {
        do { return try AppSettings.shared.makeClient() }
        catch { fail(error.localizedDescription); return nil }
    }

    func summarize() {
        guard let c = client() else { return }
        runAI("Summarise this capture") {
            let s = try await Assistants(client: c).summarize(image: self.flattened() ?? self.base, ocrText: self.analysis?.fullText ?? self.meta.ocrText)
            self.meta.summary = s
            self.save()
            self.log.append(LogEntry(role: .assistant, text: s))
        }
    }

    func nameAndTag() {
        guard let c = client() else { return }
        runAI("Name and tag this capture") {
            let r = try await Assistants(client: c).nameAndTags(image: self.base, ocrText: self.analysis?.fullText ?? "", app: self.meta.sourceApp)
            self.meta.name = r.name; self.meta.tags = r.tags; self.meta.aiNamed = true
            self.save()
            self.log.append(LogEntry(role: .assistant, text: "Named “\(r.name)” — tags: \(r.tags.joined(separator: ", "))"))
        }
    }

    func runAgent(_ instruction: String) {
        let text = instruction.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let c = client() else { return }
        runAI(text) {
            let analysis: Analysis
            if let a = self.analysis { analysis = a }
            else {
                let img = self.base
                let terms = AppSettings.shared.redactTerms
                analysis = try await Task.detached { try Analyzer.analyze(img, customTerms: terms) }.value
                self.analysis = analysis
            }
            let state = AgentState(annotations: self.annotations, crop: self.crop, name: self.meta.name, tags: self.meta.tags, imageSize: self.imageSize)
            let agent = EditAgent(client: c)
            let result = try await agent.run(instruction: text, image: self.base, analysis: analysis, state: state, color: self.color) { event in
                Task { @MainActor in self.log.append(LogEntry(role: .tool, text: event)) }
            }
            if result.state.annotations != self.annotations || result.state.crop != self.crop {
                self.checkpoint()
                self.annotations = result.state.annotations
                self.crop = result.state.crop
            }
            if result.state.name != self.meta.name || result.state.tags != self.meta.tags {
                self.meta.name = result.state.name; self.meta.tags = result.state.tags
            }
            self.log.append(LogEntry(role: .assistant, text: result.reply))
        }
    }

    func cancelAI() { agentTask?.cancel(); agentTask = nil; busy = false; info("Stopped.") }

    private func runAI(_ label: String, _ body: @escaping @MainActor () async throws -> Void) {
        guard !busy else { return }
        log.append(LogEntry(role: .user, text: label))
        busy = true
        agentTask = Task { @MainActor in
            defer { self.busy = false; self.agentTask = nil }
            do { try await body() }
            catch is CancellationError {}
            catch { self.fail(error.localizedDescription) }
        }
    }

    func info(_ s: String) { log.append(LogEntry(role: .assistant, text: s)) }
    func fail(_ s: String) { log.append(LogEntry(role: .error, text: s)) }
}

extension Notification.Name {
    static let pinpointLibraryChanged = Notification.Name("pinpointLibraryChanged")
}
