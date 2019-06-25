//
//  VideoConverterVM.swift
//  photo-to-video-converter
//
//  Created by Serg Liamthev on 6/22/19.
//  Copyright © 2019 serglam. All rights reserved.
//

import UIKit
import AVFoundation
import Photos

protocol VideoConverterVMDelegate: class {
    
    func didReceivedError(error: String)
    func didReceiveSuccess(message: String)
    func didReceivedUnauthorizedError(error: String)
    func didFetchVideoURL(url: URL)
}

class VideoConverterVM {
    
    weak var delegate: VideoConverterVMDelegate?
    
    private static let kErrorDomain = Bundle.main.bundleIdentifier ?? "VideoConverter"
    let failedToStartAssetWriterError = NSError(domain: VideoConverterVM.kErrorDomain, code: 0,
                                                userInfo: ["description": "AVAssetWriterInputPixelBufferAdapter failed to append pixel buffer"])
    let failedToAppendPixelBufferError = NSError(domain: VideoConverterVM.kErrorDomain, code: 1,
                                                 userInfo: ["description": "AVAssetWriter failed to start writing"])
    let failedToExportAssetError = NSError(domain: VideoConverterVM.kErrorDomain, code: 2,
                                           userInfo: ["description": "AVAssetExportSession failed"])
    let canceledExportAssetError = NSError(domain: VideoConverterVM.kErrorDomain, code: 3,
                                           userInfo: ["description": "AVAssetExportSession canceled"])
    
    private var videoWriter: AVAssetWriter?
    
    var videoURL: URL?
    var videoFrameDuration = UserDefaultsManager.shared.selectedTransitionDuration ?? 1.0
    
    func convertVideo() {
        
        guard let photosCount = UserDefaultsManager.shared.selectedImagesCount, photosCount > 0 else {
            delegate?.didReceivedError(error: "Please, select photos first")
            return
        }
        let imgNames: [String] = Array(0...photosCount-1).compactMap { return"\($0).jpeg" }
        
        let photosURLs = imgNames.compactMap { LocalFileManager.shared.loadImageURLFromCache(fileName: $0) }
        
        LocalFileManager.shared.createSubFolderInDocumentsDirectory(folderName: LocalFileManager.appCacheDirectoryName)
        
        build(photos: photosURLs, { (progress) in
            debugPrint(progress)
        }, success: { [unowned self] (url) in
            //            self.delegate?.didFetchVideoURL(url: url)
            //            self.delegate?.didReceiveSuccess(message: "Successfully converted video:\n \(url.absoluteString)")
            self.addAnimationToVideo(videoURL: url, success: { (url) in
                
                self.delegate?.didFetchVideoURL(url: url)
                self.delegate?.didReceiveSuccess(message: "Successfully converted video:\n \(url.absoluteString)")
                
            }, failure: { (error) in
                self.delegate?.didReceivedError(error: error.localizedDescription)
            })
        }) { [unowned self] (error) in
            self.delegate?.didReceivedError(error: error.localizedDescription)
        }
        
    }
    
    func exportVideo() {
        
        guard !LocalFileManager.shared.checkIfDocumentsDirectoryIsEmpty() else {
            delegate?.didReceivedError(error: "Convert video firstly")
            return
        }
        
        guard let url = videoURL else {
            assertionFailure("Unable to fetch video url")
            return
        }
        
        PHPhotoLibrary.requestAuthorization { [unowned self] status in
            
            guard status == .authorized else {
                self.delegate?.didReceivedUnauthorizedError(error: "Access to photos library is restricted")
                return
            }
            
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            }) { [unowned self] success, error in
                guard let error = error else {
                    guard success else {
                        self.delegate?.didReceivedError(error: "\(#function) failed to export video")
                        return
                    }
                    self.delegate?.didReceiveSuccess(message: "Successfully exported video")
                    return
                }
                self.delegate?.didReceivedError(error: error.localizedDescription)
            }
        }
    }
    
}


// MARK: - Video conversion methods
extension VideoConverterVM {
    
