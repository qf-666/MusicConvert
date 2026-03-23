import Foundation

enum AudioConversionError: LocalizedError {
    case protectedVendorFormat(String)
    case missingOutput(Int)
    case ffmpegFailed(Int)

    var errorDescription: String? {
        switch self {
        case let .protectedVendorFormat(extensionName):
            return "Detected a protected or vendor-specific format: \(extensionName). This app does not decrypt or convert it."
        case let .missingOutput(exitCode):
            return "FFmpeg finished without creating an output file. Exit code: \(exitCode)."
        case let .ffmpegFailed(exitCode):
            return "FFmpeg failed during conversion. Exit code: \(exitCode)."
        }
    }
}
