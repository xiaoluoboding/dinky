import DinkyCorePDF
import DinkyCoreShared
import DinkyCLILib
import Foundation
import XCTest

final class PresetScopeAndMergeTests: XCTestCase {
    func testImageOnlyPresetFailsVideoMerge() throws {
        let p = CompressionPreset(
            name: "ImgOnly",
            format: .webp,
            smartQuality: true,
            autoFormat: false,
            maxWidthEnabled: false,
            maxWidth: 1920,
            maxFileSizeEnabled: false,
            maxFileSizeKB: 2048,
            saveLocationRaw: "sameFolder",
            filenameHandlingRaw: "appendSuffix",
            customSuffix: "-dinky",
            collisionNamingStyleRaw: CollisionNamingStyle.finderDuplicate.rawValue,
            collisionCustomPattern: "",
            stripMetadata: true,
            sanitizeFilenames: false,
            openFolderWhenDone: false,
            notifyWhenDone: false,
            watchFolderEnabled: false,
            watchFolderModeRaw: "global",
            watchFolderPath: "",
            watchFolderBookmark: Data(),
            presetCustomFolderPath: "",
            presetCustomFolderBookmark: Data(),
            contentTypeHintRaw: "auto",
            presetMediaScopeRaw: "image",
            pdfOutputModeRaw: PDFOutputMode.flattenPages.rawValue,
            pdfQualityRaw: "medium",
            videoQualityRaw: "high",
            videoCodecFamilyRaw: "h264",
            pdfGrayscale: false,
            pdfAutoGrayscaleMonoScans: true,
            pdfPreserveExperimentalRaw: "none",
            pdfMaxFileSizeEnabled: false,
            pdfMaxFileSizeKB: 10240,
            pdfResolutionDownsampling: false,
            videoRemoveAudio: false,
            videoMaxResolutionEnabled: false,
            videoMaxResolutionLines: 1080,
            videoMaxFPSEnabled: false,
            videoMaxFPS: 30,
            audioFormatRaw: AudioConversionFormat.aacM4A.rawValue,
            audioQualityTierRaw: AudioConversionQualityTier.balanced.rawValue,
            pdfEnableOCR: false,
            pdfOCRLanguages: []
        )
        XCTAssertFalse(p.applies(to: .video))

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("dinky-preset-scope-\(UUID().uuidString).json")
        try JSONEncoder().encode([p]).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        var vopt = DinkyVideoCompressOptions()
        XCTAssertThrowsError(
            try DinkyCLIPresetSupport.applyVideoPresetIfNeeded(
                ref: PresetCLIRef(name: "ImgOnly", file: url.path),
                explicit: [],
                options: &vopt
            )
        ) { err in
            XCTAssertTrue(err is DinkyCLIPresetError)
        }
    }

    func testCLIQualityFlagOverridesPresetVideoTier() throws {
        let p = CompressionPreset(
            name: "V",
            format: .webp,
            smartQuality: true,
            autoFormat: false,
            maxWidthEnabled: false,
            maxWidth: 1920,
            maxFileSizeEnabled: false,
            maxFileSizeKB: 2048,
            saveLocationRaw: "sameFolder",
            filenameHandlingRaw: "appendSuffix",
            customSuffix: "-dinky",
            collisionNamingStyleRaw: CollisionNamingStyle.finderDuplicate.rawValue,
            collisionCustomPattern: "",
            stripMetadata: true,
            sanitizeFilenames: false,
            openFolderWhenDone: false,
            notifyWhenDone: false,
            watchFolderEnabled: false,
            watchFolderModeRaw: "global",
            watchFolderPath: "",
            watchFolderBookmark: Data(),
            presetCustomFolderPath: "",
            presetCustomFolderBookmark: Data(),
            contentTypeHintRaw: "auto",
            presetMediaScopeRaw: "video",
            pdfOutputModeRaw: PDFOutputMode.flattenPages.rawValue,
            pdfQualityRaw: "medium",
            videoQualityRaw: "high",
            videoCodecFamilyRaw: "h264",
            pdfGrayscale: false,
            pdfAutoGrayscaleMonoScans: true,
            pdfPreserveExperimentalRaw: "none",
            pdfMaxFileSizeEnabled: false,
            pdfMaxFileSizeKB: 10240,
            pdfResolutionDownsampling: false,
            videoRemoveAudio: false,
            videoMaxResolutionEnabled: false,
            videoMaxResolutionLines: 1080,
            videoMaxFPSEnabled: false,
            videoMaxFPS: 30,
            audioFormatRaw: AudioConversionFormat.aacM4A.rawValue,
            audioQualityTierRaw: AudioConversionQualityTier.balanced.rawValue,
            pdfEnableOCR: false,
            pdfOCRLanguages: []
        )
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("dinky-preset-v-\(UUID().uuidString).json")
        try JSONEncoder().encode([p]).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        var vopt = DinkyVideoCompressOptions()
        _ = try DinkyCLIPresetSupport.applyVideoPresetIfNeeded(
            ref: PresetCLIRef(name: "V", file: url.path),
            explicit: ["quality"],
            options: &vopt
        )
        // explicit contains quality → preset tier should not apply; options still default .medium from init
        XCTAssertEqual(vopt.quality, .medium)
    }

