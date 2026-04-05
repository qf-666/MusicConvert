import FFmpegSupport
import Foundation

struct AudioConversionService {
    func convert(
        input: ImportedAudioFile,
        to outputFormat: AudioFormat,
        quality: AudioQuality
    ) async throws -> URL {
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

        let outputURL = uniqueOutputURL(
            in: outputDirectory,
            baseName: input.originalBaseName,
            fileExtension: outputFormat.fileExtension,
            fileManager: fileManager
        )

        let arguments = [
            "ffmpeg",
            "-hide_banner",
            "-y",
            "-i",
            input.localURL.path
        ] + outputFormat.ffmpegArguments(for: quality) + [
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

    private func uniqueOutputURL(
        in directory: URL,
        baseName: String,
        fileExtension: String,
        fileManager: FileManager
    ) -> URL {
        let sanitizedBaseName = baseName.isEmpty ? "converted" : baseName
        var candidate = directory
            .appendingPathComponent(sanitizedBaseName)
            .appendingPathExtension(fileExtension)

        if !fileManager.fileExists(atPath: candidate.path) {
            return candidate
        }

        var index = 2
        while true {
            candidate = directory
                .appendingPathComponent("\(sanitizedBaseName)-\(index)")
                .appendingPathExtension(fileExtension)
            if !fileManager.fileExists(atPath: candidate.path) {
                return candidate
            }
            index += 1
        }
    }
}
