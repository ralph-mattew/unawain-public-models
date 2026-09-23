// coreml-bench: macOS front end for BenchCore.
//
//   swift run -c release coreml-bench \
//     --model ../../artifacts/NllbEncoder.mlpackage --model ../../artifacts/NllbDecoderStep.mlpackage \
//     --out ../results/<run-id>.json
//
// The parent process re-launches itself as a child until every (model, compute-units)
// job is done. A child that crashes (e.g. the MPSGraph abort from experiment 001) leaves
// its job marked in-progress; the parent attaches the crash line and the next child
// records the job as failed. The iOS app uses the same state file, resumed by relaunching.
import BenchCore
import Foundation

struct Args {
    var models: [URL] = []
    var computeUnits = ComputeUnits.all
    var warmup = 10
    var iters = 100
    var activeLen = 64
    var seed: UInt64 = 0
    var release = "v0.1.0"
    var out: URL?
    var child = false

    static func parse(_ argv: [String]) -> Args {
        var a = Args()
        var i = 0
        func value() -> String {
            i += 1
            guard i < argv.count else { fail("missing value for \(argv[i - 1])") }
            return argv[i]
        }
        while i < argv.count {
            switch argv[i] {
            case "--model": a.models.append(URL(fileURLWithPath: value()).standardizedFileURL)
            case "--compute-units":
                a.computeUnits = []
                while i + 1 < argv.count, !argv[i + 1].hasPrefix("--") { a.computeUnits.append(value()) }
            case "--warmup": a.warmup = Int(value()) ?? a.warmup
            case "--iters": a.iters = Int(value()) ?? a.iters
            case "--active-len": a.activeLen = Int(value()) ?? a.activeLen
            case "--seed": a.seed = UInt64(value()) ?? a.seed
            case "--release": a.release = value()
            case "--out": a.out = URL(fileURLWithPath: value()).standardizedFileURL
            case "--_child": a.child = true
            case "-h", "--help":
                print("usage: coreml-bench --model PKG [--model PKG ...] --out FILE [--compute-units ALL CPU_ONLY CPU_AND_GPU CPU_AND_NE] [--warmup 10] [--iters 100] [--active-len 64] [--seed 0] [--release v0.1.0]")
                exit(0)
            default: fail("unknown argument \(argv[i])")
            }
            i += 1
        }
        if a.models.isEmpty || a.out == nil { fail("--model and --out are required (see --help)") }
        return a
    }
}

func fail(_ msg: String) -> Never {
    FileHandle.standardError.write(Data("coreml-bench: \(msg)\n".utf8))
    exit(2)
}

let args = Args.parse(Array(CommandLine.arguments.dropFirst()))
let out = args.out!
let stateURL = out.deletingPathExtension().appendingPathExtension("state.json")
let runner = BenchRunner(
    stateURL: stateURL,
    compiledDir: FileManager.default.temporaryDirectory.appendingPathComponent("coreml-bench-compiled"),
    modelURLs: args.models,
    log: { print($0); fflush(stdout) })

if args.child {
    // One job per process: cold loads and a clean memory baseline for every setting.
    _ = try await runner.resume(maxJobs: 1)
    exit(0)
}

let config = BenchConfig(artifacts: args.models.map(\.lastPathComponent), computeUnits: args.computeUnits,
                         warmup: args.warmup, iters: args.iters, activeLen: args.activeLen,
                         seed: args.seed, release: args.release)
var state = try await runner.start(config)
let maxAttempts = 2 * state.jobs.count + 2

for _ in 0..<maxAttempts {
    let p = Process()
    p.executableURL = Bundle.main.executableURL
    p.arguments = Array(CommandLine.arguments.dropFirst()) + ["--_child"]
    let err = Pipe()
    p.standardError = err
    try p.run()
    let errData = err.fileHandleForReading.readDataToEndOfFile()
    p.waitUntilExit()

    guard var s = runner.loadState() else { fail("state file disappeared") }
    if s.isDone { state = s; break }
    if p.terminationStatus != 0, s.inProgress != nil {
        let lines = (String(data: errData, encoding: .utf8) ?? "").split(separator: "\n")
        let hit = lines.last { $0.localizedCaseInsensitiveContains("assert") || $0.localizedCaseInsensitiveContains("error") }
        let how = p.terminationReason == .uncaughtSignal ? "signal \(p.terminationStatus)" : "exit \(p.terminationStatus)"
        s.crashNote = "process terminated (\(how))" + (hit.map { ": " + $0.trimmingCharacters(in: .whitespaces) } ?? "")
        try runner.save(s)
    }
    state = s
}

guard state.isDone else { fail("stopped after \(maxAttempts) attempts; state kept at \(stateURL.path)") }
try runner.writeResult(state, to: out)
try? FileManager.default.removeItem(at: stateURL)
print("wrote \(out.path)")
