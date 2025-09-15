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
    func snapshot(window: Window) async throws -> NSImage
}

public final class SnapshotService: SnapshotServiceProtocol {
    private let ciContext = CIContext()

    public init() {}

    public func snapshot(window: Window) async throws -> NSImage {
        let content: SCShareableContent
        do {
            content = try await SCShareableContent.current
        } catch {
            throw SnapshotError.permissionDenied
        }
        
        
        
        guard let scWindow = content.windows.first(where: {
            guard let owningPID = $0.owningApplication?.processID else { return false }
            
            // Check title match
            let titleMatches = window.title.isEmpty || ($0.title ?? "").localizedCaseInsensitiveContains(window.title)
            
            // Check windowID match if possible
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

        // Hold these strong until the task completes!
        class StreamHolder {
            var delegate: OneShotDelegate?
            var stream: SCStream?
        }
        let holder = StreamHolder()

        return try await withCheckedThrowingContinuation { continuation in
            var didResume = false

            let delegate = OneShotDelegate { sampleBuffer in
                guard !didResume else { return }
                didResume = true

                guard
                    let sample = sampleBuffer,
                    CMSampleBufferIsValid(sample),
                    let image = SnapshotService.image(from: sample, using: self.ciContext)
                else {
                    continuation.resume(throwing: SnapshotError.captureFailed(nil))
                    return
                }

                continuation.resume(returning: image)

                // Stop stream and break strong ref
                Task {
                    try? await holder.stream?.stopCapture()
                    holder.delegate = nil
                    holder.stream = nil
                }
            }
            holder.delegate = delegate
            holder.stream = stream

            do {
                try stream.addStreamOutput(delegate, type: .screen, sampleHandlerQueue: .main)
                Task { try await stream.startCapture() }
            } catch {
                if !didResume {
                    didResume = true
                    continuation.resume(throwing: SnapshotError.captureFailed(error))
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
