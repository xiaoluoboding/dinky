import DinkyCoreShared
import Foundation

extension MediaType {
    /// Plural label for “applies to” summaries (preset list, sidebar).
    var presetAppliesToSummaryWord: String {
        switch self {
        case .image: return String(localized: "Images", comment: "Preset list: applies to image files.")
        case .video: return String(localized: "Videos", comment: "Preset list: applies to video files.")
        case .audio: return String(localized: "Audio", comment: "Preset list: applies to audio files.")
        case .pdf: return String(localized: "PDFs", comment: "Preset list: applies to PDF files.")
        }
    }

    /// Singular label for Applies-to multi-select (Image / Video / PDF).
    var presetAppliesToSegmentLabel: String {
        switch self {
        case .image: return String(localized: "Image", comment: "Settings UI: media type segment.")
        case .video: return String(localized: "Video", comment: "Settings UI: media type segment.")
        case .audio: return String(localized: "Audio", comment: "Settings UI: media type segment.")
        case .pdf: return String(localized: "PDF", comment: "Settings UI: media type segment.")
        }
    }
}
