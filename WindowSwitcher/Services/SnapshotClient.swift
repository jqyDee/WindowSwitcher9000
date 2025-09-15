//
//  SnapshotError.swift
//  WindowSwitcher
//
//  Created by Matti Fischbach on 12.09.25.
//

import ScreenCaptureKit
import CoreImage
import Cocoa

public protocol SnapshotServiceProtocol {
    @MainActor
    func snapshot(window: Window, maxSize: CGSize) async throws -> NSImage
}

public final class SnapshotService: SnapshotServiceProtocol {
    private let ciContext = CIContext()

    public init() {}

    public func snapshot(window: Window, maxSize: CGSize = CGSize(width: 1200, height: 900)) async throws -> NSImage {
        let content: SCShareableContent
        do {
            content = try await SCShareableContent.current
        } catch {
            throw SnapshotError.permissionDenied
        }

        guard let scWindow = content.windows.first(where: {
            $0.owningApplication?.processID == window.pid &&
            $0.isOnScreen
        }) else {
            throw SnapshotError.windowNotFound
        }

        let config = SCStreamConfiguration()
        config.width  = Int(min(scWindow.frame.width, maxSize.width))
        config.height = Int(min(scWindow.frame.height, maxSize.height))

        let filter = SCContentFilter(desktopIndependentWindow: scWindow)
        let stream = SCStream(filter: filter, configuration: config, delegate: nil)

        return try await withCheckedThrowingContinuation { continuation in
            let delegate = OneShotDelegate { sampleBuffer in
                guard
                    let sample = sampleBuffer,
                    CMSampleBufferIsValid(sample),
                    let image = SnapshotService.image(from: sample, using: self.ciContext)
                else {
                    continuation.resume(throwing: SnapshotError.captureFailed(nil))
                    return
                }

                continuation.resume(returning: image)

                Task { try? await stream.stopCapture() }
            }

            do {
                try stream.addStreamOutput(delegate, type: .screen, sampleHandlerQueue: .main)
                Task { try await stream.startCapture() }
            } catch {
                continuation.resume(throwing: SnapshotError.captureFailed(error))
            }

            // keep alive until the continuation resumes
            withExtendedLifetime(delegate) {}
            withExtendedLifetime(stream) {}
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
