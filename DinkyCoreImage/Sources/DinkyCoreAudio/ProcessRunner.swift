import Foundation

enum ProcessRunnerError: LocalizedError, Sendable {
    case processFailed(Int32, String)

    var errorDescription: String? {
        switch self {
        case .processFailed(let c, let m): return "Process exited \(c): \(m)"
        }
    }
}

enum ProcessRunner: Sendable {
    static func runExecutable(_ url: URL, arguments: [String]) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            let p = Process()
            p.executableURL = url
            p.arguments = arguments
            let errPipe = Pipe()
            p.standardError = errPipe
            p.standardOutput = Pipe()
            p.terminationHandler = { proc in
                let stderr =
                    String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                if proc.terminationStatus == 0 {
                    cont.resume()
                } else {
                    cont.resume(throwing: ProcessRunnerError.processFailed(proc.terminationStatus, stderr))
                }
            }
            do {
                try p.run()
            } catch {
                cont.resume(throwing: error)
            }
        }
    }
}
