import AVFoundation
import CoreGraphics
import DinkyCoreImage
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct CompressionGoals {
    var maxWidth: Int?       // nil = no limit (pixels)
    var maxFileSizeKB: Int?  // nil = no limit
    /// Proportional downscale: 0.5 = half, 0.667 = two-thirds, etc. Applied before maxWidth.
    /// nil = no proportional scaling.
    var scaleFactor: Double? // nil = no scale
}


struct CompressionResult {
    let outputURL: URL
    let originalSize: Int64
    let outputSize: Int64
    var originalRecoveryURL: URL? = nil
    let detectedContentType: ContentType?
    var videoDuration: Double? = nil
    var videoContentType: VideoContentType? = nil
    var videoIsHDR: Bool = false
    var videoEffectiveCodec: VideoCodecFamily? = nil
    var usedFirstFrameOnly: Bool = false
}

enum CompressionError: LocalizedError {
    case binaryNotFound(String)
    case processFailed(Int32, String)
    case outputMissing
    case pdfLoadFailed
    case pdfPageRenderFailed(Int)
    case videoExportFailed(String)
    case videoExportSessionUnavailable
    case heicTranscodeFailed
    case heicEncodeFailed
    case imageResizeFailed
    case imageReadFailed
    case imageWriteFailed

    var errorDescription: String? {
        switch self {
        case .binaryNotFound(let n): return "Binary '\(n)' not found in app bundle."
        case .processFailed(let c, let e): return "Process exited \(c): \(e)"
        case .outputMissing: return "Output file was not created."
        case .pdfLoadFailed: return "Could not open the PDF file."
        case .pdfPageRenderFailed(let p): return "Could not render page \(p + 1)."
        case .videoExportFailed(let msg): return "Video export failed: \(msg)"
        case .videoExportSessionUnavailable: return "Could not create export session for this video."
        case .heicTranscodeFailed: return "Could not read or convert this HEIC/HEIF image."
        case .heicEncodeFailed:
            return String(localized: "Could not encode this image as HEIC.", comment: "Error when HEIC export fails.")
        case .imageResizeFailed: return "Could not resize this image for the width limit."
        case .imageReadFailed:
            return String(localized: "Could not read image data from this file.", comment: "Error when ImageIO fails to read source.")
        case .imageWriteFailed:
            return String(localized: "Could not write the compressed image file.", comment: "Error when ImageIO fails to finalize output.")
        }
    }
}

