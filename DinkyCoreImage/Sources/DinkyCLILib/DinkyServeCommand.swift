import DinkyCoreImage
import DinkyCorePDF
import DinkyCoreShared
import DinkyCoreVideo
import Dispatch
import Foundation
import Network

struct DinkyServeCompressBody: Codable {
    var inputPaths: [String]
    var format: String?
    var outputDir: String?
    var maxWidth: Int?
    var maxSizeKB: Int?
    var quality: Int?
    var smartQuality: Bool?
    var stripMetadata: Bool?
    var contentHint: String?
    var parallel: Int?
}

struct DinkyServeVideoCompressBody: Codable {
    var inputPaths: [String]
    var outputDir: String?
    var quality: String?
    var codec: String?
    var removeAudio: Bool?
    var maxHeight: Int?
    /// When false, disables FPS cap. When omitted, FPS cap follows `maxFPS` / defaults.
    var fpsCapEnabled: Bool?
    /// When set, enables cap with this frame rate (60 / 30 / 24 / 15); normalized if needed.
    var maxFPS: Int?
    var smartQuality: Bool?
}

struct DinkyServePdfCompressBody: Codable {
    var inputPaths: [String]
    var outputDir: String?
    var mode: String?
    var quality: String?
    var grayscale: Bool?
    var stripMetadata: Bool?
    var resolutionDownsample: Bool?
    var targetKB: Int?
    var preserveExperimental: String?
    var smartQuality: Bool?
    var autoGrayscaleMono: Bool?
}

public enum DinkyServeCommand {
    public static func runBlocking(args: [String]) -> Never {
        var port: UInt16 = 17381
        var i = 0
        while i < args.count {
            if args[i] == "--port", i + 1 < args.count, let p = UInt16(args[i + 1]) {
                port = p
                i += 2
            } else {
                i += 1
            }
        }
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        guard let listener = try? NWListener(using: parameters, on: NWEndpoint.Port(rawValue: port) ?? 17381) else {
            FileHandle.standardError.write(Data("dinky serve: could not open listener on port \(port)\n".utf8))
            exit(1)
        }
        let queue = DispatchQueue(label: "dinky.serve", qos: .userInitiated, attributes: .concurrent)
        listener.newConnectionHandler = { receiveHTTP(connection: $0, queue: queue) }
        listener.start(queue: queue)
        let banner = "dinky: listening on port \(port) (POST /v1/compress, /v1/video/compress, /v1/pdf/compress; GET /v1/health) — local only. Ctrl-C to stop.\n"
        FileHandle.standardError.write(Data(banner.utf8))
        dispatchMain()
    }

    private static func receiveHTTP(connection: NWConnection, queue: DispatchQueue) {
        connection.start(queue: queue)
        let acc = RecvBuffer()
        @Sendable
        func recv() {
            connection.receive(minimumIncompleteLength: 1, maximumLength: 2_000_000) { data, _, isComplete, error in
                if let d = data, !d.isEmpty { acc.append(d) }
                if let error {
                    _ = error
                    connection.cancel()
                    return
                }
                if isComplete, acc.isEmpty {
                    connection.cancel()
                    return
                }
                if !acc.isEmpty, let s = acc.utf8String(), s.contains("\r\n\r\n") {
                    handleRawHTTP(s, connection: connection, queue: queue)
                    return
                }
                if isComplete, !acc.isEmpty, let s = acc.utf8String() {
                    handleRawHTTP(s, connection: connection, queue: queue)
                    return
                }
                if !isComplete { recv() }
            }
        }
        recv()
    }

    private static func handleRawHTTP(_ raw: String, connection: NWConnection, queue: DispatchQueue) {
        guard let firstSub = raw.split(separator: "\r\n", omittingEmptySubsequences: true).first else {
            send(connection: connection, status: 400, body: "{\"error\":\"bad request\"}")
            return
        }
        let firstLine = String(firstSub)
        let parts = firstLine.split(separator: " ").map(String.init)
        guard parts.count >= 2 else { send(connection: connection, status: 400, body: "{\"error\":\"bad request\"}"); return }
        let method = parts[0]
        let path = parts[1]
        let headerAndBody = raw.split(separator: "\r\n\r\n", maxSplits: 1)
        let body: String
        if headerAndBody.count == 2 {
            body = String(headerAndBody[1])
        } else {
            body = ""
        }
        if method == "GET", path == "/v1/health" || path.hasPrefix("/v1/health?") {
            let b = "{\"ok\":true,\"schema\":\"\(dinkyImageServeInfoSchema)\"}\n"
            send(connection: connection, status: 200, body: b)
            return
        }
        if method == "POST", path == "/v1/compress" {
            Task {
                await handleCompressPOST(body: body, connection: connection, queue: queue)
            }
            return
        }
        if method == "POST", path == "/v1/video/compress" {
            Task {
                await handleVideoCompressPOST(body: body, connection: connection, queue: queue)
            }
            return
        }
        if method == "POST", path == "/v1/pdf/compress" {
            Task {
                await handlePdfCompressPOST(body: body, connection: connection, queue: queue)
            }
            return
        }
        send(connection: connection, status: 404, body: "{\"error\":\"not found\"}")
    }

