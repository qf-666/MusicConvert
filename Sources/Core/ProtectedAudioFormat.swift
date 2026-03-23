import Foundation

enum ProtectedAudioFormat {
    private static let exactMatches: Set<String> = [
        "kgm",
        "kgma",
        "vpr",
        "ncm",
        "uc!",
        "tm0",
        "tm2",
        "bkcmp3",
        "bkcflac",
        "bkcm4a",
        "mgg",
        "mflac"
    ]

    static func detect(in url: URL) -> String? {
        let fileName = url.lastPathComponent.lowercased()
        let fileExtension = url.pathExtension.lowercased()

        if exactMatches.contains(fileExtension) {
            return fileExtension
        }

        if fileExtension.hasPrefix("qmc") {
            return fileExtension
        }

        if fileName.contains(".qmc") {
            return "qmc*"
        }

        return nil
    }
}

