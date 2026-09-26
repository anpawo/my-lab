import Vision

enum OCR {
    /// Lines top to bottom, plus any QR/barcode payloads at the end.
    static func text(in image: CGImage) async throws -> String {
        let text = VNRecognizeTextRequest()
        text.recognitionLevel = .accurate
        text.usesLanguageCorrection = true
        text.automaticallyDetectsLanguage = true
        let codes = VNDetectBarcodesRequest()
        try VNImageRequestHandler(cgImage: image).perform([text, codes])

        let lines = (text.results ?? [])
            .sorted { a, b in
                // Vision's y grows upward; same line if the boxes overlap vertically by half a height.
                let sameLine = abs(a.boundingBox.midY - b.boundingBox.midY) < min(a.boundingBox.height, b.boundingBox.height) / 2
                return sameLine ? a.boundingBox.minX < b.boundingBox.minX : a.boundingBox.midY > b.boundingBox.midY
            }
            .compactMap { $0.topCandidates(1).first?.string }
        let payloads = (codes.results ?? []).compactMap(\.payloadStringValue)
        return (lines + payloads).joined(separator: "\n")
    }
}
