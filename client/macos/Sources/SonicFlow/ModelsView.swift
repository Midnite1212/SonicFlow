import AppKit
import Observation
import SonicFlowCore
import SwiftUI

@MainActor
@Observable
final class ModelsModel {
    enum Tab: String, CaseIterable {
        case recommended, browse, mine

        var title: String {
            switch self {
            case .recommended: "Recommended"
            case .browse: "Browse"
            case .mine: "My Models"
            }
        }
    }

    var tab = Tab.recommended
    var list: ModelList?
    var message: String?
    var switching: String?
    var query = ""
    var searchKind = ModelInfo.Kind.cleanup
    var results: [HubSearch.Result] = []
    var searching = false
    var searched = false
    var repo = ""
    var ollama: OllamaStatus?
    @ObservationIgnored private var poller: Task<Void, Never>?

    func refresh() async {
        do {
            list = try await EngineAPI.models()
        } catch {
            message = "The engine isn't reachable. Restart it in Settings."
        }
        pollWhileWorking()
    }

    /// Downloads and benchmarks report progress only when asked, so poll once a second until none
    /// are running.
    private func pollWhileWorking() {
        guard list?.isWorking == true, poller == nil else { return }
        poller = Task { [weak self] in
            while let self, !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                if let list = try? await EngineAPI.models() { self.list = list }
                if self.list?.isWorking != true { break }
            }
            self?.poller = nil
        }
    }

    func download(_ model: ModelInfo) async {
        await perform { try await EngineAPI.download(model.id) }
    }

    func benchmark(_ model: ModelInfo) async {
        await perform { try await EngineAPI.benchmark(model.id) }
    }

    func use(_ model: ModelInfo) async {
        switching = model.id
        await perform {
            _ = try await EngineAPI.configure(
                asr: model.kind == .asr ? model.id : nil, cleanup: model.kind == .cleanup ? model.id : nil
            )
        }
        switching = nil
    }

    func remove(_ model: ModelInfo) async {
        await perform { try await EngineAPI.remove(model.id) }
        await loadOllama()
    }

    /// Adds a model and starts its download, so one click takes it from found to ready.
    func add(source: String, family: String? = nil) async {
        await perform {
            let model = try await EngineAPI.addModel(source: source, family: family)
            if !model.installed, model.hasFiles, !model.isLocalFolder, model.family != "ollama" {
                try await EngineAPI.download(model.id)
            }
            self.tab = .mine
        }
        if family == "ollama" { await loadOllama() }
        if !searched { return }
        await search()
    }

    func chooseFolder() async {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.prompt = "Add Model"
        panel.message = "Choose a folder with an MLX model: config.json and .safetensors weights."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        await add(source: url.path)
    }

    func search() async {
        let query = query.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return }
        searching = true
        do {
            results = try await EngineAPI.search(query, kind: searchKind).results
            searched = true
            message = nil
        } catch {
            message = error.localizedDescription
        }
        searching = false
    }

    func loadOllama() async {
        ollama = try? await EngineAPI.ollama()
    }

    private func perform(_ work: () async throws -> Void) async {
        message = nil
        do {
            try await work()
        } catch {
            message = error.localizedDescription
        }
        await refresh()
    }
}

struct ModelsView: View {
    @Bindable var model: ModelsModel

