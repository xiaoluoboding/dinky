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
