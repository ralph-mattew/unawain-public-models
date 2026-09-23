import SwiftUI
import UIKit

@main
struct CoreMLBenchApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}

/// Drives BenchCore on device. Model packages are copied into the app bundle at build
/// time (see the "Bundle model packages" build phase). State and results live in
/// Documents, which is visible in the Files app and in Finder while the phone is connected.
@MainActor
final class BenchViewModel: ObservableObject {
    @Published var lines: [String] = []
    @Published var running = false
    @Published var results: [URL] = []
    @Published var interrupted: String?

    let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    let modelURLs: [URL]
    let runner: BenchRunner

    init() {
        let dir = Bundle.main.resourceURL!.appendingPathComponent("Models")
        modelURLs = ((try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.pathExtension == "mlpackage" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let relay = LogRelay()
        runner = BenchRunner(stateURL: docs.appendingPathComponent("bench-state.json"),
                             compiledDir: caches.appendingPathComponent("compiled"),
                             modelURLs: modelURLs,
                             log: { line in Task { @MainActor in relay.vm?.lines.append(line) } })
        relay.vm = self
        refresh()
    }

    var canResume: Bool { runner.loadState().map { !$0.isDone } ?? false }

    func refresh() {
        results = ((try? FileManager.default.contentsOfDirectory(at: docs, includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.lastPathComponent.hasPrefix("coreml-latency-") }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
        if let s = runner.loadState(), !s.isDone, let job = s.inProgress {
            interrupted = "\(s.config.artifacts[job.model]) [\(job.computeUnits)] was running when the app stopped. Resume records it as failed and continues."
        } else {
            interrupted = nil
        }
    }

    func run(fresh: Bool) {
        guard !running else { return }
        running = true
        interrupted = nil
        UIApplication.shared.isIdleTimerDisabled = true
        let artifacts = modelURLs.map(\.lastPathComponent)
        Task.detached { [runner, docs] in
            do {
                if fresh { try await runner.start(BenchConfig(artifacts: artifacts)) }
                let state = try await runner.resume()
                let stamp = state.result.hostBefore.timestampUtc.replacingOccurrences(of: ":", with: "")
                let out = docs.appendingPathComponent("coreml-latency-\(state.result.hostBefore.deviceModel)-\(stamp).json")
                try runner.writeResult(state, to: out)
                try? FileManager.default.removeItem(at: runner.stateURL)
                await MainActor.run { self.lines.append("Wrote \(out.lastPathComponent)") }
            } catch {
                await MainActor.run { self.lines.append("Error: \(error)") }
            }
            await MainActor.run {
                self.running = false
                UIApplication.shared.isIdleTimerDisabled = false
                self.refresh()
            }
        }
    }
}

/// Lets the runner's background log callback reach the view model on the main actor.
final class LogRelay: @unchecked Sendable {
    weak var vm: BenchViewModel?
}

struct ContentView: View {
    @StateObject private var vm = BenchViewModel()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Keep the app in the foreground until it finishes. If it crashes, reopen it and tap Resume.")
                        .font(.footnote)
                    if let note = vm.interrupted {
                        Text(note).font(.footnote).foregroundStyle(.orange)
                    }
                    if vm.canResume {
                        Button("Resume run") { vm.run(fresh: false) }.disabled(vm.running)
                    }
                    Button(vm.canResume ? "Discard and start over" : "Start run") { vm.run(fresh: true) }
                        .disabled(vm.running || vm.modelURLs.isEmpty)
                    if vm.running { ProgressView() }
                } header: {
                    Text("\(vm.modelURLs.count) model packages bundled")
                }

                if !vm.results.isEmpty {
                    Section("Results") {
                        ForEach(vm.results, id: \.self) { url in
                            ShareLink(item: url) { Label(url.lastPathComponent, systemImage: "square.and.arrow.up") }
                                .font(.footnote)
                        }
                    }
                }

                Section("Log") {
                    ForEach(Array(vm.lines.enumerated()), id: \.offset) { _, line in
                        Text(line).font(.caption.monospaced())
                    }
                }
            }
            .navigationTitle("Core ML Bench")
        }
        .onAppear {
            // `-autorun` (Xcode scheme or devicectl) starts or resumes without a tap.
            guard ProcessInfo.processInfo.arguments.contains("-autorun"), !vm.running else { return }
            vm.run(fresh: !vm.canResume)
        }
    }
}
