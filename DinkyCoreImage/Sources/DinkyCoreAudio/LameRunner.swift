import Foundation

public enum LameRunnerError: LocalizedError, Sendable {
    case lameMissing(URL)
    case processFailed(Int32, String)

    public var errorDescription: String? {
        switch self {
        case .lameMissing(let u): return "LAME encoder not found or not executable at \(u.path)"
        case .processFailed(let c, let m): return "lame exited \(c): \(m)"
        }
    }
}

/// Encode MP3 from a linear PCM WAV (produced by `afconvert`).
public enum LameRunner: Sendable {
    public static func encodeMP3(fromWAV wavURL: URL, to mp3URL: URL, bitrateKbps: Int, lameBinary: URL)
        async throws
    {
        guard FileManager.default.isExecutableFile(atPath: lameBinary.path) else {
            throw LameRunnerError.lameMissing(lameBinary)
        }

        try FileManager.default.createDirectory(
            at: mp3URL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? FileManager.default.removeItem(at: mp3URL)

        // `-q 2`: good tradeoff; `-b`: CBR for predictable sizing (matches tier labels).
        let args = ["-q", "2", "-b", "\(bitrateKbps)", wavURL.path, mp3URL.path]

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            let p = Process()
            p.executableURL = lameBinary
            p.arguments = args
            let errPipe = Pipe()
            p.standardError = errPipe
            p.standardOutput = Pipe()
            p.terminationHandler = { proc in
                let stderr =
                    String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                if proc.terminationStatus == 0 {
                    cont.resume()
                } else {
                    cont.resume(
                        throwing: LameRunnerError.processFailed(proc.terminationStatus, stderr)
                    )
                }
            }
            do {
                try p.run()
            } catch {
                cont.resume(throwing: error)
            }
        }

        guard FileManager.default.fileExists(atPath: mp3URL.path) else {
            throw LameRunnerError.processFailed(-1, "Output file missing after lame.")
        }
    }
}
