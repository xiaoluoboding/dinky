import AVFoundation
import DinkyCoreShared
import Foundation
import os

/// Picks AAC tier (and occasionally nudges toward a better tier) from track bit rate metadata.
public enum AudioSmartQuality: Sendable {

    private static let log = Logger(subsystem: "dinky", category: "AudioSmartQuality")

    public struct Decision: Sendable {
        public let format: AudioConversionFormat
        public let tier: AudioConversionQualityTier

        public init(format: AudioConversionFormat, tier: AudioConversionQualityTier) {
            self.format = format
            self.tier = tier
        }
    }

    public static func decide(
        asset: AVURLAsset,
        userFormat: AudioConversionFormat,
        userTier: AudioConversionQualityTier
    ) async -> Decision {
        let t0 = CFAbsoluteTimeGetCurrent()
        defer {
            log.debug(
                "audio.smartQuality.decide \(String(format: "%.3f", CFAbsoluteTimeGetCurrent() - t0))s"
            )
        }

        do {
            let tracks = try await asset.loadTracks(withMediaType: .audio)
            guard let track = tracks.first else {
                return Decision(format: userFormat, tier: userTier)
            }

            let rate = try await track.load(.estimatedDataRate)
            let bps = Double(rate)
            guard bps > 0 else {
                return Decision(format: userFormat, tier: userTier)
            }

            var tier = userTier

            // Already very compressed — avoid over-shrinking speech / low-bit podcasts.
            if bps < 88_000, userTier == .smallest {
                tier = .balanced
            }

            // High-bitrate masters — bump toward archival lossy tier (or stay lossless-bound).
            if bps >= 230_000 {
                tier = .archival
            } else if bps >= 180_000, tier == .smallest {
                tier = .balanced
            }

            var format = userFormat
            // Archival + lossy AAC → prefer FLAC for mastering / web delivery of lossless sources.
            if tier == .archival, format == .aacM4A {
                format = .flac
            }

            return Decision(format: format, tier: tier)
        } catch {
            return Decision(format: userFormat, tier: userTier)
        }
    }
}