    private func build(photos: [URL],_ progress: @escaping ((Progress) -> Void), success: @escaping ((URL) -> Void), failure: @escaping ((NSError) -> Void)) {
        
        guard let data = try? Data(contentsOf: photos.first!), let image = UIImage(data: data) else {
            assertionFailure("Unable to get first image")
            return
        }
        let inputSize = CGSize(width: image.size.width, height: image.size.height)
        let outputSize = CGSize(width: 1280, height: 720)
        var error: NSError?
        
        guard let documentsPath = LocalFileManager.shared.documentsDirectoryURL else {
            assertionFailure("Unable to get documents directory url")
            return
        }
        
        let videoOutputURL = documentsPath.appendingPathComponent("AssembledVideo.mp4")
        
        do {
            try FileManager.default.removeItem(at: videoOutputURL)
        } catch {}
        
        do {
            try videoWriter = AVAssetWriter(outputURL: videoOutputURL, fileType: AVFileType.mp4)
        } catch let writerError as NSError {
            error = writerError
            videoWriter = nil
        }
        
        if let videoWriter = videoWriter {
            let videoSettings: [String : AnyObject] = [
                AVVideoCodecKey  : AVVideoCodecType.h264 as AnyObject,
                AVVideoWidthKey  : outputSize.width as AnyObject,
                AVVideoHeightKey : outputSize.height as AnyObject
            ]
            
            let videoWriterInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: videoSettings)
            
            let sourceBufferAttributes = [
                (kCVPixelBufferPixelFormatTypeKey as String): Int(kCVPixelFormatType_32ARGB),
                (kCVPixelBufferWidthKey as String): Float(inputSize.width),
                (kCVPixelBufferHeightKey as String): Float(inputSize.height)] as [String : Any]
            
            let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
                assetWriterInput: videoWriterInput,
                sourcePixelBufferAttributes: sourceBufferAttributes
            )
            
            assert(videoWriter.canAdd(videoWriterInput))
            videoWriter.add(videoWriterInput)
            
