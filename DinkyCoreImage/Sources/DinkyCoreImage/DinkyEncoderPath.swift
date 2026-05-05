import DinkyCoreShared
import Foundation

/// Resolves the directory that contains `cwebp`, `avifenc`, and `oxipng` (same layout as Dinky.app Resources).
public enum DinkyEncoderPath: Sendable {
    /// 1) `DINKY_BIN` environment variable
    /// 2) `bin` next to the `dinky` executable
    /// 3) Homebrew on Apple Silicon (`/opt/homebrew/bin`)
    public static func resolveBinDirectory() -> URL? {
        if let e = ProcessInfo.processInfo.environment["DINKY_BIN"]?.trimmingCharacters(in: .whitespacesAndNewlines), !e.isEmpty {
            let u = URL(fileURLWithPath: e, isDirectory: true)
            if isValidEncoderDir(u) { return u }
        }
        let exe = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
        let alongside = exe.deletingLastPathComponent().appendingPathComponent("bin", isDirectory: true)
        if isValidEncoderDir(alongside) { return alongside }

        let homebrew = URL(fileURLWithPath: "/opt/homebrew/bin", isDirectory: true)
        if isValidEncoderDir(homebrew) { return homebrew }

        let homebrewX86 = URL(fileURLWithPath: "/usr/local/bin", isDirectory: true)
        if isValidEncoderDir(homebrewX86) { return homebrewX86 }
        return nil
    }

    public static func isValidEncoderDir(_ url: URL) -> Bool {
        let names = ["cwebp", "avifenc", "oxipng"]
        return names.allSatisfy {
            FileManager.default.isExecutableFile(atPath: url.appendingPathComponent($0).path)
        }
    }

    /// `qpdf` in the same directory as the image encoders (Dinky.app Resources layout).
    public static func qpdfExecutable(inBinDirectory dir: URL) -> URL? {
        let u = dir.appendingPathComponent("qpdf")
        guard FileManager.default.isExecutableFile(atPath: u.path) else { return nil }
        return u
    }

    /// Bundled MP3 encoder (LAME); same folder as image encoders in the `.app`.
    public static func lameExecutable(inBinDirectory dir: URL) -> URL? {
        let u = dir.appendingPathComponent("lame")
        guard FileManager.default.isExecutableFile(atPath: u.path) else { return nil }
        return u
    }

    /// Encoder directory that also includes an executable `qpdf` (needed for preserve-mode qpdf passes).
    public static func resolveBinDirectoryWithQpdf() -> URL? {
        guard let dir = resolveBinDirectory() else { return nil }
        guard qpdfExecutable(inBinDirectory: dir) != nil else { return nil }
        return dir
    }
}
