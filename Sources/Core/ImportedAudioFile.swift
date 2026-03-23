import Foundation

struct ImportedAudioFile {
    let originalName: String
    let localURL: URL
    let byteCount: Int64

    var fileExtension: String {
        localURL.pathExtension.lowercased()
    }

    var baseName: String {
        localURL.deletingPathExtension().lastPathComponent
    }

    var byteCountDescription: String {
        ByteCountFormatter.string(fromByteCount: byteCount, countStyle: .file)
    }

    static func copyingFromPicker(_ sourceURL: URL) throws -> ImportedAudioFile {
        let protectedExtension = ProtectedAudioFormat.detect(in: sourceURL)
        if let protectedExtension {
            throw AudioConversionError.protectedVendorFormat(protectedExtension)
        }

        let accessGranted = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if accessGranted {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let fileManager = FileManager.default
        let workingDirectory = try fileManager.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent("ImportedAudio", isDirectory: true)

        try fileManager.createDirectory(
            at: workingDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )

        let destinationURL = workingDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(sourceURL.pathExtension)

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        try fileManager.copyItem(at: sourceURL, to: destinationURL)

        let values = try destinationURL.resourceValues(forKeys: [.fileSizeKey])

        return ImportedAudioFile(
            originalName: sourceURL.lastPathComponent,
            localURL: destinationURL,
            byteCount: Int64(values.fileSize ?? 0)
        )
    }
}
