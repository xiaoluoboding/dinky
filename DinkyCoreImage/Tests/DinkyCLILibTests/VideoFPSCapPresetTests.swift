import DinkyCoreShared
import XCTest

final class VideoFPSCapPresetTests: XCTestCase {
    func testNormalizeSnapsToNearestAllowed() {
        XCTAssertEqual(VideoFPSCapPreset.normalizeStored(29), 30)
        XCTAssertEqual(VideoFPSCapPreset.normalizeStored(61), 60)
        XCTAssertEqual(VideoFPSCapPreset.normalizeStored(22), 24)
    }

    func testEffectiveCapWhenDisabled() {
        XCTAssertNil(VideoFPSCapPreset.effectiveCapFPS(enabled: false, storedFPS: 30, sourceNominalFPS: 60))
    }

    func testEffectiveCapWhenSourceAlreadyAtOrBelowCap() {
        XCTAssertNil(VideoFPSCapPreset.effectiveCapFPS(enabled: true, storedFPS: 30, sourceNominalFPS: 24))
        XCTAssertNil(VideoFPSCapPreset.effectiveCapFPS(enabled: true, storedFPS: 30, sourceNominalFPS: 30))
    }

    func testEffectiveCapWhenSourceHigher() {
        XCTAssertEqual(
            VideoFPSCapPreset.effectiveCapFPS(enabled: true, storedFPS: 30, sourceNominalFPS: 60),
            30
        )
    }

    func testEffectiveCapWhenNominalUnknownUsesCap() {
        XCTAssertEqual(
            VideoFPSCapPreset.effectiveCapFPS(enabled: true, storedFPS: 24, sourceNominalFPS: 0),
            24
        )
    }
}
