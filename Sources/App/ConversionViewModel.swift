import Combine
import Foundation

@MainActor
final class ConversionViewModel: ObservableObject {
    @Published var importedFile: ImportedAudioFile?
    @Published var selectedFormat: AudioFormat = .flac
    @Published var outputURL: URL?
    @Published var errorMessage: String?
    @Published var statusMessage: String?
    @Published var isConverting = false

    private let service = AudioConversionService()

    func importFile(from url: URL) {
        do {
            let importedFile = try ImportedAudioFile.copyingFromPicker(url)
            self.importedFile = importedFile
            outputURL = nil
            statusMessage = "Input file is ready."
        } catch {
            present(error: error)
        }
    }

    func convert() {
        guard let importedFile else {
            errorMessage = "Pick a local audio file first."
            return
        }

        isConverting = true
        outputURL = nil
        statusMessage = "Running FFmpeg for \(selectedFormat.displayName)."

        Task {
            do {
                let outputURL = try await service.convert(input: importedFile, to: selectedFormat)
                self.outputURL = outputURL
                statusMessage = "Conversion finished. The file is ready to export."
            } catch {
                present(error: error)
            }

            isConverting = false
        }
    }

    func present(error: Error) {
        isConverting = false
        statusMessage = nil
        errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}
