import Foundation

public enum AFConvertError: LocalizedError, Sendable {
    case afconvertMissing
    case processFailed(Int32, String)
    case outputMissing

    public var errorDescription: String? {
        switch self {
        case .afconvertMissing: return "`/usr/bin/afconvert` is not available."
        case .processFailed(let c, let m): return "afconvert exited \(c): \(m)"
        case .outputMissing: return "afconvert did not create the output file."
        }
    }
}

/// Runs Apple's `/usr/bin/afconvert` (no bundle cost).
public enum AFConvertRunner: Sendable {
    public static let executableURL = URL(fileURLWithPath: "/usr/bin/afconvert")

    /// `afconvert [options…] input output`
    public static func convert(from input: URL, to output: URL, arguments args: [String]) async throws {
        guard FileManager.default.isExecutableFile(atPath: executableURL.path) else {
            throw AFConvertError.afconvertMissing
        }

        try FileManager.default.createDirectory(
            at: output.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? FileManager.default.removeItem(at: output)

        var fullArgs = args
        fullArgs.append(contentsOf: [input.path, output.path])

        do {
            try await ProcessRunner.runExecutable(executableURL, arguments: fullArgs)
        } catch let ProcessRunnerError.processFailed(c, m) {
            throw AFConvertError.processFailed(c, m)
        }

        guard FileManager.default.fileExists(atPath: output.path) else {
            throw AFConvertError.outputMissing
        }
    }
}
