import AppKit
import SwiftUI
import ZoomiesCore

struct AssistantPanel: View {
    @ObservedObject var model: EditorModel
    @ObservedObject var settings = AppSettings.shared
    @State private var prompt = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                TextField("Name", text: $model.meta.name).textFieldStyle(.roundedBorder).font(.headline)
                TextField("Tags (comma separated)", text: Binding(
                    get: { model.meta.tags.joined(separator: ", ") },
                    set: { model.meta.tags = $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }.filter { !$0.isEmpty } }
                )).textFieldStyle(.roundedBorder).font(.caption)
            }

            HStack {
                Label("Assistant", systemImage: "sparkles").font(.headline)
                Spacer()
                Text(settings.isAIConfigured ? settings.current.model : "Not set up")
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                Menu {
                    Button("Blur") { model.autoRedact(style: .blur) }
                    Button("Black boxes") { model.autoRedact(style: .redact) }
                } label: { Label("Auto-redact", systemImage: "eye.slash") }
                Button { model.extractText() } label: { Label("Copy text", systemImage: "text.viewfinder") }
                Button { model.summarize() } label: { Label("Summarize", systemImage: "text.alignleft") }
                Button { model.nameAndTag() } label: { Label("Name & tag", systemImage: "tag") }
            }
            .controlSize(.small)
            .disabled(model.busy)

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        if model.log.isEmpty {
                            Text("Ask for an edit, for example:\n• “Point an arrow at the Save button”\n• “Blur every email and face”\n• “Number the steps in the menu”\n• “Crop to the dialog”")
                                .font(.callout).foregroundStyle(.secondary)
                        }
                        ForEach(model.log) { e in
                            LogRow(entry: e).id(e.id)
                        }
                        if model.busy { ProgressView().controlSize(.small) }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                }
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .textBackgroundColor)))
                .onChange(of: model.log.count) { _, _ in if let last = model.log.last { proxy.scrollTo(last.id, anchor: .bottom) } }
            }

            HStack {
                TextField("Tell the assistant what to do…", text: $prompt, axis: .vertical)
                    .lineLimit(1...4)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(send)
                if model.busy {
                    Button { model.cancelAI() } label: { Image(systemName: "stop.circle.fill") }.buttonStyle(.borderless)
                } else {
                    Button(action: send) { Image(systemName: "arrow.up.circle.fill").font(.title2) }
                        .buttonStyle(.borderless).disabled(prompt.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            if !settings.isAIConfigured {
                Button("Set up AI in Settings…") { AppDelegate.shared?.showSettings() }.controlSize(.small)
            }
        }
        .padding(10)
    }

    private func send() {
        let p = prompt
        prompt = ""
        model.runAgent(p)
    }
}

struct LogRow: View {
    let entry: LogEntry
    var body: some View {
        switch entry.role {
        case .user:
            Text(entry.text).font(.callout.weight(.semibold)).padding(6)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.accentColor.opacity(0.15)))
        case .assistant:
            Text(entry.text).font(.callout).textSelection(.enabled)
        case .tool:
            Text(entry.text).font(.caption.monospaced()).foregroundStyle(.secondary).lineLimit(3)
        case .error:
            Label(entry.text, systemImage: "exclamationmark.triangle.fill").font(.callout).foregroundStyle(.red).textSelection(.enabled)
        }
    }
}

