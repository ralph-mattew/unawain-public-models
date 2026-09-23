import CoreML
import CryptoKit
import Foundation

public enum ComputeUnits {
    public static let all = ["ALL", "CPU_ONLY", "CPU_AND_GPU", "CPU_AND_NE"]

    static func parse(_ name: String) -> MLComputeUnits? {
        switch name {
        case "ALL": return .all
        case "CPU_ONLY": return .cpuOnly
        case "CPU_AND_GPU": return .cpuAndGPU
        case "CPU_AND_NE": return .cpuAndNeuralEngine
        default: return nil
        }
    }
}

public enum BenchError: Error, CustomStringConvertible {
    case missingArtifact(String)
    case unsupportedInput(String)

    public var description: String {
        switch self {
        case .missingArtifact(let name): return "artifact not found: \(name)"
        case .unsupportedInput(let name): return "input \(name) is not a multi-array"
        }
    }
}

/// Runs a benchmark as a list of (model, compute-units) jobs, saving state before and
/// after each one. If the process dies mid-job, the next `resume()` records that job as
/// failed and continues, which is how a Core ML crash is captured on iOS (no child processes).
public final class BenchRunner: @unchecked Sendable {
    public let stateURL: URL
    let compiledDir: URL
    let models: [String: URL]
    let log: @Sendable (String) -> Void

    /// - Parameters:
    ///   - modelURLs: `.mlpackage` locations, matched to `config.artifacts` by file name.
    ///   - compiledDir: cache for compiled `.mlmodelc` bundles (cleared on a fresh start).
    public init(stateURL: URL, compiledDir: URL, modelURLs: [URL], log: @escaping @Sendable (String) -> Void) {
        self.stateURL = stateURL
        self.compiledDir = compiledDir
        self.models = Dictionary(modelURLs.map { ($0.lastPathComponent, $0) }, uniquingKeysWith: { a, _ in a })
        self.log = log
    }

    // MARK: State

    public func loadState() -> BenchState? {
        guard let data = try? Data(contentsOf: stateURL) else { return nil }
        return try? JSON.decoder().decode(BenchState.self, from: data)
    }

