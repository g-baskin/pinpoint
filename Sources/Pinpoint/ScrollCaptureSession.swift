import AppKit
import ScreenCaptureKit
import SwiftUI
import PinpointCore

/// Scrolling capture: outlines a region, grabs it several times a second while the user scrolls, and stitches the frames.
@MainActor
final class ScrollCaptureSession {
    final class Status: ObservableObject {
        @Published var height = 0
        @Published var message = "Start at the top, then scroll down slowly"
        @Published var warning = false
    }

    private let screen: NSScreen
    private let rect: CGRect          // points, relative to the screen's top-left
    private let scale: CGFloat
    private let previousApp: NSRunningApplication?
    private let completion: (CGImage?) -> Void
    private let status = Status()
    private let stitcher: ScrollStitcher
    private var outline: NSWindow?
    private var panel: NSPanel?
    private var loop: Task<Void, Never>?
    private var running = false
    private var ended = false

    init(screen: NSScreen, rect: CGRect, scale: CGFloat, previousApp: NSRunningApplication?, completion: @escaping (CGImage?) -> Void) {
        self.screen = screen; self.rect = rect; self.scale = scale; self.previousApp = previousApp; self.completion = completion
        stitcher = ScrollStitcher(options: .init(scrollbarMargin: Int(20 * scale)))
    }

    /// Takes the first frame (so permission problems surface here), then shows the outline and controls and starts following.
    func start() async throws {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        let id = CaptureService.displayID(screen)
        guard let display = content.displays.first(where: { $0.displayID == id }) else { throw CaptureError.noDisplay }
        // Leaving out Pinpoint's own windows keeps the outline and controls out of the frames.
        let ours = content.applications.filter { $0.processID == ProcessInfo.processInfo.processIdentifier }
        let filter = SCContentFilter(display: display, excludingApplications: ours, exceptingWindows: [])
        let config = SCStreamConfiguration()
        config.sourceRect = rect
        config.width = Int((rect.width * scale).rounded())
        config.height = Int((rect.height * scale).rounded())
        config.showsCursor = false
        config.captureResolution = .best
        let first = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        // Finished or cancelled (⌃⇧5) while the first frame was on its way: don't open windows or start following.
        guard !ended else { return }
        stitcher.add(first)
        status.height = stitcher.height
        running = true
        showWindows()
        // Hand focus back so the page reacts to the trackpad, mouse wheel and keyboard as usual.
        if let app = previousApp, app.processIdentifier != ProcessInfo.processInfo.processIdentifier { app.activate() }
        let stitcher = stitcher
        loop = Task { [weak self] in
            while let self, self.running {
                do {
                    let frame = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
                    guard self.running else { break }
                    let step = await Task.detached(priority: .userInitiated) { stitcher.add(frame) }.value
                    guard self.running else { break }
                    self.show(step)
                } catch {
                    guard self.running else { break }
                    if CaptureService.isPermissionError(error) {
                        self.cancel()
                        CaptureService.showPermissionHelp()
                        break
                    }
                    self.status.message = "Capture paused: \(error.localizedDescription)"
                    self.status.warning = true
                }
                try? await Task.sleep(nanoseconds: 80_000_000)
            }
        }
    }

    /// Stops following and hands back the stitched image.
    func finish() {
        guard !ended else { return }
        ended = true; running = false
        close()
        let stitcher = stitcher
        Task {
            await loop?.value
            let image = await Task.detached(priority: .userInitiated) { stitcher.makeImage() }.value
            completion(image)
        }
    }

    func cancel() {
        guard !ended else { return }
        ended = true; running = false
        loop?.cancel()
        close()
        completion(nil)
    }

    private func show(_ step: ScrollStitcher.Step) {
        status.height = stitcher.height
        switch step {
        case .lostTrack:
            status.message = "Lost the place. Scroll back up a little, then go slower"
            status.warning = true
        case .full:
            status.message = "Maximum length reached. Click Done"
            status.warning = true
        case .added, .unchanged, .started:
            status.message = "Scroll down slowly through the outlined area"
            status.warning = false
        }
    }

    // MARK: Windows

    private var globalRect: CGRect {
        CGRect(x: screen.frame.minX + rect.minX, y: screen.frame.maxY - rect.maxY, width: rect.width, height: rect.height)
    }

    private func showWindows() {
        let o = NSWindow(contentRect: globalRect.insetBy(dx: -4, dy: -4), styleMask: .borderless, backing: .buffered, defer: false)
        o.isOpaque = false
        o.backgroundColor = .clear
        o.hasShadow = false
        o.ignoresMouseEvents = true   // scrolling and clicks go straight through to the page
        o.level = .statusBar
        o.isReleasedWhenClosed = false
        o.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        o.contentView = OutlineView()
        o.orderFrontRegardless()
        outline = o

        let host = NSHostingView(rootView: ScrollCaptureBar(status: status, done: { [weak self] in self?.finish() },
                                                            cancel: { [weak self] in self?.cancel() }))
        let size = host.fittingSize
        let p = NSPanel(contentRect: CGRect(origin: panelOrigin(size), size: size), styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.isFloatingPanel = true
        p.hidesOnDeactivate = false
        p.becomesKeyOnlyIfNeeded = true
        p.level = .statusBar
        p.isReleasedWhenClosed = false
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.contentView = host
        p.orderFrontRegardless()
        panel = p
    }

    /// Below the region if there's room, else above it, else just inside its bottom edge.
    private func panelOrigin(_ size: CGSize) -> CGPoint {
        let r = globalRect, vis = screen.visibleFrame, gap: CGFloat = 12
        let x = min(max(r.midX - size.width / 2, vis.minX + 8), vis.maxX - size.width - 8)
        if r.minY - gap - size.height >= vis.minY { return CGPoint(x: x, y: r.minY - gap - size.height) }
        if r.maxY + gap + size.height <= vis.maxY { return CGPoint(x: x, y: r.maxY + gap) }
        return CGPoint(x: x, y: max(vis.minY, r.minY) + gap)
    }

    private func close() {
        outline?.orderOut(nil); outline = nil
        panel?.orderOut(nil); panel = nil
    }
}

private final class OutlineView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(rect: bounds.insetBy(dx: 2, dy: 2))
        path.lineWidth = 2
        path.setLineDash([8, 5], count: 2, phase: 0)
        NSColor.systemBlue.setStroke()
        path.stroke()
    }
}

private struct ScrollCaptureBar: View {
    @ObservedObject var status: ScrollCaptureSession.Status
    let done: () -> Void
    let cancel: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: status.warning ? "exclamationmark.triangle.fill" : "scroll")
                .foregroundStyle(status.warning ? Color.orange : Color.accentColor)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(status.message).font(.system(size: 12, weight: .semibold))
                Text("\(status.height) px tall · ⌃⇧5 also finishes").font(.system(size: 11)).foregroundStyle(.secondary)
                    .accessibilityLabel("\(status.height) pixels tall. Control Shift 5 also finishes")
            }
            .accessibilityElement(children: .combine)
            Button("Cancel", action: cancel)
            Button("Done", action: done).buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .fixedSize()
    }
}
