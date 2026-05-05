import AppIntents
import Foundation

struct CompressVideoIntent: AppIntent {
    static var title: LocalizedStringResource = LocalizedStringResource(
        "Compress Videos",
        comment: "Shortcuts app: video intent title."
    )
    static var description = IntentDescription(
        LocalizedStringResource(
            "Compresses video files to MP4 using Dinky and returns the compressed files. Uses codec, quality, audio removal, max resolution, and optional frame-rate cap from the app’s Settings.",
            comment: "Shortcuts app: video intent description."
        ),
        categoryName: LocalizedStringResource("Video", comment: "Shortcuts app: video intent category.")
    )

    @Parameter(
        title: LocalizedStringResource("Videos", comment: "Shortcuts: videos parameter title."),
        description: LocalizedStringResource("The video files to compress.", comment: "Shortcuts: videos parameter description.")
    )
    var videos: [IntentFile]

    static var parameterSummary: some ParameterSummary {
        Summary("Compress \(\.$videos)")
    }

    func perform() async throws -> some ReturnsValue<[IntentFile]> {
        let settings = DinkyPreferences.videoCompressionSettingsForIntent()
        var results: [IntentFile] = []

        for video in videos {
            let srcURL = URL(fileURLWithPath: video.filename)
            let ext = srcURL.pathExtension.isEmpty ? "mp4" : srcURL.pathExtension
            let stem = srcURL.deletingPathExtension().lastPathComponent.isEmpty
                ? String(localized: "video", comment: "Default filename stem for Shortcuts video output when source has no name.")
                : srcURL.deletingPathExtension().lastPathComponent

            let tmpIn = FileManager.default.temporaryDirectory
                .appendingPathComponent("dinky_video_intent_\(UUID().uuidString)")
                .appendingPathExtension(ext)
            let tmpOut = FileManager.default.temporaryDirectory
                .appendingPathComponent("dinky_video_intent_\(UUID().uuidString)")
                .appendingPathExtension("mp4")

            try video.data.write(to: tmpIn)
            defer { try? FileManager.default.removeItem(at: tmpIn) }

            let result = try await CompressionService.shared.compressVideo(
                source: tmpIn,
                quality: settings.quality,
                codec: settings.codec,
                removeAudio: settings.removeAudio,
                maxResolutionLines: settings.maxResolutionLines,
                maxFPSEnabled: settings.fpsCapEnabled,
                storedMaxFPS: settings.fpsCap,
                outputURL: tmpOut,
                videoContentType: nil,
                progressHandler: nil
            )
            defer { try? FileManager.default.removeItem(at: result.outputURL) }

            let outData = try Data(contentsOf: result.outputURL)
            let outFilename = stem + ".mp4"
            results.append(IntentFile(data: outData, filename: outFilename, type: .init(filenameExtension: "mp4")))
        }

        return .result(value: results)
    }
}