    public func save(_ state: BenchState) throws {
        try FileManager.default.createDirectory(at: stateURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSON.encoder().encode(state).write(to: stateURL, options: .atomic)
    }

    /// Discards any previous state and compiled cache, and records starting conditions.
    @discardableResult
    public func start(_ config: BenchConfig) async throws -> BenchState {
        try? FileManager.default.removeItem(at: compiledDir)
        let host = await DeviceConditions.capture()
        let method = Method(warmup: config.warmup, iters: config.iters, activeLen: config.activeLen, seed: config.seed)
        let run = BenchRun(hostBefore: host, release: config.release, method: method,
                           models: config.artifacts.map { ModelEntry(artifact: $0) }, hostAfter: nil)
        let state = BenchState(config: config, result: run)
        try save(state)
        return state
    }

    /// Runs remaining jobs (at most `maxJobs`, if given). ``BenchState/isDone`` is true on completion.
    public func resume(maxJobs: Int = .max) async throws -> BenchState {
        guard var state = loadState() else { throw CocoaError(.fileNoSuchFile) }

        if let job = state.inProgress {
            let note = state.crashNote ?? "process ended while this setting was running (crash, jetsam, or forced quit); check the device crash log"
            log("\(state.config.artifacts[job.model]) [\(job.computeUnits)] did not finish: \(note)")
            state.result.models[job.model].runs.append(.failure(job.computeUnits, note))
            state.inProgress = nil
            state.crashNote = nil
            state.nextJob += 1
            state.resumeCount += 1
            try save(state)
        }

        let jobs = state.jobs
        var ran = 0
        while state.nextJob < jobs.count, ran < maxJobs {
            ran += 1
            let job = jobs[state.nextJob]
            let name = state.config.artifacts[job.model]
            state.inProgress = job
            try save(state)

            if state.result.models[job.model].packageSha256 == nil, state.result.models[job.model].setupError == nil {
                log("\(name): hashing and compiling ...")
                state.result.models[job.model] = await setUp(name, entry: state.result.models[job.model])
                try save(state)
            }

            log("\(name) [\(job.computeUnits)] ...")
            var result: RunResult
            if let err = state.result.models[job.model].setupError {
                result = .failure(job.computeUnits, "setup failed: \(err)")
            } else {
                let (r, io) = await bench(name, job.computeUnits, state.config)
                result = r
                if state.result.models[job.model].io == nil { state.result.models[job.model].io = io }
            }
            if result.failed == true {
                log("  FAILED: \(result.error ?? "")")
            } else {
                log(String(format: "  load %.2fs  p50 %.2fms  p95 %.2fms  thermal %@",
                           result.loadS ?? 0, result.p50Ms ?? 0, result.p95Ms ?? 0, result.thermalAfter ?? "?"))
            }
            state.result.models[job.model].runs.append(result)
            state.inProgress = nil
            state.nextJob += 1
            try save(state)
        }
        if state.nextJob < jobs.count { return state }

        // Op placement last, so the timed loads above were not warmed by it.
        for m in state.result.models.indices where state.result.models[m].setupError == nil {
            if state.result.models[m].computePlan?.note == Self.planStarted {
                state.result.models[m].computePlan?.note = "compute plan did not finish (process ended)"
                try save(state)
            }
            guard state.result.models[m].computePlan == nil else { continue }
            log("\(state.config.artifacts[m]): reading compute plan ...")
            var marker = ComputePlanSummary()
            marker.note = Self.planStarted
            state.result.models[m].computePlan = marker
            try save(state)
            state.result.models[m].computePlan = await computePlan(compiledURL(state.config.artifacts[m]))
            try save(state)
        }

        if state.result.hostAfter == nil {
            state.result.hostAfter = await DeviceConditions.capture()
            try save(state)
        }
        return state
    }

    public func writeResult(_ state: BenchState, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        var data = try JSON.encoder().encode(state.result)
        data.append(0x0A)
        try data.write(to: url, options: .atomic)
    }

    // MARK: Per-model setup

    func compiledURL(_ name: String) -> URL {
        compiledDir.appendingPathComponent((name as NSString).deletingPathExtension + ".mlmodelc")
    }

    func setUp(_ name: String, entry: ModelEntry) async -> ModelEntry {
        var entry = entry
        guard let src = models[name] else {
            entry.setupError = BenchError.missingArtifact(name).description
            return entry
        }
        do {
            entry.packageSizeMb = (Double(try Package.sizeBytes(src)) / 1e5).rounded() / 10
            entry.packageSha256 = try Package.sha256(src)

            let t0 = now()
            let tmp = try await MLModel.compileModel(at: src)
            entry.compileS = round2(now() - t0)
            let dest = compiledURL(name)
            try FileManager.default.createDirectory(at: compiledDir, withIntermediateDirectories: true)
            try? FileManager.default.removeItem(at: dest)
            try FileManager.default.moveItem(at: tmp, to: dest)
        } catch {
            entry.setupError = "\(error)"
        }
        return entry
    }

    static let planStarted = "started"

    func computePlan(_ compiled: URL) async -> ComputePlanSummary {
        var s = ComputePlanSummary()
        do {
            let cfg = MLModelConfiguration()
            cfg.computeUnits = .all
            let plan = try await MLComputePlan.load(contentsOf: compiled, configuration: cfg)
            guard case .program(let program) = plan.modelStructure else {
                s.note = "not an ML program; op placement unavailable"
                return s
            }
            func visit(_ block: MLModelStructure.Program.Block) {
                for op in block.operations {
                    if let usage = plan.deviceUsage(for: op) {
                        s.operations += 1
                        switch usage.preferred {
                        case .cpu: s.preferredCpu += 1
                        case .gpu: s.preferredGpu += 1
                        case .neuralEngine: s.preferredNeuralEngine += 1
                        @unknown default: break
                        }
                        for device in usage.supported {
                            switch device {
                            case .neuralEngine: s.supportedNeuralEngine += 1
                            case .gpu: s.supportedGpu += 1
                            default: break
                            }
                        }
                    } else {
                        s.operationsWithoutUsage += 1
                    }
                    op.blocks.forEach(visit)
                }
            }
            program.functions.values.forEach { visit($0.block) }
        } catch {
            s.note = "compute plan failed: \(error)"
        }
        return s
    }

    // MARK: Timing

    func bench(_ name: String, _ cuName: String, _ config: BenchConfig) async -> (RunResult, IODescription?) {
        let thermalBefore = DeviceConditions.thermalState()
        guard let cu = ComputeUnits.parse(cuName) else {
            return (.failure(cuName, "unknown compute units", thermalBefore: thermalBefore), nil)
        }
        let compiled = compiledURL(name)
        let cfg = MLModelConfiguration()
        cfg.computeUnits = cu

        do {
            var r = RunResult(computeUnits: cuName)
            r.thermalBefore = thermalBefore
            r.footprintBeforeLoadMb = footprintMB()

            // Fresh instance: cold load for this compute-units setting, then the first call.
            let (inputs, io) = try autoreleasepool { () throws -> (MLDictionaryFeatureProvider, IODescription) in
                var t0 = now()
                let model = try MLModel(contentsOf: compiled, configuration: cfg)
                r.loadS = round2(now() - t0)
                let inputs = try Inputs.synthetic(model.modelDescription, seed: config.seed, activeLen: config.activeLen)
                t0 = now()
                _ = try model.prediction(from: inputs)
                r.firstCallMs = round2((now() - t0) * 1e3)
                return (inputs, describe(model.modelDescription))
            }

            // Second instance: warm (cached) load, then warmup and timed calls.
            var t0 = now()
            let warm = try MLModel(contentsOf: compiled, configuration: cfg)
            r.reloadS = round2(now() - t0)

            for _ in 0..<config.warmup {
                _ = try autoreleasepool { try warm.prediction(from: inputs) }
            }
            r.footprintAfterLoadMb = footprintMB()
            var times: [Double] = []
            times.reserveCapacity(config.iters)
            for _ in 0..<config.iters {
                t0 = now()
                _ = try autoreleasepool { try warm.prediction(from: inputs) }
                times.append((now() - t0) * 1e3)
            }

            let st = Stats(times)
            r.p50Ms = round2(st.percentile(50))
            r.p95Ms = round2(st.percentile(95))
            r.meanMs = round2(st.mean)
            r.stdevMs = round2(st.stdev)
            r.minMs = round2(st.min)
            r.maxMs = round2(st.max)
            r.iters = config.iters
            r.warmup = config.warmup
            r.footprintAfterRunMb = footprintMB()
            r.thermalAfter = DeviceConditions.thermalState()
            return (r, io)
        } catch {
            return (.failure(cuName, "\(error)", thermalBefore: thermalBefore), nil)
        }
    }

    func describe(_ d: MLModelDescription) -> IODescription {
        func features(_ dict: [String: MLFeatureDescription]) -> [IOFeature] {
            dict.values.sorted { $0.name < $1.name }.map { f in
                let c = f.multiArrayConstraint
                return IOFeature(name: f.name, shape: c?.shape.map(\.intValue) ?? [],
                                 dtype: c.map { Inputs.dtypeName($0.dataType) } ?? "NON_ARRAY")
            }
        }
        return IODescription(inputs: features(d.inputDescriptionsByName), outputs: features(d.outputDescriptionsByName))
    }
}

func now() -> Double { Double(DispatchTime.now().uptimeNanoseconds) / 1e9 }
func round2(_ x: Double) -> Double { (x * 100).rounded() / 100 }

// MARK: - Statistics (percentiles use linear interpolation, like numpy's default)

struct Stats {
    let sorted: [Double]
    init(_ values: [Double]) { sorted = values.sorted() }
    var min: Double { sorted.first ?? .nan }
    var max: Double { sorted.last ?? .nan }
    var mean: Double { sorted.reduce(0, +) / Double(sorted.count) }
    var stdev: Double {
        guard sorted.count > 1 else { return 0 }
        let m = mean
        return (sorted.reduce(0) { $0 + ($1 - m) * ($1 - m) } / Double(sorted.count - 1)).squareRoot()
    }
    func percentile(_ q: Double) -> Double {
        guard !sorted.isEmpty else { return .nan }
        let pos = q / 100 * Double(sorted.count - 1)
        let lo = Int(pos.rounded(.down)), hi = Int(pos.rounded(.up))
        return sorted[lo] + (sorted[hi] - sorted[lo]) * (pos - Double(lo))
    }
}

// MARK: - Synthetic inputs (same conventions as bench_coreml_latency.py)

enum Inputs {
    /// SplitMix64: small, seedable, identical on every platform.
    struct RNG {
        var state: UInt64
        mutating func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }
        mutating func unit() -> Double { Double(next() >> 11) / Double(1 << 53) }
        mutating func gaussian() -> Double {
            (-2 * log(max(unit(), .leastNonzeroMagnitude))).squareRoot() * cos(2 * .pi * unit())
        }
    }