actor CompressionService {
    static let shared = CompressionService()
    private let binDir: URL
    private let imagePipeline: DinkyImageCompression

    private init() {
        guard let url = Bundle.main.resourceURL else {
            fatalError("Bundle.main.resourceURL is nil — app bundle is malformed")
        }
        self.binDir = url
        self.imagePipeline = DinkyImageCompression(binDirectory: url)
    }

    func compress(
        source: URL,
        format: CompressionFormat,
        goals: CompressionGoals,
        stripMetadata: Bool,
        outputURL: URL,
        originalsAction: OriginalsAction = .keep,
        backupFolderURL: URL? = nil,
        isURLDownloadSource: Bool = false,
        smartQuality: Bool = false,
        contentTypeHint: String = "auto",
        preclassifiedContent: ContentType? = nil,
        parallelCompressionLimit: Int = 3,
        collisionNamingStyle: CollisionNamingStyle = .finderDuplicate,
        collisionCustomPattern: String = "",
        progressHandler: (@Sendable (Float) -> Void)? = nil
    ) async throws -> CompressionResult {
        do {
            let r = try await imagePipeline.compress(
                source: source,
                format: format,
                goals: goals,
                stripMetadata: stripMetadata,
                outputURL: outputURL,
                originalsAction: originalsAction,
                backupFolderURL: backupFolderURL,
                isURLDownloadSource: isURLDownloadSource,
                smartQuality: smartQuality,
                contentTypeHint: contentTypeHint,
                preclassifiedContent: preclassifiedContent,
                parallelCompressionLimit: parallelCompressionLimit,
                collisionNamingStyle: collisionNamingStyle,
                collisionCustomPattern: collisionCustomPattern,
                qualityOverride: nil,
                progressHandler: progressHandler
            )
            return CompressionResult(
                outputURL: r.outputURL,
                originalSize: r.originalSize,
                outputSize: r.outputSize,
                originalRecoveryURL: r.originalRecoveryURL,
                detectedContentType: r.detectedContentType,
                usedFirstFrameOnly: r.usedFirstFrameOnly
            )
        } catch let e as DinkyImageCompressionError {
            throw e.asAppError()
        }
    }

    func compressPDF(
        source: URL,
        outputMode: PDFOutputMode,
        quality: PDFQuality,
        grayscale: Bool,
        stripMetadata: Bool,
        outputURL: URL,
        flattenLastResort: Bool = false,
        flattenUltra: Bool = false,
        preserveQpdfSteps: [PDFPreserveQpdfStep] = [.base],
        targetBytes: Int64? = nil,
        resolutionDownsampling: Bool = false,
        collisionNamingStyle: CollisionNamingStyle = .finderDuplicate,
        collisionCustomPattern: String = "",
        progressHandler: (@Sendable (Float) -> Void)? = nil
    ) async throws -> CompressionResult {
        let qpdf = DinkyEncoderPath.qpdfExecutable(inBinDirectory: binDir)
        let pdfResult = try await DinkyPDFPipeline.compress(
            source: source,
            outputMode: outputMode,
            quality: quality,
            grayscale: grayscale,
            stripMetadata: stripMetadata,
            outputURL: outputURL,
            flattenLastResort: flattenLastResort,
            flattenUltra: flattenUltra,
            preserveQpdfSteps: preserveQpdfSteps,
            targetBytes: targetBytes,
            resolutionDownsampling: resolutionDownsampling,
            collisionNamingStyle: collisionNamingStyle,
            collisionCustomPattern: collisionCustomPattern,
            qpdfBinary: qpdf,
            progressHandler: progressHandler
        )
        return CompressionResult(
            outputURL: pdfResult.outputURL,
            originalSize: pdfResult.originalSize,
            outputSize: pdfResult.outputSize,
            detectedContentType: nil
        )
    }

    // MARK: - Video compression

    func compressVideo(
        source: URL,
        quality: VideoQuality,
        codec: VideoCodecFamily,
        removeAudio: Bool,
        maxResolutionLines: Int? = nil,
        outputURL: URL,
        videoContentType: VideoContentType? = nil,
        progressHandler: (@Sendable (Float) -> Void)? = nil
    ) async throws -> CompressionResult {
        try await compressVideo(
            asset: VideoCompressor.makeURLAsset(url: source),
            source: source,
            quality: quality,
            codec: codec,
            removeAudio: removeAudio,
            maxResolutionLines: maxResolutionLines,
            outputURL: outputURL,
            videoContentType: videoContentType,
            progressHandler: progressHandler
        )
    }

    /// Reuses a pre-built ``AVURLAsset`` (e.g. shared with ``VideoSmartQuality``) to avoid reopening the file.
    /// - Parameter maxResolutionLines: Optional output-height cap (mirrors images' Max width). `nil` keeps source resolution.
    /// - Parameter videoContentType: When already known (Smart Quality classified it), surfaced in the result for the UI chip.
    func compressVideo(
        asset: AVURLAsset,
        source: URL,
        quality: VideoQuality,
        codec: VideoCodecFamily,
        removeAudio: Bool,
        maxResolutionLines: Int? = nil,
        outputURL: URL,
        videoContentType: VideoContentType? = nil,
        progressHandler: (@Sendable (Float) -> Void)? = nil
    ) async throws -> CompressionResult {
        let originalSize = fileSize(source)

        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let resolved = try await VideoCompressor.compress(
            asset: asset,
            sourceForMetadata: source,
            quality: quality,
            codec: codec,
            removeAudio: removeAudio,
            maxResolutionLines: maxResolutionLines,
            outputURL: outputURL,
            progressHandler: progressHandler
        )

        guard FileManager.default.fileExists(atPath: outputURL.path) else {
            throw CompressionError.outputMissing
        }

        return CompressionResult(
            outputURL: outputURL,
            originalSize: originalSize,
            outputSize: fileSize(outputURL),
            detectedContentType: nil,
            videoDuration: resolved.durationSeconds,
            videoContentType: videoContentType,
            videoIsHDR: resolved.isHDR,
            videoEffectiveCodec: resolved.codec
        )
    }

    // MARK: - Helpers

    private func fileSize(_ url: URL) -> Int64 {
        (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).flatMap { Int64($0) } ?? 0
    }
}
