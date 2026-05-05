import AVFoundation
import DinkyCoreShared
import Foundation

public enum AudioCompressionError: LocalizedError, Sendable {
    case noAudioTrack
    case lameExecutableRequired
    case afconvertFailed(String)

    public var errorDescription: String? {
        switch self {
        case .noAudioTrack: return "No audio track was found in this file."
        case .lameExecutableRequired: return "The LAME encoder is required for MP3 export but wasn’t found in the bundle."
        case .afconvertFailed(let m): return m
        }
    }
}

public enum AudioCompressor: Sendable {

    public struct Resolved: Sendable {
        public let durationSeconds: Double?
        public let format: AudioConversionFormat

        public init(durationSeconds: Double?, format: AudioConversionFormat) {
            self.durationSeconds = durationSeconds
            self.format = format
        }
    }

    public static func makeURLAsset(url: URL) -> AVURLAsset {
        let options: [String: Any] = [
            "AVURLAssetUsesNoPersistentCacheKey": true,
            AVURLAssetPreferPreciseDurationAndTimingKey: false,
        ]
        return AVURLAsset(url: url, options: options)
    }

    /// Cross-converts using `/usr/bin/afconvert` and bundled `lame` (MP3 encode only).
    public static func convert(
        source: URL,
        targetFormat: AudioConversionFormat,
        qualityTier: AudioConversionQualityTier,
        lameExecutable: URL?,
        outputURL: URL,
        progressHandler: (@Sendable (Float) -> Void)? = nil
    ) async throws -> Resolved {
        let t0 = CFAbsoluteTimeGetCurrent()
        defer { CompressionTiming.logPhase("audio.convert", startedAt: t0) }

        let asset = makeURLAsset(url: source)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        guard audioTracks.first != nil else {
            throw AudioCompressionError.noAudioTrack
        }

        let durationSeconds: Double?
        do {
            let d = try await asset.load(.duration)
            let s = CMTimeGetSeconds(d)
            durationSeconds = s.isFinite && s > 0 ? s : nil
        } catch {
            durationSeconds = nil
        }

        progressHandler?(0)
        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        if targetFormat == .mp3 {
            guard let lame = lameExecutable else {
                throw AudioCompressionError.lameExecutableRequired
            }
            let tempWav = FileManager.default.temporaryDirectory
                .appendingPathComponent("dinky_audio_\(UUID().uuidString).wav")
            defer { try? FileManager.default.removeItem(at: tempWav) }

            do {
                try await AFConvertRunner.convert(
                    from: source,
                    to: tempWav,
                    arguments: ["-f", "WAVE", "-d", "LEI16"]
                )
                progressHandler?(0.45)
                try await LameRunner.encodeMP3(
                    fromWAV: tempWav,
                    to: outputURL,
                    bitrateKbps: qualityTier.lameCBRBitrateKbps,
                    lameBinary: lame
                )
            } catch let e as AFConvertError {
                throw Self.mapAFConvertError(e)
            } catch let e as LameRunnerError {
                switch e {
                case .lameMissing:
                    throw AudioCompressionError.lameExecutableRequired
                case .processFailed(_, let stderr):
                    throw AudioCompressionError.afconvertFailed(stderr)
                }
            }
        } else {
            let args = afconvertArguments(for: targetFormat, qualityTier: qualityTier)
            do {
                try await AFConvertRunner.convert(from: source, to: outputURL, arguments: args)
            } catch let e as AFConvertError {
                throw Self.mapAFConvertError(e)
            }
        }

        progressHandler?(1)
        return Resolved(durationSeconds: durationSeconds, format: targetFormat)
    }

    private static func afconvertArguments(
        for format: AudioConversionFormat,
        qualityTier: AudioConversionQualityTier
    ) -> [String] {
        switch format {
        case .aacM4A:
            return ["-f", "m4af", "-d", "aac", "-b", "\(qualityTier.aacTotalBitrateBps)"]
        case .alacM4A:
            return ["-f", "m4af", "-d", "alac"]
        case .flac:
            return ["-f", "flac", "-d", "flac"]
        case .wav:
            return ["-f", "WAVE", "-d", "LEI16"]
        case .aiff:
            return ["-f", "AIFF", "-d", "BEI16"]
        case .mp3:
            preconditionFailure("MP3 handled via LAME")
        }
    }

    private static func mapAFConvertError(_ e: AFConvertError) -> AudioCompressionError {
        switch e {
        case .afconvertMissing: return .afconvertFailed("afconvert not found at /usr/bin/afconvert.")
        case .outputMissing: return .afconvertFailed("afconvert did not create an output file.")
        case .processFailed(_, let stderr): return .afconvertFailed(stderr)
        }
    }
}
