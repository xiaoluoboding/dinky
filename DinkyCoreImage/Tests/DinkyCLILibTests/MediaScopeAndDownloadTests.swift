import DinkyCoreShared
import XCTest

final class MediaTypeDetectorTests: XCTestCase {

    func testWebmDetectedAsVideo() {
        let url = URL(fileURLWithPath: "/tmp/sample.webm")
        XCTAssertEqual(MediaTypeDetector.detect(url), .video)
    }

    func testCommonVideoExtensionsUnchanged() {
        XCTAssertEqual(MediaTypeDetector.detect(URL(fileURLWithPath: "/a/b/c.mp4")), .video)
        XCTAssertEqual(MediaTypeDetector.detect(URL(fileURLWithPath: "/x/y.mov")), .video)
    }

    func testMkvNotClassifiedWithoutExplicitSupport() {
        let url = URL(fileURLWithPath: "/tmp/sample.mkv")
        XCTAssertNil(MediaTypeDetector.detect(url))
    }

    func testAMRReturnsNil() {
        XCTAssertNil(MediaTypeDetector.detect(URL(fileURLWithPath: "/tmp/voice.amr")))
    }

    func test3GPVariantsReturnNil() {
        XCTAssertNil(MediaTypeDetector.detect(URL(fileURLWithPath: "/tmp/x.3gp")))
        XCTAssertNil(MediaTypeDetector.detect(URL(fileURLWithPath: "/tmp/x.3gpp")))
        XCTAssertNil(MediaTypeDetector.detect(URL(fileURLWithPath: "/tmp/x.3g2")))
        XCTAssertNil(MediaTypeDetector.detect(URL(fileURLWithPath: "/tmp/x.awb")))
    }

    func testStandardAudioStillDetected() {
        XCTAssertEqual(MediaTypeDetector.detect(URL(fileURLWithPath: "/tmp/a.m4a")), .audio)
        XCTAssertEqual(MediaTypeDetector.detect(URL(fileURLWithPath: "/tmp/a.mp3")), .audio)
        XCTAssertEqual(MediaTypeDetector.detect(URL(fileURLWithPath: "/tmp/a.flac")), .audio)
    }
}

final class MediaDownloadMIMETests: XCTestCase {

    func testVideoWebmMIME() {
        XCTAssertEqual(MediaDownloadMIME.pathExtension(for: "video/webm"), "webm")
        XCTAssertEqual(MediaDownloadMIME.pathExtension(for: "VIDEO/WEBM"), "webm")
    }

    func testVideoMp4AndQuicktimeUnchanged() {
        XCTAssertEqual(MediaDownloadMIME.pathExtension(for: "video/mp4"), "mp4")
        XCTAssertEqual(MediaDownloadMIME.pathExtension(for: "video/quicktime"), "mov")
    }
}