    static func synthetic(_ desc: MLModelDescription, seed: UInt64, activeLen: Int) throws -> MLDictionaryFeatureProvider {
        var rng = RNG(state: seed)
        var feeds: [String: MLFeatureValue] = [:]
        for (name, f) in desc.inputDescriptionsByName.sorted(by: { $0.key < $1.key }) {
            guard let c = f.multiArrayConstraint else { throw BenchError.unsupportedInput(name) }
            let arr = try MLMultiArray(shape: c.shape, dataType: c.dataType)
            let last = max(c.shape.last?.intValue ?? 1, 1)
            let lname = name.lowercased()
            let isInt = c.dataType == .int32
            for i in 0..<arr.count {
                let v: Double
                if lname.contains("mask") {
                    v = i % last < activeLen ? 1 : 0
                } else if lname.contains("ids") || lname.contains("token") {
                    v = Double(4 + rng.next() % 996)  // low ids exist in full and pruned vocabularies
                } else if lname.contains("pos") {
                    v = Double(activeLen - 1)
                } else if isInt {
                    v = 0
                } else {
                    v = rng.gaussian() * 0.1
                }
                arr[i] = NSNumber(value: v)
            }
            feeds[name] = MLFeatureValue(multiArray: arr)
        }
        return try MLDictionaryFeatureProvider(dictionary: feeds)
    }

