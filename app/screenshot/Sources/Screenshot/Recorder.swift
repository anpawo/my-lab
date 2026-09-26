import AppKit
import ScreenCaptureKit
import ScreenshotCore

/// One SCStream writing straight to a .mov through SCRecordingOutput. No pause: SCStream has
/// none, and a second segment plus a join is not worth it here.
@MainActor
final class Recorder: NSObject, SCStreamDelegate, SCRecordingOutputDelegate {
    private var stream: SCStream?
    private(set) var url: URL?
    private(set) var started = Date()
    private var finished: CheckedContinuation<Void, Never>?

    var isRecording: Bool { stream != nil }

    func start(filter: SCContentFilter, size: CGSize, scale: CGFloat, sourceRect: CGRect? = nil) async throws {
        let config = SCStreamConfiguration()
        if let sourceRect { config.sourceRect = sourceRect }
        // H.264 wants even dimensions.
        config.width = max(2, Int(size.width * scale) & ~1)
        config.height = max(2, Int(size.height * scale) & ~1)
        config.minimumFrameInterval = CMTime(value: 1, timescale: 60)
        config.showsCursor = true
        config.captureMicrophone = Settings.microphone
        config.capturesAudio = false
        config.queueDepth = 6
        config.pixelFormat = kCVPixelFormatType_32BGRA

        let url = Settings.folder.appendingPathComponent(fileName(kind: "Screen Recording", ext: "mov"))
        let out = SCRecordingOutputConfiguration()
        out.outputURL = url
        out.videoCodecType = .h264
        out.outputFileType = .mov
        let output = SCRecordingOutput(configuration: out, delegate: self)
        let stream = SCStream(filter: filter, configuration: config, delegate: self)
        try stream.addRecordingOutput(output)
        try await stream.startCapture()
        self.stream = stream
        self.url = url
        started = Date()
    }

    /// Returns once the file is closed and playable.
    func stop() async -> URL? {
        guard let stream else { return nil }
        self.stream = nil
        try? await stream.stopCapture()
        await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
            finished = c
            // The delegate normally fires within a few hundred ms; never hang on it.
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in self?.finish() }
        }
        return url
    }

    private func finish() {
        finished?.resume()
        finished = nil
    }

    nonisolated func recordingOutputDidFinishRecording(_ o: SCRecordingOutput) {
        Task { @MainActor in self.finish() }
    }
    nonisolated func recordingOutput(_ o: SCRecordingOutput, didFailWithError error: Error) {
        NSLog("screenshot: recording failed: \(error.localizedDescription)")
        Task { @MainActor in self.finish() }
    }
    nonisolated func stream(_ stream: SCStream, didStopWithError error: Error) {
        NSLog("screenshot: stream stopped: \(error.localizedDescription)")
        Task { @MainActor in self.stream = nil; self.finish() }
    }
}
