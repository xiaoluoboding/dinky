import Foundation
import UniformTypeIdentifiers

public enum MediaType: Hashable, Sendable {
    case image
    case pdf
    case video
    case audio
}

// MARK: - Preset “Applies to” encoding (`CompressionPreset.presetMediaScopeRaw`)

/// Parses and writes `presetMediaScopeRaw`: `"all"`, a single token (`image` / `video` / `audio` / `pdf`), or comma-separated sets in canonical order.
public enum PresetMediaScopeRawCodec: Sendable {
    public static let allTypes: Set<MediaType> = [.image, .video, .audio, .pdf]

    public static func includedTypes(from raw: String) -> Set<MediaType> {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return allTypes }
        if trimmed == "all" { return allTypes }
        if trimmed.contains(",") {
            var set = Set<MediaType>()
            for part in trimmed.split(separator: ",") {
                let p = part.trimmingCharacters(in: .whitespaces).lowercased()
                if let m = tokenToMedia(p) { set.insert(m) }
            }
            return set.isEmpty ? allTypes : set
        }
        if let m = tokenToMedia(trimmed.lowercased()) {
            return [m]
        }
        return allTypes
    }

    /// Serializes a non-empty subset. Callers must ensure `set` is non-empty.
    public static func serialize(_ set: Set<MediaType>) -> String {
        precondition(!set.isEmpty, "preset media scope must include at least one type")
        if set == allTypes { return "all" }
        if set.count == 1, let only = set.first {
            return token(for: only)
        }
        let order: [MediaType] = [.image, .video, .audio, .pdf]
        return order.filter { set.contains($0) }.map { token(for: $0) }.joined(separator: ",")
    }

    private static func token(for m: MediaType) -> String {
        switch m {
        case .image: return "image"
        case .video: return "video"
        case .audio: return "audio"
        case .pdf: return "pdf"
        }
    }

    private static func tokenToMedia(_ s: String) -> MediaType? {
        switch s {
        case "image": return .image
        case "video": return .video
        case "audio": return .audio
        case "pdf": return .pdf
        default: return nil
        }
    }
}

/// Which file types a preset applies to (stored on ``CompressionPreset``).
public enum PresetMediaScope: String, CaseIterable, Identifiable, Sendable {
    case all
    case image
    case video
    case audio
    case pdf

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .all: return "All"
        case .image: return "Images"
        case .pdf: return "PDFs"
        case .video: return "Videos"
        case .audio: return "Audio"
        }
    }
}

/// Classify files by extension / UTI for dispatch (CLI single-queue or `preset run`).
public enum MediaTypeDetector: Sendable {
    private static let imageExtensions: Set<String> = ["jpg", "jpeg", "png", "webp", "avif", "tiff", "bmp", "heic", "heif", "gif"]
    private static let audioExtensions: Set<String> = ["mp3", "m4a", "aac", "wav", "aif", "aiff", "flac", "caf"]
    /// Video-ish extensions (`m4v`/`mp4`/…); `.m4a` is intentionally handled as audio via `audioExtensions` first.
    private static let videoExtensions: Set<String> = ["mp4", "mov", "m4v", "avi", "webm"]

    public static func detect(_ url: URL) -> MediaType? {
        let ext = url.pathExtension.lowercased()
        if imageExtensions.contains(ext) { return .image }
        if ext == "pdf" { return .pdf }
        if audioExtensions.contains(ext) { return .audio }

        guard let uti = UTType(filenameExtension: ext) else {
            if videoExtensions.contains(ext) { return .video }
            return nil
        }

        // Prefer explicit MIME families before video — treats `.m4a` / MPEG-4 audio as audio even if other rules overlap.
        if uti.conforms(to: .mp3) || uti.conforms(to: .mpeg4Audio)
            || uti.conforms(to: .wav) || uti.conforms(to: .aiff)
        {
            return .audio
        }

        if videoExtensions.contains(ext) { return .video }
        // MP4/MOV family — avoids classifying WebM/MKV/etc. as video when AVFoundation export often fails.
        if uti.conforms(to: .mpeg4Movie) || uti.conforms(to: .quickTimeMovie) { return .video }
        if uti.conforms(to: .pdf) { return .pdf }
        if uti.conforms(to: .image) { return .image }
        // Last resort: generic audio UTI (e.g. uncommon extensions).
        if uti.conforms(to: .audio) { return .audio }
        return nil
    }
}
