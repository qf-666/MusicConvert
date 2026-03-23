import Foundation

enum AudioFormat: String, CaseIterable, Identifiable {
    case flac
    case mp3
    case wav
    case ogg
    case aac
    case m4a

    var id: String { rawValue }

    var displayName: String {
        rawValue.uppercased()
    }

    var fileExtension: String {
        rawValue
    }

    var description: String {
        switch self {
        case .flac:
            return "Lossless compression"
        case .mp3:
            return "Lossy, broad compatibility"
        case .wav:
            return "Uncompressed PCM"
        case .ogg:
            return "Vorbis container"
        case .aac:
            return "Raw AAC stream"
        case .m4a:
            return "AAC in M4A container"
        }
    }

    var ffmpegArguments: [String] {
        switch self {
        case .flac:
            return ["-vn", "-c:a", "flac", "-compression_level", "8"]
        case .mp3:
            return ["-vn", "-c:a", "libmp3lame", "-q:a", "2"]
        case .wav:
            return ["-vn", "-c:a", "pcm_s16le"]
        case .ogg:
            return ["-vn", "-c:a", "vorbis", "-q:a", "5"]
        case .aac:
            return ["-vn", "-c:a", "aac", "-b:a", "256k", "-f", "adts"]
        case .m4a:
            return ["-vn", "-c:a", "aac", "-b:a", "256k", "-movflags", "+faststart"]
        }
    }
}