            if videoWriter.startWriting() {
                videoWriter.startSession(atSourceTime: CMTime.zero)
                assert(pixelBufferAdaptor.pixelBufferPool != nil)
                
                let media_queue = DispatchQueue(label: "mediaInputQueue")
                
                videoWriterInput.requestMediaDataWhenReady(on: media_queue) { [unowned self] in
                    let fps: Int32 = 30
                    let duration: Int64 = Int64(Double(fps) * self.videoFrameDuration)
                    
                    let currentProgress = Progress(totalUnitCount: Int64(photos.count))
                    
                    for (index, photoURL) in photos.enumerated() {
                        
                        let frameStartTime = index == 0 ? CMTime.zero : CMTimeMake(value: Int64(index) * duration, timescale: fps)
                        
                        let lastFrameTime = CMTimeAdd(frameStartTime, CMTimeMake(value: duration / 2, timescale: fps))
                        
                        error = self.writeFrame(photoURL: photoURL, videoWriterInput: videoWriterInput, pixelBufferAdaptor: pixelBufferAdaptor, frameStartTime: frameStartTime, frameEndTime: lastFrameTime)
                        
                        currentProgress.completedUnitCount = Int64(index+1)
                        progress(currentProgress)
                        
                    }
                    
                    videoWriterInput.markAsFinished()
                    videoWriter.finishWriting {
                        if let error = error {
                            failure(error)
                        } else {
                            self.videoURL = videoOutputURL
                            success(videoOutputURL)
                        }
                        
                        self.videoWriter = nil
                    }
                }
            } else {
                error = failedToAppendPixelBufferError
            }
        }
        guard let err = error else {
            return
        }
        failure(err)
    }
    
    private func writeFrame(photoURL: URL,
                            videoWriterInput: AVAssetWriterInput,
                            pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor,
                            frameStartTime: CMTime, frameEndTime: CMTime?) -> NSError? {
        if !self.appendPixelBufferForImageAtURL(photoURL, pixelBufferAdaptor: pixelBufferAdaptor, presentationTime: frameStartTime) {
            return failedToStartAssetWriterError
        }
        
        guard let endTime = frameEndTime else {
            return nil
        }
        
        while !videoWriterInput.isReadyForMoreMediaData {}
        if !self.appendPixelBufferForImageAtURL(photoURL, pixelBufferAdaptor: pixelBufferAdaptor, presentationTime: endTime) {
            return failedToStartAssetWriterError
        }
        return nil
    }
    
    private func appendPixelBufferForImageAtURL(_ url: URL, pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor, presentationTime: CMTime) -> Bool {
        var appendSucceeded = false
        
        autoreleasepool {
            
            guard let imageData = try? Data(contentsOf: url),
                let image = UIImage(data: imageData),
                let pixelBufferPool = pixelBufferAdaptor.pixelBufferPool else {
                    assertionFailure("error")
                    return
            }
            
            let pixelBufferPointer = UnsafeMutablePointer<CVPixelBuffer?>.allocate(capacity: 1)
            let status: CVReturn = CVPixelBufferPoolCreatePixelBuffer(
                kCFAllocatorDefault,
                pixelBufferPool,
                pixelBufferPointer
            )
            
            guard let pixelBuffer = pixelBufferPointer.pointee, status == 0 else {
                assertionFailure("error: Failed to allocate pixel buffer from pool")
                return
            }
            fillPixelBufferFromImage(image, pixelBuffer: pixelBuffer)
            
            appendSucceeded = pixelBufferAdaptor.append(
                pixelBuffer,
                withPresentationTime: presentationTime
            )
            pixelBufferPointer.deinitialize(count: 1)
            pixelBufferPointer.deallocate()
        }
        
        return appendSucceeded
    }
    
    private func fillPixelBufferFromImage(_ image: UIImage, pixelBuffer: CVPixelBuffer) {
        CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
        
        let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer)
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: pixelData,
            width: Int(image.size.width),
            height: Int(image.size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: rgbColorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
            ) else {
                assertionFailure("Unable to create context")
                return
        }
        guard let cgImage = image.cgImage else {
            assertionFailure("Unable to get cgimage")
            return
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height))
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
    }
    
    private func addAnimationToVideo(videoURL: URL, success: @escaping ((URL) -> Void), failure: @escaping ((NSError) -> Void)) {
        
        let videoAsset: AVURLAsset = AVURLAsset(url: videoURL, options: nil)
        let mixComposition: AVMutableComposition = AVMutableComposition()
        
        guard let compositionVideoTrack = mixComposition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            assertionFailure("Unable to create composition")
            return
        }
        
        guard let clipVideoTrack = videoAsset.tracks(withMediaType: .video).first else {
            assertionFailure("Unable to video track")
            return
        }
        let timeRange = CMTimeRange(start: CMTime.zero, end: videoAsset.duration)
        
        do {
            try compositionVideoTrack.insertTimeRange(timeRange, of: clipVideoTrack, at: CMTime.zero)
        } catch {
            assertionFailure(error.localizedDescription)
        }
        
        compositionVideoTrack.preferredTransform = clipVideoTrack.preferredTransform
        
        guard let videoTrack: AVAssetTrack = videoAsset.tracks(withMediaType: .video).first else {
            assertionFailure("Unable to video track")
            return
        }
        let videoSize: CGSize = videoTrack.naturalSize
        
        //  create the layer with the animation
        let animationLayer = CALayer()
        animationLayer.frame = CGRect(x: 0, y: 0, width: videoSize.width, height: videoSize.height)
        let animation = CATransition()
        
        //Set transition properties
        animation.type = CATransitionType(rawValue: UserDefaultsManager.shared.selectedTransition!)
        animation.subtype = CATransitionSubtype.init(rawValue: UserDefaultsManager.shared.selectedTransitionDirection!)
        animation.duration = UserDefaultsManager.shared.selectedTransitionDuration!
        animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
        
        animationLayer.add(animation, forKey: "animation")
        
        //sorts the layer in proper order
        let parentLayer = CALayer()
        let videoLayer = CALayer()
        parentLayer.frame = CGRect(x: 0, y: 0, width: videoSize.width, height: videoSize.height)
        videoLayer.frame = CGRect(x: 0, y: 0, width: videoSize.width, height: videoSize.height)
        parentLayer.addSublayer(videoLayer)
        parentLayer.addSublayer(animationLayer)
        
        //create the composition and add the instructions to insert the layer:
        
        let videoComp: AVMutableVideoComposition = AVMutableVideoComposition()
        videoComp.renderSize = videoSize
        videoComp.frameDuration = CMTime(value: 1, timescale: 30)
        videoComp.animationTool = AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: videoLayer, in: parentLayer)
        
        /// instruction
        let instruction: AVMutableVideoCompositionInstruction = AVMutableVideoCompositionInstruction()
        
        instruction.timeRange = CMTimeRangeMake(start: CMTime.zero, duration: mixComposition.duration)
        guard let mixVideoTrack: AVAssetTrack = mixComposition.tracks(withMediaType: .video).first else {
            assertionFailure("Unable to video track")
            return
        }
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: mixVideoTrack)
        instruction.layerInstructions = [layerInstruction]
        videoComp.instructions = [instruction]
        
        // export video
        guard let assetExport = AVAssetExportSession(asset: mixComposition, presetName: AVAssetExportPresetHighestQuality) else {
            assertionFailure("Unable to create asset export")
            return
        }
        assetExport.videoComposition = videoComp
        
        let videoName = "AnimatedVideo.mp4"
        
        let animatedVideoURL = videoURL.deletingLastPathComponent().appendingPathComponent(videoName)
        assetExport.outputFileType = AVFileType.mp4
        assetExport.outputURL = animatedVideoURL
        assetExport.shouldOptimizeForNetworkUse = true
        
        assetExport.exportAsynchronously { [unowned self] in
            
            switch assetExport.status {
                
            case .waiting, .unknown, .exporting:
                debugPrint("Export status: \(assetExport.status.rawValue)")
                
            case .completed:
                success(animatedVideoURL)
                
            case .failed:
                failure(self.failedToExportAssetError)
                
            case .cancelled:
                failure(self.canceledExportAssetError)
                
            @unknown default:
                fatalError()
            }
        }
    }
    
}
