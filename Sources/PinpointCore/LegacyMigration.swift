import Foundation

/// One-time carry-over of data saved while the app was called Zoomies (old IDs and paths below).
/// Copies settings and keys, and moves the library; old settings and Keychain items are left as a backup.
public enum LegacyMigration {
    public static let oldDefaultsDomain = "app.zoomies.Zoomies"
    public static let oldKeychainService = "app.zoomies.apikeys"
    static let doneKey = "migratedFromZoomies"

    public static var oldLibraryRoot: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Pictures/Zoomies", isDirectory: true)
    }

    public static func run(defaults: UserDefaults = .standard) {
        moveLibrary(from: oldLibraryRoot, to: LibraryStore.defaultRoot)
        guard !defaults.bool(forKey: doneKey) else { return }
        copyDefaults(defaults.persistentDomain(forName: oldDefaultsDomain), into: defaults)
        for account in Keychain.accounts(service: oldKeychainService) where Keychain.get(account).isEmpty {
            let value = Keychain.get(account, service: oldKeychainService)
            if !value.isEmpty { Keychain.set(value, for: account) }
        }
        defaults.set(true, forKey: doneKey)
    }

    /// Copies keys the new app doesn't have yet; window-frame keys follow the renamed autosave names.
    static func copyDefaults(_ old: [String: Any]?, into defaults: UserDefaults) {
        for (key, value) in old ?? [:] {
            let newKey = key.replacingOccurrences(of: "Zoomies", with: "Pinpoint")
            if defaults.object(forKey: newKey) == nil { defaults.set(value, forKey: newKey) }
        }
    }

    /// Renames the old library folder, or merges it in item by item if the new one already exists.
    /// Never overwrites: anything whose name is already taken stays in the old folder.
    @discardableResult
    static func moveLibrary(from old: URL, to new: URL, fm: FileManager = .default) -> Bool {
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: old.path, isDirectory: &isDir), isDir.boolValue else { return true }
        if !fm.fileExists(atPath: new.path) {
            do {
                try fm.createDirectory(at: new.deletingLastPathComponent(), withIntermediateDirectories: true)
                try fm.moveItem(at: old, to: new)
                return true
            } catch {
                NSLog("Pinpoint: could not move old library: \(error)")
                return false
            }
        }
        guard let items = try? fm.contentsOfDirectory(atPath: old.path) else { return false }
        var ok = true
        for name in items where name != ".DS_Store" {
            let dest = new.appendingPathComponent(name)
            if fm.fileExists(atPath: dest.path) { ok = false; continue }
            do { try fm.moveItem(at: old.appendingPathComponent(name), to: dest) } catch {
                NSLog("Pinpoint: could not move \(name) from old library: \(error)"); ok = false
            }
        }
        let left = (try? fm.contentsOfDirectory(atPath: old.path))?.filter { $0 != ".DS_Store" } ?? ["?"]
        if left.isEmpty { try? fm.removeItem(at: old) }
        return ok
    }
}