    func testPresetMergesFPSCapIntoVideoOptions() throws {
        let p = CompressionPreset(
            name: "VFps",
            format: .webp,
            smartQuality: true,
            autoFormat: false,
            maxWidthEnabled: false,
            maxWidth: 1920,
            maxFileSizeEnabled: false,
            maxFileSizeKB: 2048,
            saveLocationRaw: "sameFolder",
            filenameHandlingRaw: "appendSuffix",
            customSuffix: "-dinky",
            collisionNamingStyleRaw: CollisionNamingStyle.finderDuplicate.rawValue,
            collisionCustomPattern: "",
            stripMetadata: true,
            sanitizeFilenames: false,
            openFolderWhenDone: false,
            notifyWhenDone: false,
            watchFolderEnabled: false,
            watchFolderModeRaw: "global",
            watchFolderPath: "",
            watchFolderBookmark: Data(),
            presetCustomFolderPath: "",
            presetCustomFolderBookmark: Data(),
            contentTypeHintRaw: "auto",
            presetMediaScopeRaw: "video",
            pdfOutputModeRaw: PDFOutputMode.flattenPages.rawValue,
            pdfQualityRaw: "medium",
            videoQualityRaw: "high",
            videoCodecFamilyRaw: "h264",
            pdfGrayscale: false,
            pdfAutoGrayscaleMonoScans: true,
            pdfPreserveExperimentalRaw: "none",
            pdfMaxFileSizeEnabled: false,
            pdfMaxFileSizeKB: 10240,
            pdfResolutionDownsampling: false,
            videoRemoveAudio: false,
            videoMaxResolutionEnabled: false,
            videoMaxResolutionLines: 1080,
            videoMaxFPSEnabled: true,
            videoMaxFPS: 24,
            audioFormatRaw: AudioConversionFormat.aacM4A.rawValue,
            audioQualityTierRaw: AudioConversionQualityTier.balanced.rawValue,
            pdfEnableOCR: false,
            pdfOCRLanguages: []
        )
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("dinky-preset-fps-\(UUID().uuidString).json")
        try JSONEncoder().encode([p]).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        var vopt = DinkyVideoCompressOptions()
        _ = try DinkyCLIPresetSupport.applyVideoPresetIfNeeded(
            ref: PresetCLIRef(name: "VFps", file: url.path),
            explicit: [],
            options: &vopt
        )
        XCTAssertTrue(vopt.fpsCapEnabled)
        XCTAssertEqual(vopt.fpsCap, 24)
    }

    func testNoFpsCapFlagOverridesPreset() throws {
        let p = CompressionPreset(
            name: "VFps2",
            format: .webp,
            smartQuality: true,
            autoFormat: false,
            maxWidthEnabled: false,
            maxWidth: 1920,
            maxFileSizeEnabled: false,
            maxFileSizeKB: 2048,
            saveLocationRaw: "sameFolder",
            filenameHandlingRaw: "appendSuffix",
            customSuffix: "-dinky",
            collisionNamingStyleRaw: CollisionNamingStyle.finderDuplicate.rawValue,
            collisionCustomPattern: "",
            stripMetadata: true,
            sanitizeFilenames: false,
            openFolderWhenDone: false,
            notifyWhenDone: false,
            watchFolderEnabled: false,
            watchFolderModeRaw: "global",
            watchFolderPath: "",
            watchFolderBookmark: Data(),
            presetCustomFolderPath: "",
            presetCustomFolderBookmark: Data(),
            contentTypeHintRaw: "auto",
            presetMediaScopeRaw: "video",
            pdfOutputModeRaw: PDFOutputMode.flattenPages.rawValue,
            pdfQualityRaw: "medium",
            videoQualityRaw: "high",
            videoCodecFamilyRaw: "h264",
            pdfGrayscale: false,
            pdfAutoGrayscaleMonoScans: true,
            pdfPreserveExperimentalRaw: "none",
            pdfMaxFileSizeEnabled: false,
            pdfMaxFileSizeKB: 10240,
            pdfResolutionDownsampling: false,
            videoRemoveAudio: false,
            videoMaxResolutionEnabled: false,
            videoMaxResolutionLines: 1080,
            videoMaxFPSEnabled: true,
            videoMaxFPS: 15,
            audioFormatRaw: AudioConversionFormat.aacM4A.rawValue,
            audioQualityTierRaw: AudioConversionQualityTier.balanced.rawValue,
            pdfEnableOCR: false,
            pdfOCRLanguages: []
        )
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("dinky-preset-fps2-\(UUID().uuidString).json")
        try JSONEncoder().encode([p]).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let parse = try DinkyVideoCompressArgParser.parse(["--preset-file", url.path, "--preset", "VFps2", "--no-fps-cap", "clip.mp4"])
        var vopt = parse.options
        _ = try DinkyCLIPresetSupport.applyVideoPresetIfNeeded(
            ref: parse.preset,
            explicit: parse.explicit,
            options: &vopt
        )
        XCTAssertFalse(vopt.fpsCapEnabled)
    }
}
