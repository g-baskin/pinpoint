import CoreGraphics
import Foundation
import UniformTypeIdentifiers

/// Everything Pinpoint knows about one capture. Stored as meta.json next to the images.
public struct CaptureMeta: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var created: Date
    public var modified: Date
    public var name: String
    public var tags: [String]
    public var ocrText: String
    public var summary: String?
    public var sourceApp: String?
    public var width: Int
    public var height: Int
    public var annotations: [Annotation]
    public var crop: CGRect?
    public var aiNamed: Bool

    public init(id: UUID = UUID(), created: Date = Date(), name: String, tags: [String] = [], ocrText: String = "",
                summary: String? = nil, sourceApp: String? = nil, width: Int, height: Int,
                annotations: [Annotation] = [], crop: CGRect? = nil, aiNamed: Bool = false) {
        self.id = id; self.created = created; self.modified = created; self.name = name; self.tags = tags
        self.ocrText = ocrText; self.summary = summary; self.sourceApp = sourceApp; self.width = width
        self.height = height; self.annotations = annotations; self.crop = crop; self.aiNamed = aiNamed
    }
}

/// Folder-per-capture library: <root>/<uuid>/{original.png, rendered.png, thumb.jpg, meta.json}
public final class LibraryStore: @unchecked Sendable {
    public let root: URL
    private let fm = FileManager.default
    private let lock = NSLock()

    public static var defaultRoot: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Pictures/Pinpoint", isDirectory: true)
    }

    public init(root: URL = LibraryStore.defaultRoot) {
        self.root = root
        try? fm.createDirectory(at: root, withIntermediateDirectories: true)
    }

    public func folder(_ id: UUID) -> URL { root.appendingPathComponent(id.uuidString, isDirectory: true) }
    public func originalURL(_ id: UUID) -> URL { folder(id).appendingPathComponent("original.png") }
    public func renderedURL(_ id: UUID) -> URL { folder(id).appendingPathComponent("rendered.png") }
    public func thumbURL(_ id: UUID) -> URL { folder(id).appendingPathComponent("thumb.jpg") }
    public func metaURL(_ id: UUID) -> URL { folder(id).appendingPathComponent("meta.json") }

    static let encoder: JSONEncoder = {
        let e = JSONEncoder(); e.outputFormatting = [.prettyPrinted, .sortedKeys]; e.dateEncodingStrategy = .iso8601; return e
    }()
    static let decoder: JSONDecoder = { let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d }()

    @discardableResult
    public func create(image: CGImage, name: String = "Capture", sourceApp: String? = nil) throws -> CaptureMeta {
        let meta = CaptureMeta(name: name, sourceApp: sourceApp, width: image.width, height: image.height)
        try fm.createDirectory(at: folder(meta.id), withIntermediateDirectories: true)
        try ImageFiles.write(image, to: originalURL(meta.id))
        try writeThumb(image, id: meta.id)
        try writeMeta(meta)
        return meta
    }

    /// Saves metadata and, if given, the flattened (annotated) image.
    public func save(_ meta: CaptureMeta, rendered: CGImage? = nil) throws {
        var m = meta
        m.modified = Date()
        try fm.createDirectory(at: folder(m.id), withIntermediateDirectories: true)
        if let r = rendered {
            try ImageFiles.write(r, to: renderedURL(m.id))
            try writeThumb(r, id: m.id)
        }
        try writeMeta(m)
    }

    public func writeMeta(_ meta: CaptureMeta) throws {
        lock.lock(); defer { lock.unlock() }
        try Self.encoder.encode(meta).write(to: metaURL(meta.id), options: .atomic)
    }

    func writeThumb(_ image: CGImage, id: UUID) throws {
        let (t, _) = ImageFiles.downscaled(image, maxDimension: 480)
        try ImageFiles.write(t, to: thumbURL(id), type: .jpeg, quality: 0.8)
    }

    public func meta(_ id: UUID) -> CaptureMeta? {
        guard let d = try? Data(contentsOf: metaURL(id)) else { return nil }
        return try? Self.decoder.decode(CaptureMeta.self, from: d)
    }

    public func loadAll() -> [CaptureMeta] {
        let dirs = (try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
        return dirs.compactMap { UUID(uuidString: $0.lastPathComponent).flatMap(meta) }
            .sorted { $0.created > $1.created }
    }

    public func original(_ id: UUID) -> CGImage? { ImageFiles.load(originalURL(id)) }

    /// The best image to share: the annotated render if there is one, else the original.
    public func bestImage(_ id: UUID) -> CGImage? {
        fm.fileExists(atPath: renderedURL(id).path) ? ImageFiles.load(renderedURL(id)) : original(id)
    }

    @discardableResult
    public func delete(_ id: UUID) throws -> URL? {
        var trashed: NSURL?
        try fm.trashItem(at: folder(id), resultingItemURL: &trashed)
        return trashed as URL?
    }

    /// Every word in the query must appear in the name, tags, app, summary or recognised text.
    public static func search(_ metas: [CaptureMeta], query: String) -> [CaptureMeta] {
        let words = query.lowercased().split(separator: " ").map(String.init).filter { !$0.isEmpty }
        guard !words.isEmpty else { return metas }
        return metas.filter { m in
            let hay = ([m.name, m.sourceApp ?? "", m.summary ?? "", m.ocrText] + m.tags.map { "#" + $0 + " " + $0 })
                .joined(separator: " ").lowercased()
            return words.allSatisfy { hay.contains($0) }
        }
    }
}
