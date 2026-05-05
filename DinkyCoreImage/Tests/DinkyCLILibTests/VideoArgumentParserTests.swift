import DinkyCLILib
import XCTest

final class VideoArgumentParserTests: XCTestCase {
    func testDefaults() throws {
        let r = try DinkyVideoCompressArgParser.parse(["a.mov"])
        XCTAssertEqual(r.paths, ["a.mov"])
        XCTAssertTrue(r.options.smartQuality)
    }

    func testCodecAndQuality() throws {
        let r = try DinkyVideoCompressArgParser.parse(["--codec", "hevc", "-q", "low", "--no-smart-quality", "v.mp4"])
        XCTAssertEqual(r.options.codec, .hevc)
        XCTAssertEqual(r.options.quality, .medium)
        XCTAssertFalse(r.options.smartQuality)
    }

    func testMaxFpsAndNoFpsCap() throws {
        let r = try DinkyVideoCompressArgParser.parse(["--max-fps", "24", "a.mov"])
        XCTAssertTrue(r.options.fpsCapEnabled)
        XCTAssertEqual(r.options.fpsCap, 24)
        XCTAssertTrue(r.explicit.contains("maxFps"))

        let r2 = try DinkyVideoCompressArgParser.parse(["--no-fps-cap", "b.mov"])
        XCTAssertFalse(r2.options.fpsCapEnabled)
        XCTAssertTrue(r2.explicit.contains("maxFps"))
    }

    func testProresRejected() {
        XCTAssertThrowsError(try DinkyVideoCompressArgParser.parse(["--codec", "prores", "a.mov"])) { err in
            let e = err as? DinkyCLIParseError
            XCTAssertTrue(e?.message.contains("ProRes") == true)
        }
    }
}
