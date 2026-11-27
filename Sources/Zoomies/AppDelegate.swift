import AppKit
import Carbon
import SwiftUI
import ZoomiesCore

enum CaptureMode { case area, window, screen, allScreens }

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static weak var shared: AppDelegate?

    let library = LibraryStore()
    private var statusItem: NSStatusItem!
    lazy var workspace = Workspace(store: library)
    private var mainWindow: MainWindowController?
    private var settingsWindow: NSWindow?
    private var overlays: [SelectionOverlay] = []
    private var capturing = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        NSApp.setActivationPolicy(.accessory)
        buildMainMenu()
        buildStatusItem()
        let mods = controlKey | shiftKey
        HotKeyCenter.shared.register(keyCode: kVK_ANSI_1, modifiers: mods, id: 1) { [weak self] in self?.capture(.area) }
        HotKeyCenter.shared.register(keyCode: kVK_ANSI_2, modifiers: mods, id: 2) { [weak self] in self?.capture(.window) }
        HotKeyCenter.shared.register(keyCode: kVK_ANSI_3, modifiers: mods, id: 3) { [weak self] in self?.capture(.screen) }
        HotKeyCenter.shared.register(keyCode: kVK_ANSI_4, modifiers: mods, id: 5) { [weak self] in self?.capture(.allScreens) }
        HotKeyCenter.shared.register(keyCode: kVK_ANSI_L, modifiers: mods, id: 4) { [weak self] in self?.showLibrary() }
        // No nagging at launch: the preflight check can report false even when access works. We only ask if a capture fails.
        NSLog("Pinpoint: launched; screen capture preflight = \(CaptureService.hasPermission())")
        // Opening Pinpoint shows its editor/library window, like any normal app; it keeps running in the menu bar after you close it.
        DispatchQueue.main.async { self.showMain() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        workspace.saveCurrent()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { showMain() }
        return true
    }

    // MARK: Menus

    private func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let b = statusItem.button {
            b.image = NSImage(systemSymbolName: "camera.viewfinder", accessibilityDescription: "Pinpoint")
            b.image?.isTemplate = true
        }
        let menu = NSMenu()
        func item(_ title: String, _ action: Selector, _ key: String = "", _ mods: NSEvent.ModifierFlags = []) {
            let i = NSMenuItem(title: title, action: action, keyEquivalent: key)
            i.keyEquivalentModifierMask = mods
            i.target = self
            menu.addItem(i)
        }
        item("Capture Area or Window", #selector(captureArea), "1", [.control, .shift])
        item("Capture Window", #selector(captureWindow), "2", [.control, .shift])
        item("Capture Full Screen", #selector(captureScreen), "3", [.control, .shift])
        item("Capture All Screens", #selector(captureAllScreens), "4", [.control, .shift])
        menu.addItem(.separator())
        item("Open Pinpoint", #selector(showMainAction))
        item("Open Image…", #selector(openImage))
        item("Library", #selector(showLibraryAction), "l", [.control, .shift])
        item("Settings…", #selector(showSettingsAction), ",", [.command])
        menu.addItem(.separator())
        item("Quit Pinpoint", #selector(quit), "q", [.command])
        statusItem.menu = menu
    }

    /// Standard menu bar (visible while an editor/library is open) so ⌘Z, ⌘C, ⌘S etc. work.
    private func buildMainMenu() {
        let main = NSMenu()
        func sub(_ title: String, _ items: [NSMenuItem]) {
            let top = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            let m = NSMenu(title: title)
            items.forEach { m.addItem($0) }
            top.submenu = m
            main.addItem(top)
        }
        func mi(_ t: String, _ a: Selector?, _ k: String, _ mods: NSEvent.ModifierFlags = [.command], target: AnyObject? = nil) -> NSMenuItem {
            let i = NSMenuItem(title: t, action: a, keyEquivalent: k); i.keyEquivalentModifierMask = mods; i.target = target; return i
        }
        sub("Pinpoint", [mi("About Pinpoint", #selector(NSApplication.orderFrontStandardAboutPanel(_:)), ""),
                        .separator(), mi("Settings…", #selector(showSettingsAction), ",", target: self),
                        .separator(), mi("Quit Pinpoint", #selector(quit), "q", target: self)])
        sub("File", [mi("Capture Area or Window", #selector(captureArea), "1", [.control, .shift], target: self),
                     mi("Open Image…", #selector(openImage), "o", target: self),
                     mi("Library", #selector(showLibraryAction), "l", [.control, .shift], target: self),
                     .separator(),
                     mi("Save to Library", Selector(("saveDocument:")), "s"),
                     mi("Export…", Selector(("exportDocument:")), "e", [.command, .shift]),
                     mi("Close", #selector(NSWindow.performClose(_:)), "w")])
        sub("Edit", [mi("Undo", Selector(("undo:")), "z"), mi("Redo", Selector(("redo:")), "z", [.command, .shift]),
                     .separator(),
                     mi("Cut", #selector(NSText.cut(_:)), "x"), mi("Copy", #selector(NSText.copy(_:)), "c"),
                     mi("Paste", #selector(NSText.paste(_:)), "v"), mi("Delete", #selector(NSText.delete(_:)), ""),
                     mi("Select All", #selector(NSText.selectAll(_:)), "a")])
        sub("Window", [mi("Minimize", #selector(NSWindow.performMiniaturize(_:)), "m")])
        NSApp.mainMenu = main
    }

    @objc func captureArea() { capture(.area) }
    @objc func captureWindow() { capture(.window) }
    @objc func captureScreen() { capture(.screen) }
    @objc func captureAllScreens() { capture(.allScreens) }
    @objc func showLibraryAction() { showLibrary() }
    @objc func showMainAction() { showMain() }
    @objc func showSettingsAction() { showSettings() }
    @objc func quit() { NSApp.terminate(nil) }

    // MARK: Capture flow

    func capture(_ mode: CaptureMode) {
        guard !capturing else { return }
        capturing = true
        let mouseScreen = CaptureService.screenUnderMouse()
        let frontApp = NSWorkspace.shared.frontmostApplication?.localizedName
        let windows = CaptureService.visibleWindows()
        Task {
            do {
                if mode == .screen {
                    finishCapture(try await CaptureService.captureScreen(mouseScreen), app: frontApp)
                    return
                }
                if mode == .allScreens {
                    finishCapture(try await CaptureService.captureAllScreens(), app: frontApp)
                    return
                }
                // Freeze every display and show the picker on all of them at once.
                var frozenShots: [(NSScreen, CGImage)] = []
                for s in NSScreen.screens { frozenShots.append((s, try await CaptureService.captureScreen(s))) }
                overlays = frozenShots.map { screen, frozen in
                    SelectionOverlay(screen: screen, frozen: frozen, windows: windows, preferWindow: mode == .window) { [weak self] result in
                        guard let self else { return }
                        self.overlays.forEach { $0.dismiss() }
                        self.overlays.removeAll()
                        Task { @MainActor in await self.handleSelection(result, frozen: frozen, mode: mode, scale: screen.backingScaleFactor, app: frontApp) }
                    }
                }
                for o in overlays where o.targetScreen != mouseScreen { o.present(makeKey: false) }
                overlays.first { $0.targetScreen == mouseScreen }?.present(makeKey: true)
            } catch {
                capturing = false
                NSLog("Pinpoint: capture failed: \(error) preflight=\(CaptureService.hasPermission())")
                if CaptureService.isPermissionError(error) { CaptureService.showPermissionHelp() } else { showError(error) }
            }
        }
    }

    private func handleSelection(_ result: SelectionResult, frozen: CGImage, mode: CaptureMode, scale: CGFloat, app: String?) async {
        switch result {
        case .cancelled:
            capturing = false
        case .allScreens:
            do { finishCapture(try await CaptureService.captureAllScreens(), app: app) }
            catch { capturing = false; showError(error) }
        case .region(let r):
            if let img = frozen.cropping(to: r) { finishCapture(img, app: app) } else { capturing = false }
        case .window(let w, let r):
            // Window mode grabs the window itself (even the parts hidden behind others); area mode keeps what was on screen.
            if mode == .window, let img = try? await CaptureService.captureWindow(w.id, scale: scale) {
                finishCapture(img, app: w.owner)
            } else if let img = frozen.cropping(to: r) {
                finishCapture(img, app: w.owner)
            } else { capturing = false }
        }
    }

    private func finishCapture(_ image: CGImage, app: String?) {
        capturing = false
        let settings = AppSettings.shared
        do {
            let meta = try library.create(image: image, name: "\(app ?? "Screen") \(Date().formatted(date: .abbreviated, time: .shortened))", sourceApp: app)
            NotificationCenter.default.post(name: .zoomiesLibraryChanged, object: nil)
            if settings.copyAfterCapture, let d = ImageFiles.encode(image) {
                NSPasteboard.general.clearContents(); NSPasteboard.general.setData(d, forType: .png)
            }
            if settings.openEditorAfterCapture {
                if let ed = openEditor(meta: meta, image: image), settings.autoRedactOnCapture { autoRedactWhenReady(ed) }
            }
            postProcess(meta: meta, image: image)
        } catch { showError(error) }
    }

    private func autoRedactWhenReady(_ model: EditorModel, tries: Int = 0) {
        if model.analysis != nil { model.autoRedact(style: .blur); return }
        guard tries < 40 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in self?.autoRedactWhenReady(model, tries: tries + 1) }
    }

    /// Background: OCR for search + offline name, then optional AI name & tags.
    private func postProcess(meta: CaptureMeta, image: CGImage) {
        let store = library
        let useAI = AppSettings.shared.autoNameWithAI && AppSettings.shared.isAIConfigured
        let client = useAI ? try? AppSettings.shared.makeClient(fast: true) : nil
        Task.detached(priority: .utility) {
            guard var m = store.meta(meta.id) else { return }
            let analysis = (try? Analyzer.analyze(image, faces: false)) ?? Analysis(lines: [], sensitive: [])
            m.ocrText = analysis.fullText
            m.name = Analyzer.suggestedName(from: analysis.lines, app: meta.sourceApp)
            if let client, let r = try? await Assistants(client: client).nameAndTags(image: image, ocrText: m.ocrText, app: m.sourceApp) {
                m.name = r.name; m.tags = r.tags; m.aiNamed = true
            }
            let final = m
            await MainActor.run {
                // Don't clobber edits the user made in an open editor meanwhile.
                if let ed = self.workspace.editor, ed.meta.id == final.id {
                    if ed.meta.name == meta.name { ed.meta.name = final.name }
                    if ed.meta.tags.isEmpty { ed.meta.tags = final.tags }
                    ed.meta.ocrText = final.ocrText
                    ed.meta.aiNamed = final.aiNamed
                    try? store.writeMeta(ed.meta)
                } else {
                    try? store.writeMeta(final)
                }
                NotificationCenter.default.post(name: .zoomiesLibraryChanged, object: nil)
            }
        }
    }

    // MARK: Windows

    /// Opens a capture in the single Pinpoint window.
    @discardableResult
    func openEditor(meta: CaptureMeta, image: CGImage) -> EditorModel? {
        workspace.open(meta: meta, image: image)
        showMain()
        return workspace.editor
    }

    func openEditor(id: UUID) {
        workspace.open(id: id)
        showMain()
    }

    func showMain(mode: Workspace.Mode? = nil) {
        if mainWindow == nil { mainWindow = MainWindowController(ws: workspace) }
        if let mode { workspace.mode = mode }
        workspace.library.reload()
        mainWindow?.showWindow(nil)
        activate()
    }

    func mainWindowClosed() {
        DispatchQueue.main.async { self.updateActivationPolicy() }
    }

    @objc func openImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = true
        activate()
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            guard let img = ImageFiles.load(url) else { continue }
            if let meta = try? library.create(image: img, name: url.deletingPathExtension().lastPathComponent, sourceApp: nil) {
                openEditor(meta: meta, image: img)
                postProcess(meta: meta, image: img)
            }
        }
        NotificationCenter.default.post(name: .zoomiesLibraryChanged, object: nil)
    }

    func showLibrary() { showMain(mode: .library) }

    func showSettings() {
        if settingsWindow == nil {
            let w = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 520, height: 560), styleMask: [.titled, .closable], backing: .buffered, defer: false)
            w.title = "Pinpoint Settings"
            w.isReleasedWhenClosed = false
            w.contentView = NSHostingView(rootView: SettingsView())
            w.center()
            NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: w, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.updateActivationPolicy() }
            }
            settingsWindow = w
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        activate()
    }

    /// Show in the Dock / ⌘-Tab only while a real window is open; otherwise live in the menu bar.
    private func activate() {
        if NSApp.activationPolicy() != .regular { NSApp.setActivationPolicy(.regular) }
        NSApp.activate(ignoringOtherApps: true)
    }

    private func updateActivationPolicy() {
        let anyOpen = (mainWindow?.window?.isVisible ?? false) || (settingsWindow?.isVisible ?? false)
        if !anyOpen { NSApp.setActivationPolicy(.accessory) }
    }

    private func showError(_ error: Error) {
        let a = NSAlert(error: error)
        activate()
        a.runModal()
    }
}
