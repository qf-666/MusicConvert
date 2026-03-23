import Foundation

/// Decodes KuGou Music encrypted files (.kgm, .kgma, .vpr).
/// Ported from https://github.com/ghtz08/kugou-kgm-decoder (Rust/MIT).
enum KGMDecoder {

    // MARK: - Public

    enum DecoderError: LocalizedError {
        case invalidMagicHeader
        case headerTooShort
        case pubKeyLoadFailed

        var errorDescription: String? {
            switch self {
            case .invalidMagicHeader:
                return "不是有效的 KGM/VPR 文件。"
            case .headerTooShort:
                return "文件头太短，无法解码。"
            case .pubKeyLoadFailed:
                return "无法加载 KGM 解密密钥。"
            }
        }
    }

    /// Detects whether the file at `url` is a KGM/VPR encrypted file.
    static func canDecode(_ url: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }
        guard let headerData = try? handle.read(upToCount: Self.magicHeader.count),
              headerData.count == Self.magicHeader.count
        else { return false }
        return headerData.elementsEqual(Self.magicHeader)
    }

    /// Decrypts the KGM/VPR file at `inputURL` and writes the raw audio
    /// to a temporary file, returning the URL to the decrypted file.
    /// The caller is responsible for deleting the returned file when done.
    static func decode(inputURL: URL) throws -> URL {
        let inputData = try Data(contentsOf: inputURL)
        guard inputData.count > Self.headerLen else {
            throw DecoderError.headerTooShort
        }

        let fileMagic = inputData.prefix(Self.magicHeader.count)
        guard fileMagic.elementsEqual(Self.magicHeader) else {
            throw DecoderError.invalidMagicHeader
        }

        var ownKey = [UInt8](repeating: 0, count: Self.ownKeyLen)
        ownKey.replaceSubrange(0..<16, with: inputData[0x1c..<0x2c])

        let audioData = inputData[Self.headerLen...]
        let audioLength = audioData.count
        let pubKey = try loadPubKey()

        var decoded = Data(count: audioLength)
        let pubKeyMendCount = Self.pubKeyMend.count

        decoded.withUnsafeMutableBytes { decodedPtr in
            audioData.withUnsafeBytes { audioPtr in
                let dst = decodedPtr.bindMemory(to: UInt8.self)
                let src = audioPtr.bindMemory(to: UInt8.self)

                for i in 0..<audioLength {
                    let byte = src[i]

                    var ownVal = ownKey[i % Self.ownKeyLen] ^ byte
                    ownVal ^= (ownVal & 0x0F) << 4

                    let pubKeyIndex = i / Self.pubKeyMagnification
                    var pubVal = Self.pubKeyMend[i % pubKeyMendCount]
                    if pubKeyIndex < pubKey.count {
                        pubVal ^= pubKey[pubKeyIndex]
                    }
                    pubVal ^= (pubVal & 0x0F) << 4

                    dst[i] = ownVal ^ pubVal
                }
            }
        }

        let ext = detectAudioExtension(decoded)

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("KGMDecoded", isDirectory: true)
        try FileManager.default.createDirectory(
            at: tempDir,
            withIntermediateDirectories: true
        )
        let outputURL = tempDir
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(ext)

        try decoded.write(to: outputURL)
        return outputURL
    }

    // MARK: - Constants

    private static let headerLen = 1024
    private static let ownKeyLen = 17
    private static let pubKeyMagnification = 16
    private static let magicHeader: [UInt8] = [
        0x7C, 0xD5, 0x32, 0xEB, 0x86, 0x02, 0x7F, 0x4B,
        0xA8, 0xAF, 0xA6, 0x8E, 0x0F, 0xFF, 0x99, 0x14,
        0x00, 0x04, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00,
        0x01, 0x00, 0x00, 0x00,
    ]

    private static let pubKeyMend: [UInt8] = [
        0xB8, 0xD5, 0x3D, 0xB2, 0xE9, 0xAF, 0x78, 0x8C, 0x83, 0x33, 0x71, 0x51, 0x76, 0xA0,
        0xCD, 0x37, 0x2F, 0x3E, 0x35, 0x8D, 0xA9, 0xBE, 0x98, 0xB7, 0xE7, 0x8C, 0x22, 0xCE,
        0x5A, 0x61, 0xDF, 0x68, 0x69, 0x89, 0xFE, 0xA5, 0xB6, 0xDE, 0xA9, 0x77, 0xFC, 0xC8,
        0xBD, 0xBD, 0xE5, 0x6D, 0x3E, 0x5A, 0x36, 0xEF, 0x69, 0x4E, 0xBE, 0xE1, 0xE9, 0x66,
        0x1C, 0xF3, 0xD9, 0x02, 0xB6, 0xF2, 0x12, 0x9B, 0x44, 0xD0, 0x6F, 0xB9, 0x35, 0x89,
        0xB6, 0x46, 0x6D, 0x73, 0x82, 0x06, 0x69, 0xC1, 0xED, 0xD7, 0x85, 0xC2, 0x30, 0xDF,
        0xA2, 0x62, 0xBE, 0x79, 0x2D, 0x62, 0x62, 0x3D, 0x0D, 0x7E, 0xBE, 0x48, 0x89, 0x23,
        0x02, 0xA0, 0xE4, 0xD5, 0x75, 0x51, 0x32, 0x02, 0x53, 0xFD, 0x16, 0x3A, 0x21, 0x3B,
        0x16, 0x0F, 0xC3, 0xB2, 0xBB, 0xB3, 0xE2, 0xBA, 0x3A, 0x3D, 0x13, 0xEC, 0xF6, 0x01,
        0x45, 0x84, 0xA5, 0x70, 0x0F, 0x93, 0x49, 0x0C, 0x64, 0xCD, 0x31, 0xD5, 0xCC, 0x4C,
        0x07, 0x01, 0x9E, 0x00, 0x1A, 0x23, 0x90, 0xBF, 0x88, 0x1E, 0x3B, 0xAB, 0xA6, 0x3E,
        0xC4, 0x73, 0x47, 0x10, 0x7E, 0x3B, 0x5E, 0xBC, 0xE3, 0x00, 0x84, 0xFF, 0x09, 0xD4,
        0xE0, 0x89, 0x0F, 0x5B, 0x58, 0x70, 0x4F, 0xFB, 0x65, 0xD8, 0x5C, 0x53, 0x1B, 0xD3,
        0xC8, 0xC6, 0xBF, 0xEF, 0x98, 0xB0, 0x50, 0x4F, 0x0F, 0xEA, 0xE5, 0x83, 0x58, 0x8C,
        0x28, 0x2C, 0x84, 0x67, 0xCD, 0xD0, 0x9E, 0x47, 0xDB, 0x27, 0x50, 0xCA, 0xF4, 0x63,
        0x63, 0xE8, 0x97, 0x7F, 0x1B, 0x4B, 0x0C, 0xC2, 0xC1, 0x21, 0x4C, 0xCC, 0x58, 0xF5,
        0x94, 0x52, 0xA3, 0xF3, 0xD3, 0xE0, 0x68, 0xF4, 0x00, 0x23, 0xF3, 0x5E, 0x0A, 0x7B,
        0x93, 0xDD, 0xAB, 0x12, 0xB2, 0x13, 0xE8, 0x84, 0xD7, 0xA7, 0x9F, 0x0F, 0x32, 0x4C,
        0x55, 0x1D, 0x04, 0x36, 0x52, 0xDC, 0x03, 0xF3, 0xF9, 0x4E, 0x42, 0xE9, 0x3D, 0x61,
        0xEF, 0x7C, 0xB6, 0xB3, 0x93, 0x50,
    ]

    // MARK: - Public key loading

    private static var cachedPubKey: [UInt8]?

    private static func loadPubKey() throws -> [UInt8] {
        if let cached = cachedPubKey {
            return cached
        }

        guard let keyURL = Bundle.main.url(
            forResource: "kugou_key",
            withExtension: "bin"
        ) else {
            throw DecoderError.pubKeyLoadFailed
        }

        let pubKeyData = try Data(contentsOf: keyURL)
        let pubKey = [UInt8](pubKeyData)
        guard !pubKey.isEmpty else {
            throw DecoderError.pubKeyLoadFailed
        }

        cachedPubKey = pubKey
        return pubKey
    }

    // MARK: - Audio format detection

    /// Detect output audio format from decoded magic bytes.
    private static func detectAudioExtension(_ data: Data) -> String {
        guard data.count >= 4 else { return "mp3" }
        let b0 = data[data.startIndex]
        let b1 = data[data.startIndex + 1]
        let b2 = data[data.startIndex + 2]
        let b3 = data[data.startIndex + 3]

        if b0 == 0x66 && b1 == 0x4C && b2 == 0x61 && b3 == 0x43 {
            return "flac"
        }
        if b0 == 0x4F && b1 == 0x67 && b2 == 0x67 && b3 == 0x53 {
            return "ogg"
        }
        if (b0 == 0x49 && b1 == 0x44 && b2 == 0x33) || (b0 == 0xFF && (b1 & 0xE0) == 0xE0) {
            return "mp3"
        }
        if b0 == 0x52 && b1 == 0x49 && b2 == 0x46 && b3 == 0x46 {
            return "wav"
        }
        if data.count >= 8 {
            let b4 = data[data.startIndex + 4]
            let b5 = data[data.startIndex + 5]
            let b6 = data[data.startIndex + 6]
            let b7 = data[data.startIndex + 7]
            if b4 == 0x66 && b5 == 0x74 && b6 == 0x79 && b7 == 0x70 {
                return "m4a"
            }
        }

        return "mp3"
    }
}