    var body: some View {
        Form {
            if let message = model.message {
                Section {
                    Label(message, systemImage: "exclamationmark.triangle.fill").foregroundStyle(Theme.alert)
                }
            }
            switch model.tab {
            case .recommended: recommended
            case .browse: browse
            case .mine: mine
            }
        }
        .settingsForm()
        .navigationTitle("Models")
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Section", selection: $model.tab) {
                    ForEach(ModelsModel.Tab.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }
        }
        .task {
            await model.refresh()
            await model.loadOllama()
        }
    }

    @ViewBuilder private var recommended: some View {
        if let list = model.list {
            ModelSection(title: "Speech recognition", models: list.models(in: .recommended, kind: .asr), store: model)
            Section {
                ModelRows(models: list.models(in: .recommended, kind: .cleanup), store: model, showsKind: false)
            } header: {
                Text("Cleanup")
            } footer: {
                Text("Release-to-text time and word error rate on the 21-clip test set, measured on an M3 Pro unless marked this Mac. Cleanup times include the speech model. Benchmark any installed model from its ⋯ menu.")
                    .font(.callout)
                    .foregroundStyle(Theme.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder private var browse: some View {
        if let list = model.list {
            ModelSection(title: "Speech recognition", models: list.models(in: .catalog, kind: .asr), store: model)
            ModelSection(title: "Cleanup", models: list.models(in: .catalog, kind: .cleanup), store: model)
        }
        Section {
            HStack(spacing: 10) {
                TextField("Search MLX models, e.g. whisper or llama", text: $model.query)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { Task { await model.search() } }
                Picker("Kind", selection: $model.searchKind) {
                    Text("Cleanup").tag(ModelInfo.Kind.cleanup)
                    Text("Speech").tag(ModelInfo.Kind.asr)
                }
                .labelsHidden()
                .fixedSize()
                Button("Search") { Task { await model.search() } }
                    .disabled(model.query.trimmingCharacters(in: .whitespaces).isEmpty || model.searching)
            }
            if model.searching {
                ProgressView().controlSize(.small)
            } else if model.searched && model.results.isEmpty {
                Text("No MLX models matched.").foregroundStyle(Theme.secondary)
            }
            ForEach(model.results) { result in
                LabeledContent {
                    if result.added {
                        Text("Added").foregroundStyle(Theme.tertiary)
                    } else {
                        Button("Add and Download") { Task { await model.add(source: result.source) } }
                            .controlSize(.small)
                    }
                } label: {
                    Text(result.source)
                    Text("\(result.family == "mlx-lm" ? "MLX" : result.family.capitalized) · \((result.downloads ?? 0).formatted()) downloads")
                }
            }
        } header: {
            Text("Search Hugging Face")
        } footer: {
            Text("Searching contacts Hugging Face. Only MLX builds are listed; they run on this Mac once downloaded.")
                .font(.callout)
                .foregroundStyle(Theme.tertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder private var mine: some View {
        Section("Add a model") {
            LabeledContent {
                Button("Choose Folder…") { Task { await model.chooseFolder() } }
            } label: {
                Text("Model folder on this Mac")
                Text("An MLX model you downloaded: a folder with config.json and .safetensors weights.")
            }
            LabeledContent {
                HStack {
                    TextField("org/model", text: $model.repo)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 220)
                        .onSubmit { Task { await addRepo() } }
                    Button("Add") { Task { await addRepo() } }
                        .disabled(!model.repo.contains("/"))
                }
            } label: {
                Text("Hugging Face repo")
                Text("Any MLX build, e.g. mlx-community/whisper-small-mlx. Downloads after adding.")
            }
            ollamaRows
        }
        if let list = model.list {
            let custom = list.models.filter { $0.group == .custom }
            Section("Your models") {
                if custom.isEmpty {
                    Text("Models you add appear here, ready to use for speech or cleanup.")
                        .foregroundStyle(Theme.secondary)
                } else {
                    ModelRows(models: custom, store: model, showsKind: true)
                }
            }
        }
    }

    @ViewBuilder private var ollamaRows: some View {
        let ollama = model.ollama
        LabeledContent {
            Button("Refresh") { Task { await model.loadOllama() } }
        } label: {
            Text("Ollama")
            if let ollama, ollama.running {
                Text(ollama.models.isEmpty ? "Ollama is running but has no models. Pull one with `ollama pull`." : "Cleanup models you pulled in Ollama.")
            } else {
                Text("Ollama isn't running. Install it from ollama.com or open the app, then refresh.")
            }
        }
        if let ollama, ollama.running {
            ForEach(ollama.models) { pulled in
                LabeledContent {
                    if pulled.added {
                        Text("Added").foregroundStyle(Theme.tertiary)
                    } else {
                        Button("Add") { Task { await model.add(source: pulled.name, family: "ollama") } }
                            .controlSize(.small)
                    }
                } label: {
                    Text(pulled.name)
                    if let size = ModelInfo.size(pulled.size) { Text(size) }
                }
            }
        }
    }

    private func addRepo() async {
        let repo = model.repo.trimmingCharacters(in: .whitespaces)
        guard repo.contains("/") else { return }
        await model.add(source: repo)
        if model.message == nil { model.repo = "" }
    }
}

private struct ModelSection: View {
    let title: String
    let models: [ModelInfo]
    let store: ModelsModel

    var body: some View {
        Section(title) {
            ModelRows(models: models, store: store, showsKind: false)
        }
    }
}

private struct ModelRows: View {
    let models: [ModelInfo]
    let store: ModelsModel
    let showsKind: Bool

    var body: some View {
        ForEach(models) { model in
            ModelRow(model: model, store: store, showsKind: showsKind)
        }
    }
}

private struct ModelRow: View {
    let model: ModelInfo
    let store: ModelsModel
    let showsKind: Bool

    var body: some View {
        let isActive = store.list?.isActive(model) ?? false
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(model.title).foregroundStyle(Theme.text)
                    Text(details).font(.callout).foregroundStyle(Theme.tertiary)
                }
                if !model.note.isEmpty {
                    Text(model.note).font(.callout).foregroundStyle(Theme.secondary)
                }
                if model.isLocalFolder {
                    Text(model.source).font(.caption).foregroundStyle(Theme.tertiary).lineLimit(1).truncationMode(.middle)
                }
                if let benchmark = model.benchmark, benchmark.isRunning {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Benchmarking on this Mac…").foregroundStyle(Theme.secondary)
                    }
                    .font(.callout)
                } else if let bench = model.bench {
                    HStack(spacing: 10) {
                        SpeedStripe(ms: bench.p50Ms, height: 4).frame(width: 140)
                        Text(Format.ms(bench.p50Ms)).monospacedDigit()
                            .foregroundStyle(Theme.Speed(ms: bench.p50Ms).text)
                        Text("\((bench.wer * 100).formatted(.number.precision(.fractionLength(1))))% word errors\(bench.isLocal ? " · this Mac" : "")")
                            .foregroundStyle(Theme.tertiary)
                    }
                    .font(.callout)
                }
                if let benchmark = model.benchmark, let error = benchmark.error {
                    Text("Benchmark failed: \(error)").font(.callout).foregroundStyle(Theme.alert).lineLimit(2)
                }
            }
            Spacer(minLength: 12)
            action(isActive: isActive)
                .controlSize(.small)
            if model.installed || model.group == .custom {
                Menu {
                    if model.installed {
                        Button("Benchmark on This Mac") { Task { await store.benchmark(model) } }
                            .disabled(model.benchmark?.isRunning ?? false)
                    }
                    if isActive || !model.hasFiles {
                        EmptyView()
                    } else if model.group == .custom {
                        Button(model.isLocalFolder || model.family == "ollama" ? "Remove from SonicFlow" : "Remove and Delete Download", role: .destructive) {
                            Task { await store.remove(model) }
                        }
                    } else {
                        Button("Delete Download", role: .destructive) { Task { await store.remove(model) } }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .tint(Theme.secondary)
                .fixedSize()
            }
        }
        .padding(.vertical, 4)
    }

    private var details: String {
        var parts = [model.familyTitle]
        if showsKind { parts.insert(model.kind == .asr ? "Speech" : "Cleanup", at: 0) }
        if let size = ModelInfo.size(model.sizeBytes) { parts.append(size) }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder private func action(isActive: Bool) -> some View {
        switch model.action(isActive: isActive) {
        case .inUse:
            Label("In use", systemImage: "checkmark.circle.fill").foregroundStyle(Theme.ready)
        case .use:
            if store.switching == model.id {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("Loading…").foregroundStyle(Theme.secondary)
                }
            } else {
                Button("Use") { Task { await store.use(model) } }
                    .disabled(store.switching != nil)
            }
        case .download:
            Button("Download") { Task { await store.download(model) } }
        case let .downloading(fraction):
            HStack(spacing: 8) {
                ProgressView(value: fraction ?? 0).frame(width: 110)
                Text(fraction.map { "\(Int($0 * 100))%" } ?? "Starting…")
                    .monospacedDigit().foregroundStyle(Theme.secondary).frame(width: 64, alignment: .trailing)
            }
        case let .failed(reason):
            VStack(alignment: .trailing, spacing: 2) {
                Button("Retry Download") { Task { await store.download(model) } }
                Text(reason).font(.caption).foregroundStyle(Theme.alert).lineLimit(1)
            }
        case .unavailable:
            Text(model.family == "ollama" ? "Not in Ollama" : "Folder missing").foregroundStyle(Theme.tertiary)
        }
    }
}
