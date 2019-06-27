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
    
    
    /// MARK: - Errors
    static let kErrorDomain = Bundle.main.bundleIdentifier ?? "VideoConverter"
    let failedToStartAssetWriterError = NSError.create(domain: kErrorDomain, errorCode: 0,
                                                       description: "AVAssetWriterInputPixelBufferAdapter failed to append pixel buffer")
    
    let failedToAppendPixelBufferError = NSError.create(domain: kErrorDomain, errorCode: 1, description: "AVAssetWriter failed to start writing")
    
    let failedToExportAssetError = NSError.create(domain: kErrorDomain, errorCode: 2, description: "AVAssetExportSession failed")
    let canceledExportAssetError = NSError.create(domain: kErrorDomain, errorCode: 3, description: "AVAssetExportSession canceled")
    let createCompositionError = NSError.create(domain: kErrorDomain, errorCode: 4, description: "Unable to create composition")
    let getVideoTrackError = NSError.create(domain: kErrorDomain, errorCode: 5, description: "Unable to get video track")
    
    let assetExportError = NSError.create(domain: kErrorDomain, errorCode: 6, description: "Unable to create asset export")
    let getCGImageError = NSError.create(domain: kErrorDomain, errorCode: 7, description: "Unable to get cgimage")
    
    // MARK: Properties
    private var videoWriter: AVAssetWriter?
    
    // MARK: Video properties
    var videoURL: URL?
    private var videoFrameDuration = UserDefaultsManager.shared.selectedTransitionDuration ?? 1.0
    private let videoOutputSize = CGSize(width: 1280, height: 720)
    private let videoFPS: Int32 = 30
    
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
                AVVideoWidthKey  : videoOutputSize.width as AnyObject,
                AVVideoHeightKey : videoOutputSize.height as AnyObject
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
                    
                    let duration: Int64 = Int64(Double(self.videoFPS) * self.videoFrameDuration)
                    
                    let currentProgress = Progress(totalUnitCount: Int64(photos.count))
                    
                    for (index, photoURL) in photos.enumerated() {
                        
                        let frameStartTime = index == 0 ? CMTime.zero : CMTime(value: Int64(index) * duration, timescale: self.videoFPS)
                        
                        let lastFrameTime = CMTimeAdd(frameStartTime, CMTime(value: duration / 2, timescale: self.videoFPS))
                        
                        do {
                            try self.writeFrame(photoURL: photoURL, videoWriterInput: videoWriterInput, pixelBufferAdaptor: pixelBufferAdaptor, frameStartTime: frameStartTime, frameEndTime: lastFrameTime)
                        } catch {
                            failure(error as NSError)
                        }
                        
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
                            frameStartTime: CMTime, frameEndTime: CMTime?) throws {
        
        try appendPixelBufferForImageAtURL(photoURL, pixelBufferAdaptor: pixelBufferAdaptor, presentationTime: frameStartTime)
        
        guard let endTime = frameEndTime else {
            return
        }
        
        while !videoWriterInput.isReadyForMoreMediaData {}
        
        try appendPixelBufferForImageAtURL(photoURL, pixelBufferAdaptor: pixelBufferAdaptor, presentationTime: endTime)
    }
    
    private func appendPixelBufferForImageAtURL(_ url: URL, pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor, presentationTime: CMTime) throws {
        
        try autoreleasepool {
            
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
            try fillPixelBufferFromImage(image, pixelBuffer: pixelBuffer)
            
            pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: presentationTime)
            pixelBufferPointer.deinitialize(count: 1)
            pixelBufferPointer.deallocate()
        }
        
    }
    
    private func fillPixelBufferFromImage(_ image: UIImage, pixelBuffer: CVPixelBuffer) throws {
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
            throw(getCGImageError)
        }
        
        context.draw(cgImage, in: CGRect(origin: CGPoint.zero, size: image.size))
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
    }
    
    
    // MARK: - Video animation adding
    private func addAnimationToVideo(videoURL: URL, success: @escaping ((URL) -> Void), failure: @escaping ((NSError) -> Void)) {
        
        let videoAsset: AVURLAsset = AVURLAsset(url: videoURL, options: nil)
        let mixComposition: AVMutableComposition = AVMutableComposition()
        
        guard let compositionVideoTrack = mixComposition.addMutableTrack(withMediaType: .video, preferredTrackID: CMPersistentTrackID()) else {
            assertionFailure("Unable to create composition")
            failure(createCompositionError)
            return
        }
        
        guard let clipVideoTrack = videoAsset.tracks(withMediaType: .video).first else {
            assertionFailure("Unable to get video track")
            failure(getVideoTrackError)
            return
        }
        let timeRange = CMTimeRange(start: CMTime.zero, end: videoAsset.duration)
        
        do {
            try compositionVideoTrack.insertTimeRange(timeRange, of: clipVideoTrack, at: CMTime.zero)
        } catch {
            assertionFailure(error.localizedDescription)
        }
        
        compositionVideoTrack.preferredTransform = clipVideoTrack.preferredTransform
        
        let videoSize: CGSize = clipVideoTrack.naturalSize
        
        let parentLayer = CALayer()
        let videoLayer = CALayer()
        
        parentLayer.frame = CGRect(origin: CGPoint.zero, size: videoSize)
        videoLayer.frame = CGRect(origin: CGPoint.zero, size: videoSize)
        parentLayer.addSublayer(videoLayer)
        
        for index in 0...UserDefaultsManager.shared.selectedImagesCount! - 1 {
            // create the layer with the animation
            let animationLayer = CALayer()
            let nextSceneTime = CMTime(value: Int64(videoFPS * Int32(index)), timescale: videoFPS)
            animationLayer.contents = videoAsset.getImage(at: nextSceneTime)?.cgImage
            animationLayer.frame = CGRect(origin: CGPoint.zero, size: videoSize)
            animationLayer.masksToBounds = true
            let animation = CATransition()
            
            //Set transition properties
            animation.type = CATransitionType(rawValue: UserDefaultsManager.shared.selectedTransition!)
            animation.subtype = CATransitionSubtype(rawValue: UserDefaultsManager.shared.selectedTransitionDirection!)
            animation.beginTime = AVCoreAnimationBeginTimeAtZero
            animation.duration = UserDefaultsManager.shared.selectedTransitionDuration!
            animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
            animation.isRemovedOnCompletion = true
            animationLayer.add(animation, forKey: "animation")
            
            // Hide animation layer after it completion
            let hideAnimation = CABasicAnimation(keyPath: "opacity")
            hideAnimation.duration = CFTimeInterval(mixComposition.duration.value) - animation.duration
            // animate from fully visible to invisible
            hideAnimation.fromValue = 0.0
            hideAnimation.toValue = 0.0
            hideAnimation.beginTime = animation.duration
            hideAnimation.isRemovedOnCompletion = false
            animationLayer.add(hideAnimation, forKey: "animateOpacity")
            
            parentLayer.addSublayer(animationLayer)
        }

        //create the composition and add the instructions to insert the layer:
        
        let videoComp: AVMutableVideoComposition = AVMutableVideoComposition()
        videoComp.renderSize = videoSize
        videoComp.frameDuration = CMTime(value: 1, timescale: videoFPS) // ALARM: most important part
        videoComp.animationTool = AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: videoLayer, in: parentLayer)
        
        /// instruction
        let instruction: AVMutableVideoCompositionInstruction = AVMutableVideoCompositionInstruction()
        
        instruction.timeRange = CMTimeRangeMake(start: CMTime.zero, duration: mixComposition.duration)
        guard let mixVideoTrack: AVAssetTrack = mixComposition.tracks(withMediaType: .video).first else {
            assertionFailure("Unable to video track")
            failure(getVideoTrackError)
            return
        }
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: mixVideoTrack)
        instruction.layerInstructions = [layerInstruction]
        videoComp.instructions = [instruction]
        
        // export video
        guard let assetExport = AVAssetExportSession(asset: mixComposition, presetName: AVAssetExportPresetHighestQuality) else {
            assertionFailure("Unable to create asset export")
            failure(failedToExportAssetError)
            return
        }
        assetExport.videoComposition = videoComp
        
        let videoName = "AnimatedVideo.mp4"
        
        let animatedVideoURL = videoURL.deletingLastPathComponent().appendingPathComponent(videoName)
        
        if FileManager.default.fileExists(atPath: animatedVideoURL.path) {
            do {
                try FileManager.default.removeItem(atPath: animatedVideoURL.path)
            } catch {
                assertionFailure(error.localizedDescription)
                failure(error as NSError)
            }
        }
        
        assetExport.outputFileType = AVFileType.mp4
        assetExport.outputURL = animatedVideoURL
        assetExport.shouldOptimizeForNetworkUse = false
        
        assetExport.exportAsynchronously { [unowned self] in
            
            switch assetExport.status {
                
            case .waiting, .unknown, .exporting:
                debugPrint("Export status: \(assetExport.status.rawValue)")
                
            case .completed:
                
                self.videoURL = animatedVideoURL
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
