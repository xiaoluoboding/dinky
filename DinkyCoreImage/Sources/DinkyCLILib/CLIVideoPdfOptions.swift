import DinkyCorePDF
import DinkyCoreShared
import DinkyCoreVideo
import Foundation

public struct DinkyVideoCompressOptions: Sendable {
    public var quality: VideoQuality
    public var codec: VideoCodecFamily
    public var removeAudio: Bool
    public var maxResolutionLines: Int?
    /// When true and source nominal FPS is above ``fpsCap``, export uses a capped frame duration.
    public var fpsCapEnabled: Bool
    /// Target cap (60 / 30 / 24 / 15); normalized on merge from presets.
    public var fpsCap: Int
    public var smartQuality: Bool
    public var outputDir: URL?
    public var collisionStyle: CollisionNamingStyle
    public var collisionCustomPattern: String
    public var json: Bool

    public init(
        quality: VideoQuality = .medium,
        codec: VideoCodecFamily = .h264,
        removeAudio: Bool = false,
        maxResolutionLines: Int? = nil,
        fpsCapEnabled: Bool = false,
        fpsCap: Int = VideoFPSCapPreset.defaultStoredFPS,
        smartQuality: Bool = true,
        outputDir: URL? = nil,
        collisionStyle: CollisionNamingStyle = .finderDuplicate,
        collisionCustomPattern: String = "",
        json: Bool = false
    ) {
        self.quality = quality
        self.codec = codec
        self.removeAudio = removeAudio
        self.maxResolutionLines = maxResolutionLines
        self.fpsCapEnabled = fpsCapEnabled
        self.fpsCap = fpsCap
        self.smartQuality = smartQuality
        self.outputDir = outputDir
        self.collisionStyle = collisionStyle
        self.collisionCustomPattern = collisionCustomPattern
        self.json = json
    }
}

public struct DinkyPdfCompressOptions: Sendable {
    public var outputMode: PDFOutputMode
    public var quality: PDFQuality
    public var grayscale: Bool
    public var stripMetadata: Bool
    public var resolutionDownsampling: Bool
    public var targetKB: Int?
    public var preserveExperimental: PDFPreserveExperimentalMode
    public var smartQuality: Bool
    public var autoGrayscaleMonoScans: Bool
    public var outputDir: URL?
    public var collisionStyle: CollisionNamingStyle
    public var collisionCustomPattern: String
    public var json: Bool

    public init(
        outputMode: PDFOutputMode = .flattenPages,
        quality: PDFQuality = .medium,
        grayscale: Bool = false,
        stripMetadata: Bool = true,
        resolutionDownsampling: Bool = false,
        targetKB: Int? = nil,
        preserveExperimental: PDFPreserveExperimentalMode = .none,
        smartQuality: Bool = true,
        autoGrayscaleMonoScans: Bool = true,
        outputDir: URL? = nil,
        collisionStyle: CollisionNamingStyle = .finderDuplicate,
        collisionCustomPattern: String = "",
        json: Bool = false
    ) {
        self.outputMode = outputMode
        self.quality = quality
        self.grayscale = grayscale
        self.stripMetadata = stripMetadata
        self.resolutionDownsampling = resolutionDownsampling
        self.targetKB = targetKB
        self.preserveExperimental = preserveExperimental
        self.smartQuality = smartQuality
        self.autoGrayscaleMonoScans = autoGrayscaleMonoScans
        self.outputDir = outputDir
        self.collisionStyle = collisionStyle
        self.collisionCustomPattern = collisionCustomPattern
        self.json = json
    }
}