    private static func handleCompressPOST(body: String, connection: NWConnection, queue: DispatchQueue) async {
        guard let d = body.data(using: .utf8), let msg = try? JSONDecoder().decode(DinkyServeCompressBody.self, from: d) else {
            await sendOnQueue(queue, connection, status: 400, body: "{\"error\":\"invalid JSON\"}")
            return
        }
        if msg.inputPaths.isEmpty {
            await sendOnQueue(queue, connection, status: 400, body: "{\"error\":\"inputPaths required\"}")
            return
        }
        var o = DinkyCompressOptions()
        o.format = msg.format?.lowercased() ?? "auto"
        o.json = true
        if let dir = msg.outputDir { o.outputDir = URL(fileURLWithPath: dir, isDirectory: true) }
        o.maxWidth = msg.maxWidth
        o.maxFileSizeKB = msg.maxSizeKB
        o.quality = msg.quality
        if let sq = msg.smartQuality { o.smartQuality = sq }
        if o.quality != nil { o.smartQuality = false }
        if let m = msg.stripMetadata { o.stripMetadata = m }
        o.contentTypeHint = msg.contentHint ?? "auto"
        if let p = msg.parallel { o.parallelLimit = max(1, p) }
        let (code, results) = await DinkyCompressCommand.runWithOptions(o, paths: msg.inputPaths)
        let payload = DinkyImageCompressResponse(
            schema: dinkyImageCompressResultSchema,
            success: code == 0,
            results: results
        )
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        if let out = try? enc.encode(payload), let s = String(data: out, encoding: .utf8) {
            let status: Int = code == 0 ? 200 : 422
            await sendOnQueue(queue, connection, status: status, body: s)
        } else {
            await sendOnQueue(queue, connection, status: 500, body: "{\"error\":\"encode failed\"}")
        }
    }

    private static func handleVideoCompressPOST(body: String, connection: NWConnection, queue: DispatchQueue) async {
        guard let d = body.data(using: .utf8), let msg = try? JSONDecoder().decode(DinkyServeVideoCompressBody.self, from: d) else {
            await sendOnQueue(queue, connection, status: 400, body: "{\"error\":\"invalid JSON\"}")
            return
        }
        if msg.inputPaths.isEmpty {
            await sendOnQueue(queue, connection, status: 400, body: "{\"error\":\"inputPaths required\"}")
            return
        }
        var o = DinkyVideoCompressOptions()
        o.json = true
        if let dir = msg.outputDir { o.outputDir = URL(fileURLWithPath: dir, isDirectory: true) }
        if let q = msg.quality {
            let t = q.lowercased()
            if t == "low" { o.quality = .medium }
            else if t == "lossless" { o.quality = .high }
            else { o.quality = VideoQuality(rawValue: t) ?? .medium }
        }
        if let c = msg.codec?.lowercased(), let codec = VideoCodecFamily(rawValue: c) {
            o.codec = codec
        }
        if let r = msg.removeAudio { o.removeAudio = r }
        o.maxResolutionLines = msg.maxHeight
        if let en = msg.fpsCapEnabled {
            o.fpsCapEnabled = en
            if en, let mf = msg.maxFPS {
                o.fpsCap = VideoFPSCapPreset.normalizeStored(mf)
            }
        } else if let mf = msg.maxFPS {
            o.fpsCapEnabled = true
            o.fpsCap = VideoFPSCapPreset.normalizeStored(mf)
        }
        if let sq = msg.smartQuality {
            o.smartQuality = sq
        } else if msg.quality != nil {
            o.smartQuality = false
        }
        let (code, results) = await DinkyVideoCompressCommand.runWithOptions(o, paths: msg.inputPaths, preset: nil)
        let payload = DinkyVideoCompressResponse(
            schema: dinkyVideoCompressResultSchema,
            success: code == 0,
            results: results
        )
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        if let out = try? enc.encode(payload), let s = String(data: out, encoding: .utf8) {
            let status: Int = code == 0 ? 200 : 422
            await sendOnQueue(queue, connection, status: status, body: s)
        } else {
            await sendOnQueue(queue, connection, status: 500, body: "{\"error\":\"encode failed\"}")
        }
    }

