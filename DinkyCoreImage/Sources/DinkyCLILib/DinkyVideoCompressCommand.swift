import DinkyCoreShared
import DinkyCoreVideo
import Foundation

public enum DinkyVideoCompressCommand: Sendable {
    public static func run(_ args: [String]) async -> (Int32, Int) {
        let parse: DinkyVideoCompressParseResult
        do {
            parse = try DinkyVideoCompressArgParser.parse(args)
        } catch let e as DinkyCLIParseError {
            FileHandle.standardError.write(Data("dinky: \(e.message)\n".utf8))
            return (1, 0)
        } catch {
            FileHandle.standardError.write(Data("dinky: \(error.localizedDescription)\n".utf8))
            return (1, 0)
        }

        var opts = parse.options
        let presetUsed: CompressionPreset?
        do {
            presetUsed = try DinkyCLIPresetSupport.applyVideoPresetIfNeeded(
                ref: parse.preset,
                explicit: parse.explicit,
                options: &opts
            )
        } catch let e as DinkyCLIPresetError {
            FileHandle.standardError.write(Data("dinky: \(e.message)\n".utf8))
            return (1, 0)
        } catch {
            FileHandle.standardError.write(Data("dinky: \(error.localizedDescription)\n".utf8))
            return (1, 0)
        }

        let paths = parse.paths
        guard !paths.isEmpty else {
            FileHandle.standardError.write(Data("dinky compress-video: no input files (see: dinky help)\n".utf8))
            return (1, 0)
        }

        let (code, results) = await runWithOptions(opts, paths: paths, preset: presetUsed)
        printResults(opts: opts, code: code, results: results)
        return (code, results.count)
    }

    public static func runWithOptions(
        _ opts: DinkyVideoCompressOptions,
        paths: [String],
        preset: CompressionPreset? = nil
    ) async -> (Int32, [DinkyVideoCompressFileResult]) {
        var fileResults: [DinkyVideoCompressFileResult] = []
        var anyFailed = false

        for p in paths {
            let inURL = URL(fileURLWithPath: p, isDirectory: false).standardizedFileURL
            let origSize: Int64 = (try? inURL.resourceValues(forKeys: [.fileSizeKey]).fileSize).map { Int64($0) } ?? 0
            guard FileManager.default.isReadableFile(atPath: inURL.path) else {
                anyFailed = true
                fileResults.append(
                    DinkyVideoCompressFileResult(
                        input: p,
                        output: nil,
                        originalBytes: origSize,
                        outputBytes: nil,
                        savingsPercent: nil,
                        durationSeconds: nil,
                        effectiveCodec: nil,
                        isHDR: nil,
                        videoContentType: nil,
                        error: "No such file or not readable"
                    )
                )
                continue
            }

            let outDir: URL
            do {
                if let d = opts.outputDir {
                    outDir = d.standardizedFileURL
                } else {
                    outDir = try DinkyCLIPresetSupport.outputDirectoryForSourceURL(preset: preset, source: inURL)
                        .standardizedFileURL
                }
            } catch let e as DinkyCLIPresetError {
                anyFailed = true
                fileResults.append(
                    DinkyVideoCompressFileResult(
                        input: p,
                        output: nil,
                        originalBytes: origSize,
                        outputBytes: nil,
                        savingsPercent: nil,
                        durationSeconds: nil,
                        effectiveCodec: nil,
                        isHDR: nil,
                        videoContentType: nil,
                        error: e.message
                    )
                )
                continue
            } catch {
                anyFailed = true
                fileResults.append(
                    DinkyVideoCompressFileResult(
                        input: p,
                        output: nil,
                        originalBytes: origSize,
                        outputBytes: nil,
                        savingsPercent: nil,
                        durationSeconds: nil,
                        effectiveCodec: nil,
                        isHDR: nil,
                        videoContentType: nil,
                        error: error.localizedDescription
                    )
                )
                continue
            }

            try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
            let outName = DinkyCLIPresetSupport.outputFilenameStem(preset: preset, source: inURL, mediaExtension: "mp4")
            let desiredOut = outDir.appendingPathComponent(outName, isDirectory: false)
            let uniqueOut = OutputPathUniqueness.uniqueOutputURL(
                desired: desiredOut,
                sourceURL: inURL,
                style: opts.collisionStyle,
                customPattern: opts.collisionCustomPattern
            )

            let asset = VideoCompressor.makeURLAsset(url: inURL)
            var videoQuality = opts.quality
            var contentType: VideoContentType? = nil
            if opts.smartQuality {
                let decision = await VideoSmartQuality.decide(asset: asset, fallback: opts.quality)
                videoQuality = decision.quality
                contentType = decision.contentType
            }

            do {
                let resolved = try await VideoCompressor.compress(
                    asset: asset,
                    sourceForMetadata: inURL,
                    quality: videoQuality,
                    codec: opts.codec,
                    removeAudio: opts.removeAudio,
                    maxResolutionLines: opts.maxResolutionLines,
                    maxFPSEnabled: opts.fpsCapEnabled,
                    storedMaxFPS: opts.fpsCap,
                    outputURL: uniqueOut,
                    progressHandler: nil
                )
                let outBytes: Int64 = (try? uniqueOut.resourceValues(forKeys: [.fileSizeKey]).fileSize).map { Int64($0) } ?? 0
                let pct: Double? = origSize > 0 ? (1.0 - Double(outBytes) / Double(origSize)) * 100.0 : nil
                fileResults.append(
                    DinkyVideoCompressFileResult(
                        input: p,
                        output: uniqueOut.path,
                        originalBytes: origSize,
                        outputBytes: outBytes,
                        savingsPercent: pct,
                        durationSeconds: resolved.durationSeconds,
                        effectiveCodec: resolved.codec.rawValue,
                        isHDR: resolved.isHDR,
                        videoContentType: opts.smartQuality ? (contentType?.rawValue) : nil,
                        error: nil
                    )
                )
            } catch {
                anyFailed = true
                fileResults.append(
                    DinkyVideoCompressFileResult(
                        input: p,
                        output: nil,
                        originalBytes: origSize,
                        outputBytes: nil,
                        savingsPercent: nil,
                        durationSeconds: nil,
                        effectiveCodec: nil,
                        isHDR: nil,
                        videoContentType: contentType?.rawValue,
                        error: error.localizedDescription
                    )
                )
            }
        }

        return (anyFailed ? 1 : 0, fileResults)
    }

    private static func printResults(opts: DinkyVideoCompressOptions, code: Int32, results: [DinkyVideoCompressFileResult]) {
        if opts.json {
            let payload = DinkyVideoCompressResponse(
                schema: dinkyVideoCompressResultSchema,
                success: code == 0,
                results: results
            )
            let enc = JSONEncoder()
            enc.outputFormatting = [.prettyPrinted, .sortedKeys]
            if let d = try? enc.encode(payload), let s = String(data: d, encoding: .utf8) {
                print(s)
            }
        } else {
            for fr in results {
                if let e = fr.error {
                    print("\(fr.input): error: \(e)")
                } else if let outP = fr.output, let outB = fr.outputBytes {
                    let pct = fr.savingsPercent.map { String(format: "%.1f%%", $0) } ?? "0%"
                    print("\(fr.input) -> \(outP)  (\(fr.originalBytes) → \(outB) bytes, saved \(pct))")
                }
            }
        }
    }
}
