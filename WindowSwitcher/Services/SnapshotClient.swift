//
//  SnapshotError.swift
//  WindowSwitcher
//
//  Created by Matti Fischbach on 12.09.25.
//

import ScreenCaptureKit
import CoreImage
import Cocoa


public final class SnapshotService: SnapshotServiceProtocol {
    private let ciContext = CIContext()

    private final class StreamHolder {
        let id: UUID
        let stream: SCStream
        let delegate: OneShotDelegate
        var timeoutTask: Task<Void, Never>?

        init(id: UUID, stream: SCStream, delegate: OneShotDelegate) {
            self.id = id
            self.stream = stream
            self.delegate = delegate
        }
    }
    private var activeStreams: [UUID: StreamHolder] = [:]

    public init() {}

    @MainActor
    public func snapshot(window: Window) async throws -> NSImage {
        let content: SCShareableContent
        do {
            content = try await SCShareableContent.current
        } catch {
            throw SnapshotError.permissionDenied
        }

        guard let scWindow = content.windows.first(where: {
            guard let owningPID = $0.owningApplication?.processID else { return false }
            let titleMatches = window.title.isEmpty || ($0.title ?? "").localizedCaseInsensitiveContains(window.title)
            let idMatches: Bool
            if let windowId = UInt32(window.id) {
                idMatches = $0.windowID == windowId
            } else {
                idMatches = true
            }
            
            return owningPID == window.pid && titleMatches && idMatches
        }) else {
            throw SnapshotError.windowNotFound
        }

        let config = SCStreamConfiguration()
        config.width  = Int(scWindow.frame.width)
        config.height = Int(scWindow.frame.height)

        let filter = SCContentFilter(desktopIndependentWindow: scWindow)
        let stream = SCStream(filter: filter, configuration: config, delegate: nil)

        let holderId = UUID()

        return try await withCheckedThrowingContinuation { continuation in
            var didResume = false

            let sampleQueue = DispatchQueue(label: "com.windowswitcher.scstream.\(holderId)")

            let delegate = OneShotDelegate { sampleBuffer in
                Task { @MainActor in
                    guard !didResume else { return }
                    didResume = true

                    if
                        let sample = sampleBuffer,
                        CMSampleBufferIsValid(sample),
                        let image = SnapshotService.image(from: sample, using: self.ciContext)
                    {
                        if let h = self.activeStreams[holderId] {
                            h.timeoutTask?.cancel()
                            Task {
                                try? await h.stream.stopCapture()
                                self.activeStreams.removeValue(forKey: holderId)
                            }
                        }
                        continuation.resume(returning: image)
                        return
                    }

                    // No usable frame
                    if let h = self.activeStreams[holderId] {
                        h.timeoutTask?.cancel()
                        Task {
                            try? await h.stream.stopCapture()
                            self.activeStreams.removeValue(forKey: holderId)
                        }
                    }
                    continuation.resume(throwing: SnapshotError.captureFailed(nil))
                }
            }

            let holder = StreamHolder(id: holderId, stream: stream, delegate: delegate)
            self.activeStreams[holderId] = holder

            Task { @MainActor in
                do {
                    try stream.addStreamOutput(delegate, type: .screen, sampleHandlerQueue: sampleQueue)
                    try await stream.startCapture()
                } catch {
                    self.activeStreams.removeValue(forKey: holderId)
                    if !didResume {
                        didResume = true
                        continuation.resume(throwing: SnapshotError.captureFailed(error))
                    }
                    return
                }

                // Timeout after 2s
                holder.timeoutTask = Task { @MainActor in
                    do { try await Task.sleep(nanoseconds: 2_000_000_000) } catch { return }
                    guard !didResume else { return }
                    didResume = true
                    if let h = self.activeStreams[holderId] {
                        try? await h.stream.stopCapture()
                        self.activeStreams.removeValue(forKey: holderId)
                    }
                    continuation.resume(throwing: SnapshotError.captureFailed(nil))
                }
            }
        }
    }

    private static func image(from sampleBuffer: CMSampleBuffer, using ciContext: CIContext) -> NSImage? {
        guard let pixelBuffer = sampleBuffer.imageBuffer else { return nil }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cg = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        return NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
    }
}

private final class OneShotDelegate: NSObject, SCStreamOutput {
    let handler: (CMSampleBuffer?) -> Void
    init(handler: @escaping (CMSampleBuffer?) -> Void) { self.handler = handler }

    func stream(_ stream: SCStream,
                didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
                of outputType: SCStreamOutputType) {
        guard outputType == .screen else { return }
        handler(sampleBuffer)
    }
}

public enum SnapshotError: Error {
    case permissionDenied
    case windowNotFound
    case captureFailed(Error?)
}