    private static func handlePdfCompressPOST(body: String, connection: NWConnection, queue: DispatchQueue) async {
        guard let d = body.data(using: .utf8), let msg = try? JSONDecoder().decode(DinkyServePdfCompressBody.self, from: d) else {
            await sendOnQueue(queue, connection, status: 400, body: "{\"error\":\"invalid JSON\"}")
            return
        }
        if msg.inputPaths.isEmpty {
            await sendOnQueue(queue, connection, status: 400, body: "{\"error\":\"inputPaths required\"}")
            return
        }
        guard let bin = DinkyEncoderPath.resolveBinDirectory() else {
            await sendOnQueue(queue, connection, status: 503, body: "{\"error\":\"DINKY_BIN encoders not found\"}")
            return
        }
        let qpdf = DinkyEncoderPath.qpdfExecutable(inBinDirectory: bin)
        var o = DinkyPdfCompressOptions()
        o.json = true
        if let dir = msg.outputDir { o.outputDir = URL(fileURLWithPath: dir, isDirectory: true) }
        if let m = msg.mode?.lowercased() {
            switch m {
            case "preserve": o.outputMode = .preserveStructure
            case "flatten": o.outputMode = .flattenPages
            default: break
            }
        }
        if let q = msg.quality?.lowercased(), let pq = PDFQuality(rawValue: q) {
            o.quality = pq
        }
        if let g = msg.grayscale { o.grayscale = g }
        if let s = msg.stripMetadata { o.stripMetadata = s }
        if let r = msg.resolutionDownsample { o.resolutionDownsampling = r }
        o.targetKB = msg.targetKB
        if let e = msg.preserveExperimental {
            let v = e.lowercased()
            let raw: String
            switch v {
            case "none", "off": raw = PDFPreserveExperimentalMode.none.rawValue
            case "stripstructure", "strip": raw = PDFPreserveExperimentalMode.stripNonEssentialStructure.rawValue
            case "strongerimages", "stronger": raw = PDFPreserveExperimentalMode.strongerImageRecompression.rawValue
            case "maximum", "max": raw = PDFPreserveExperimentalMode.maximum.rawValue
            default: raw = v
            }
            if let mode = PDFPreserveExperimentalMode(rawValue: raw) {
                o.preserveExperimental = mode
            }
        }
        if let sq = msg.smartQuality { o.smartQuality = sq }
        if let ag = msg.autoGrayscaleMono { o.autoGrayscaleMonoScans = ag }
        let (code, results) = await DinkyPdfCompressCommand.runWithOptions(o, paths: msg.inputPaths, preset: nil, qpdfBinary: qpdf)
        let payload = DinkyPdfCompressResponse(
            schema: dinkyPdfCompressResultSchema,
            success: code == 0,
            results: results
        )
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        if let out = try? enc.encode(payload), let s = String(data: out, encoding: .utf8) {
            let status: Int = code == 0 ? 200 : 422
            await sendOnQueue(queue, connection, status: status, body: s)
        } else {
            await sendOnQueue(queue, connection, status: 500, body: "{\"error\":\"encode failed\"}")
        }
    }

    private static func sendOnQueue(_ q: DispatchQueue, _ c: NWConnection, status: Int, body: String) async {
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            q.async {
                send(connection: c, status: status, body: body)
                cont.resume()
            }
        }
    }

    private static func send(connection: NWConnection, status: Int, body: String) {
        let r = "HTTP/1.1 \(status) OK\r\nContent-Type: application/json; charset=utf-8\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n\(body)"
        let data = Data(r.utf8)
        connection.send(content: data, isComplete: true, completion: .contentProcessed { _ in connection.cancel() })
    }
}

/// Thread-safe buffer for a single `NWConnection` receive stream.
private final class RecvBuffer: @unchecked Sendable {
    private var data = Data()
    private let lock = NSLock()

    var isEmpty: Bool {
        lock.lock()
        defer { lock.unlock() }
        return data.isEmpty
    }

    func append(_ more: Data) {
        lock.lock()
        defer { lock.unlock() }
        data.append(more)
    }

    func utf8String() -> String? {
        lock.lock()
        defer { lock.unlock() }
        return String(data: data, encoding: .utf8)
    }
}