    static func dtypeName(_ t: MLMultiArrayDataType) -> String {
        switch t {
        case .int32: return "INT32"
        case .float32: return "FLOAT32"
        case .float16: return "FLOAT16"
        case .double: return "DOUBLE"
        default: return "OTHER(\(t.rawValue))"
        }
    }
}

// MARK: - Package hashing (same algorithm as scripts/build_manifest.py)

enum Package {
    static func files(_ root: URL) throws -> [(rel: [String], url: URL)] {
        let base = root.standardizedFileURL.pathComponents
        guard let e = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey]) else { return [] }
        var out: [(rel: [String], url: URL)] = []
        for case let url as URL in e where try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true {
            out.append((Array(url.standardizedFileURL.pathComponents.dropFirst(base.count)), url))
        }
        // Python sorts Path objects component-wise; match that (not whole-string order).
        return out.sorted { $0.rel.lexicographicallyPrecedes($1.rel) }
    }

    static func sha256(_ root: URL) throws -> String {
        var h = SHA256()
        for f in try files(root) {
            h.update(data: Data(f.rel.joined(separator: "/").utf8))
            let fh = try FileHandle(forReadingFrom: f.url)
            defer { try? fh.close() }
            while try autoreleasepool(invoking: { () throws -> Bool in
                guard let chunk = try fh.read(upToCount: 1 << 20), !chunk.isEmpty else { return false }
                h.update(data: chunk)
                return true
            }) {}
        }
        return h.finalize().map { String(format: "%02x", $0) }.joined()
    }

    static func sizeBytes(_ root: URL) throws -> Int {
        try files(root).reduce(0) { $0 + ((try? $1.url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) }
    }
}
