import Carbon
import Foundation

/// System-wide shortcuts via Carbon's RegisterEventHotKey (no Accessibility permission needed).
final class HotKeyCenter {
    static let shared = HotKeyCenter()
    private var handlers: [UInt32: () -> Void] = [:]
    private var refs: [EventHotKeyRef?] = []
    private var installed = false

    func register(keyCode: Int, modifiers: Int, id: UInt32, handler: @escaping () -> Void) {
        installIfNeeded()
        handlers[id] = handler
        var ref: EventHotKeyRef?
        let hkID = EventHotKeyID(signature: OSType(0x504E5054) /* 'PNPT' */, id: id)
        let status = RegisterEventHotKey(UInt32(keyCode), UInt32(modifiers), hkID, GetApplicationEventTarget(), 0, &ref)
        if status == noErr { refs.append(ref) } else { NSLog("Pinpoint: hotkey \(id) unavailable (\(status))") }
    }

    private func installIfNeeded() {
        guard !installed else { return }
        installed = true
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var hk = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
                              MemoryLayout<EventHotKeyID>.size, nil, &hk)
            let id = hk.id
            DispatchQueue.main.async { HotKeyCenter.shared.handlers[id]?() }
            return noErr
        }, 1, &spec, nil, nil)
    }
}
