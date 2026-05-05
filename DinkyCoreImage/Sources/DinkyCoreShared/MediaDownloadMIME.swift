import Foundation

/// Maps HTTP `Content-Type` (MIME) to a filename extension for URL downloads (paste / drag link).
public enum MediaDownloadMIME: Sendable {
    public static func pathExtension(for mime: String?) -> String? {
        guard let m = mime?.lowercased() else { return nil }
        switch m {
        case "image/jpeg": return "jpg"
        case "image/png": return "png"
        case "image/webp": return "webp"
        case "image/avif": return "avif"
        case "image/heic", "image/heif": return "heic"
        case "image/tiff": return "tiff"
        case "image/bmp": return "bmp"
        case "application/pdf": return "pdf"
        case "video/mp4": return "mp4"
        case "video/quicktime": return "mov"
        case "video/webm": return "webm"
        default:
            if m.hasPrefix("image/") { return "jpg" }
            if m.hasPrefix("video/") { return "mp4" }
            return nil
        }
    }
}
