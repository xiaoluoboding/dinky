@testable import DinkyCoreAudio
import XCTest

final class AudioBitrateCapTests: XCTestCase {

    private func probe(rate: Double, channels: UInt32) -> AudioCompressor.SourceProbe {
        AudioCompressor.SourceProbe(sampleRate: rate, channelCount: channels, formatID: 0)
    }

    func testUnknownSampleRatePassesThrough() {
        let r = AudioCompressor.cappedAACBitrate(target: 128_000, probe: probe(rate: 0, channels: 0))
        XCTAssertEqual(r, 128_000)
    }

    func test8kHzMonoCappedAt32k() {
        let r = AudioCompressor.cappedAACBitrate(target: 256_000, probe: probe(rate: 8_000, channels: 1))
        XCTAssertEqual(r, 32_000)
    }

    func test8kHzStereoCappedAt64k() {
        let r = AudioCompressor.cappedAACBitrate(target: 256_000, probe: probe(rate: 8_000, channels: 2))
        XCTAssertEqual(r, 64_000)
    }

    func test16kHzMonoCappedAt64k() {
        let r = AudioCompressor.cappedAACBitrate(target: 96_000, probe: probe(rate: 16_000, channels: 1))
        XCTAssertEqual(r, 64_000)
    }

    func test22kHzMonoCappedAt96k() {
        let r = AudioCompressor.cappedAACBitrate(target: 128_000, probe: probe(rate: 22_050, channels: 1))
        XCTAssertEqual(r, 96_000)
    }

    func test44_1kHzStereoArchivalUnchanged() {
        let r = AudioCompressor.cappedAACBitrate(target: 256_000, probe: probe(rate: 44_100, channels: 2))
        XCTAssertEqual(r, 256_000)
    }

    func test48kHzStereoBalancedUnchanged() {
        let r = AudioCompressor.cappedAACBitrate(target: 128_000, probe: probe(rate: 48_000, channels: 2))
        XCTAssertEqual(r, 128_000)
    }

    func testTargetBelowCapIsRespected() {
        // 8 kHz mono cap is 32k; if the user-tier target is already 16k, keep 16k.
        let r = AudioCompressor.cappedAACBitrate(target: 16_000, probe: probe(rate: 8_000, channels: 1))
        XCTAssertEqual(r, 16_000)
    }
}
