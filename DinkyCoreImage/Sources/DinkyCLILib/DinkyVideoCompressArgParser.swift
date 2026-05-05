import DinkyCoreShared
import DinkyCoreVideo
import Foundation

public struct DinkyVideoCompressParseResult: Sendable {
    public var options: DinkyVideoCompressOptions
    public var paths: [String]
    public var explicit: Set<String>
    public var preset: PresetCLIRef

    public init(options: DinkyVideoCompressOptions, paths: [String], explicit: Set<String>, preset: PresetCLIRef) {
        self.options = options
        self.paths = paths
        self.explicit = explicit
        self.preset = preset
    }
}

public enum DinkyVideoCompressArgParser {
    public static func parse(_ args: [String]) throws -> DinkyVideoCompressParseResult {
        var o = DinkyVideoCompressOptions()
        var files: [String] = []
        var explicit: Set<String> = []
        var preset = PresetCLIRef()
        var i = 0
        let n = args.count
        while i < n {
            let a = args[i]
            if a == "--" {
                files.append(contentsOf: args[(i + 1)...].map { $0 })
                break
            }
            if a == "-h" || a == "--help" {
                throw DinkyCLIParseError(message: "help: use: dinky compress-video <files> [options]")
            }
            if a.hasPrefix("-") {
                switch a {
                case "--preset":
                    i += 1
                    guard i < n else { throw DinkyCLIParseError(message: "missing value for --preset") }
                    preset.name = args[i]
                case "--preset-id":
                    i += 1
                    guard i < n, let u = UUID(uuidString: args[i]) else {
                        throw DinkyCLIParseError(message: "invalid --preset-id (expected UUID)")
                    }
                    preset.id = u
                case "--preset-file":
                    i += 1
                    guard i < n else { throw DinkyCLIParseError(message: "missing value for --preset-file") }
                    preset.file = args[i]
                case "-q", "--quality":
                    i += 1
                    guard i < n else { throw DinkyCLIParseError(message: "missing value for --quality") }
                    o.quality = try parseVideoQuality(args[i])
                    explicit.insert("quality")
                case "--codec":
                    i += 1
                    guard i < n else { throw DinkyCLIParseError(message: "missing value for --codec") }
                    let c = args[i].lowercased()
                    if c == "prores" {
                        throw DinkyCLIParseError(message: "ProRes is not supported in Dinky; use --codec h264 or hevc")
                    }
                    guard let codec = VideoCodecFamily(rawValue: c) else {
                        throw DinkyCLIParseError(message: "unknown --codec (use h264 or hevc)")
                    }
                    o.codec = codec
                    explicit.insert("codec")
                case "--remove-audio":
                    o.removeAudio = true
                    explicit.insert("removeAudio")
                case "--keep-audio":
                    o.removeAudio = false
                    explicit.insert("removeAudio")
                case "--max-height":
                    i += 1
                    guard i < n, let h = Int(args[i]), h > 0 else { throw DinkyCLIParseError(message: "invalid --max-height") }
                    o.maxResolutionLines = h
                    explicit.insert("maxHeight")
                case "--max-fps":
                    i += 1
                    guard i < n, let f = Int(args[i]), VideoFPSCapPreset.allowedValues.contains(f) else {
                        throw DinkyCLIParseError(message: "invalid --max-fps (use 60, 30, 24, or 15)")
                    }
                    o.fpsCapEnabled = true
                    o.fpsCap = f
                    explicit.insert("maxFps")
                case "--no-fps-cap":
                    o.fpsCapEnabled = false
                    explicit.insert("maxFps")
                case "--no-smart-quality":
                    o.smartQuality = false
                    explicit.insert("smartQuality")
                case "--smart-quality":
                    o.smartQuality = true
                    explicit.insert("smartQuality")
                case "-o", "--output-dir":
                    i += 1
                    guard i < n else { throw DinkyCLIParseError(message: "missing --output-dir path") }
                    o.outputDir = URL(fileURLWithPath: args[i], isDirectory: true)
                    explicit.insert("outputDir")
                case "--json":
                    o.json = true
                case "--collision-style":
                    i += 1
                    guard i < n else { throw DinkyCLIParseError(message: "missing --collision-style") }
                    guard let s = CollisionNamingStyle(rawValue: args[i]) else {
                        throw DinkyCLIParseError(message: "unknown --collision-style")
                    }
                    o.collisionStyle = s
                    explicit.insert("collisionStyle")
                case "--collision-pattern":
                    i += 1
                    guard i < n else { throw DinkyCLIParseError(message: "missing --collision-pattern") }
                    o.collisionCustomPattern = args[i]
                    explicit.insert("collisionCustom")
                default:
                    throw DinkyCLIParseError(message: "unknown option: \(a)")
                }
            } else {
                files.append(a)
            }
            i += 1
        }
        return DinkyVideoCompressParseResult(options: o, paths: files, explicit: explicit, preset: preset)
    }

    private static func parseVideoQuality(_ raw: String) throws -> VideoQuality {
        let t = raw.lowercased()
        if t == "low" { return .medium }
        if t == "lossless" { return .high }
        guard let q = VideoQuality(rawValue: t) else {
            throw DinkyCLIParseError(message: "unknown --quality (use low|medium|high|lossless)")
        }
        return q
    }
}
