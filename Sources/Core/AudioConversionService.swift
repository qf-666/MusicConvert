import FFmpegSupport
import Foundation

struct AudioConversionService {
    func convert(input: ImportedAudioFile, to outputFormat: AudioFormat) async throws -> URL {
        let fileManager = FileManager.default
        let outputDirectory = try fileManager.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent("ConvertedAudio", isDirectory: true)

        try fileManager.createDirectory(
            at: outputDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )

        let outputURL = outputDirectory
            .appendingPathComponent("\(input.baseName)-converted")
            .appendingPathExtension(outputFormat.fileExtension)

        if fileManager.fileExists(atPath: outputURL.path) {
            try fileManager.removeItem(at: outputURL)
        }

        let arguments = [
            "ffmpeg",
            "-hide_banner",
            "-y",
            "-i",
            input.localURL.path
        ] + outputFormat.ffmpegArguments + [
            outputURL.path
        ]

        let exitCode = await Task.detached(priority: .userInitiated) {
            ffmpeg(arguments)
        }.value

        guard exitCode == 0 else {
            throw AudioConversionError.ffmpegFailed(exitCode)
        }

        guard fileManager.fileExists(atPath: outputURL.path) else {
            throw AudioConversionError.missingOutput(exitCode)
        }

        return outputURL
    }
}
