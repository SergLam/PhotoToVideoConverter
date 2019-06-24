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
    
    let kErrorDomain = Bundle.main.bundleIdentifier ?? "VideoConverter"
    let kFailedToStartAssetWriterError = 0
    let kFailedToAppendPixelBufferError = 1
    
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
            self.delegate?.didFetchVideoURL(url: url)
            self.delegate?.didReceiveSuccess(message: "Successfully converted video:\n \(url.absoluteString)")
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
    
    func build(photos: [URL],_ progress: @escaping ((Progress) -> Void), success: @escaping ((URL) -> Void), failure: @escaping ((NSError) -> Void)) {
        
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
                    
                    let frameDuration = CMTimeMake(value: duration, timescale: fps)
                    let currentProgress = Progress(totalUnitCount: Int64(photos.count))
                    
                    for (index, photoURL) in photos.enumerated() {

                        let frameStartTime = index == 0 ? CMTime.zero : CMTimeMake(value: Int64(index), timescale: 1)

                        let lastFrameTime = index == 0 ? CMTimeMake(value: 1, timescale: 1) : CMTimeMake(value: Int64(index) * duration, timescale: fps)
                        let frameEndTime = CMTimeAdd(lastFrameTime, frameDuration)

                        if !self.appendPixelBufferForImageAtURL(photoURL, pixelBufferAdaptor: pixelBufferAdaptor, presentationTime: frameStartTime) {
                            error = NSError(
                                domain: self.kErrorDomain,
                                code: self.kFailedToAppendPixelBufferError,
                                userInfo: ["description": "AVAssetWriterInputPixelBufferAdapter failed to append pixel buffer"]
                            )
                            break
                        }
                        
                        while !videoWriterInput.isReadyForMoreMediaData {}
                        
                        if !self.appendPixelBufferForImageAtURL(photoURL, pixelBufferAdaptor: pixelBufferAdaptor, presentationTime: frameEndTime) {
                            error = NSError(
                                domain: self.kErrorDomain,
                                code: self.kFailedToAppendPixelBufferError,
                                userInfo: ["description": "AVAssetWriterInputPixelBufferAdapter failed to append pixel buffer"]
                            )
                            break
                        }

                        currentProgress.completedUnitCount = Int64(index+1)
                        progress(currentProgress)

                    }
                    
//                    for (index, photoURL) in photos.enumerated() {
//
//                        let lastFrameTime = CMTimeMake(value: Int64(index) * duration, timescale: fps)
//                        let presentationTime = index == 0 ? lastFrameTime : CMTimeAdd(lastFrameTime, frameDuration)
//
//                        if !self.appendPixelBufferForImageAtURL(photoURL, pixelBufferAdaptor: pixelBufferAdaptor, presentationTime: presentationTime) {
//                            error = NSError(
//                                domain: self.kErrorDomain,
//                                code: self.kFailedToAppendPixelBufferError,
//                                userInfo: ["description": "AVAssetWriterInputPixelBufferAdapter failed to append pixel buffer"]
//                            )
//                            break
//                        }
//                        currentProgress.completedUnitCount = Int64(index+1)
//                        progress(currentProgress)
//
//                    }
                    
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
                error = NSError(
                    domain: kErrorDomain,
                    code: kFailedToStartAssetWriterError,
                    userInfo: ["description": "AVAssetWriter failed to start writing"]
                )
            }
        }
        guard let err = error else {
            return
        }
        failure(err)
        self.delegate?.didReceivedError(error: err.localizedDescription)
    }
    
    func appendPixelBufferForImageAtURL(_ url: URL, pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor, presentationTime: CMTime) -> Bool {
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
    
    func fillPixelBufferFromImage(_ image: UIImage, pixelBuffer: CVPixelBuffer) {
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
    
}
