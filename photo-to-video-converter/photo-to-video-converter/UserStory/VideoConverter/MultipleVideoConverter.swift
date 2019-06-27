//
//  MultipleVideoConverter.swift
//  photo-to-video-converter
//
//  Created by Andrii Mazepa on 6/27/19.
//  Copyright © 2019 serglam. All rights reserved.
//

import Foundation
import AVFoundation

class MultipleVideoConverter {
    
    // Set the transition duration time to two seconds.
    let transDuration = CMTimeMake(value: 2, timescale: 1)
    
    // The movies below have the same dimensions as the movie I want to generate
    let movieSize = CGSize(width: 1280, height: 720)
    
    // This is the preset applied to the AVAssetExportSession.
    // If the passthrough preset is used then the created movie file has two video
    // tracks but the transitions between the segments in each track are lost.
    // Other presets will generate a file with a single video track with the
    // transitions applied before export happens.
    // let exportPreset = AVAssetExportPresetPassthrough
    let exportPreset = AVAssetExportPreset1280x720
    
    // Path and file name to where the generated movie file will be created.
    // If a previous file was at this location it will be deleted before the new
    // file is generated. BEWARE
    let exportFilePath: NSString = "~/Desktop/TransitionsMovie.mov"
    
    // Create the list of paths to movie files that generated movie will transition between.
    // The movies need to not have any copy protection.
    let movieFilePaths = [
        "~/Movies/clips/410_clip1.mov",
        "~/Movies/clips/410_clip2.mov",
        "~/Movies/clips/410_clip3.mov",
        "~/Movies/clips/410_clip4.mov",
        "~/Movies/clips/410_clip5.mov",
        "~/Movies/clips/410_clip6.mov"
    ]
    
    // Convert the file paths into URLS after expanding any tildes in the path
    let urls = movieFilePaths.map({ (filePath) -> URL in
        return URL(fileURLWithPath: filePath, isDirectory: false)
    })
    
    // Make movie assets from the URLs.
    let movieAssets:[AVURLAsset] = urls.map { AVURLAsset(url: $0, options: .none) }
    
    // Create the mutable composition that we are going to build up.
    var composition = AVMutableComposition()
    
    // Function to build the composition tracks.
    func buildCompositionTracks(composition: AVMutableComposition,
                                transitionDuration: CMTime,
                                assetsWithVideoTracks: [AVURLAsset]) -> Void {
        
        let compositionTrackA = composition.addMutableTrack(withMediaType: .video,
                                                            preferredTrackID: CMPersistentTrackID(kCMPersistentTrackID_Invalid))
        
        let compositionTrackB = composition.addMutableTrack(withMediaType: .video,
                                                            preferredTrackID: CMPersistentTrackID(kCMPersistentTrackID_Invalid))
        
        let videoTracks = [compositionTrackA, compositionTrackB]
        
        var cursorTime = CMTime.zero
        
        for i in 0...assetsWithVideoTracks.count {
            
            let trackIndex = i % 2
            let currentTrack = videoTracks[trackIndex]
            let assetTrack = assetsWithVideoTracks[i].tracks(withMediaType: .video).first!
            let timeRange = CMTimeRangeMake(start: CMTime.zero, duration: assetsWithVideoTracks[i].duration)
            
            do {
                try currentTrack?.insertTimeRange(timeRange, of: assetTrack, at: cursorTime)
            } catch {
                assertionFailure(error.localizedDescription)
            }
            
            // Overlap clips by tranition duration // 4
            cursorTime = CMTimeAdd(cursorTime, assetsWithVideoTracks[i].duration)
            cursorTime = CMTimeSubtract(cursorTime, transitionDuration)
        }
        
        // Currently leaving out voice overs and movie tracks. // 5
    }
    
    // Function to calculate both the pass through time and the transition time ranges
    func calculateTimeRanges(transitionDuration: CMTime, assetsWithVideoTracks: [AVURLAsset])
        -> (passThroughTimeRanges: [NSValue], transitionTimeRanges: [NSValue]) {
            
            var passThroughTimeRanges:[NSValue] = [NSValue]()
            var transitionTimeRanges:[NSValue] = [NSValue]()
            var cursorTime = CMTime.zero
            
            for i in 0...assetsWithVideoTracks.count {
                
                let asset = assetsWithVideoTracks[i]
                var timeRange = CMTimeRangeMake(start: cursorTime, duration: asset.duration)
                
                if i > 0 {
                    timeRange.start = CMTimeAdd(timeRange.start, transDuration)
                    timeRange.duration = CMTimeSubtract(timeRange.duration, transDuration)
                }
                
                if i + 1 < assetsWithVideoTracks.count {
                    timeRange.duration = CMTimeSubtract(timeRange.duration, transDuration)
                }
                
                passThroughTimeRanges.append(NSValue(timeRange: timeRange))
                cursorTime = CMTimeAdd(cursorTime, asset.duration)
                cursorTime = CMTimeSubtract(cursorTime, transDuration)
                // println("cursorTime.value: \(cursorTime.value)")
                // println("cursorTime.timescale: \(cursorTime.timescale)")
                
                if i + 1 < assetsWithVideoTracks.count {
                    timeRange = CMTimeRangeMake(start: cursorTime, duration: transDuration)
                    // println("timeRange start value: \(timeRange.start.value)")
                    // println("timeRange start timescale: \(timeRange.start.timescale)")
                    transitionTimeRanges.append(NSValue(timeRange: timeRange))
                }
            }
            return (passThroughTimeRanges, transitionTimeRanges)
    }
    
    // Build the video composition and instructions.
    func buildVideoCompositionAndInstructions( composition: AVMutableComposition,
                                               passThroughTimeRanges: [NSValue],
                                               transitionTimeRanges: [NSValue],
                                               renderSize: CGSize) -> AVMutableVideoComposition {
        
        // Create a mutable composition instructions object
        var compositionInstructions = [AVMutableVideoCompositionInstruction]()
        
        // Get the list of asset tracks and tell compiler they are a list of asset tracks.
        let tracks = composition.tracks(withMediaType: .video) as [AVAssetTrack]
        
        // Create a video composition object
        let videoComposition = AVMutableVideoComposition(propertiesOf: composition)
        
        // Now create the instructions from the various time ranges.
        for i in 0...passThroughTimeRanges.count {
            
            let trackIndex = i % 2
            let currentTrack = tracks[trackIndex]
            let instruction = AVMutableVideoCompositionInstruction()
            instruction.timeRange = passThroughTimeRanges[i].timeRangeValue
            
            let layerInstruction = AVMutableVideoCompositionLayerInstruction(
                assetTrack: currentTrack)
            instruction.layerInstructions = [layerInstruction]
            compositionInstructions.append(instruction)
            
            if i < transitionTimeRanges.count {
                let instruction = AVMutableVideoCompositionInstruction()
                instruction.timeRange = transitionTimeRanges[i].timeRangeValue
                
                // Determine the foreground and background tracks.
                let fgTrack = tracks[trackIndex]
                let bgTrack = tracks[1 - trackIndex]
                
                // Create the "from layer" instruction.
                let fLInstruction = AVMutableVideoCompositionLayerInstruction(
                    assetTrack: fgTrack)
                
                // Make the opacity ramp and apply it to the from layer instruction.
                fLInstruction.setOpacityRamp(fromStartOpacity: 1.0,
                                             toEndOpacity:0.0,
                                             timeRange: instruction.timeRange)
                
                // Create the "to layer" instruction. Do I need this?
                let tLInstruction = AVMutableVideoCompositionLayerInstruction(
                    assetTrack: bgTrack)
                instruction.layerInstructions = [fLInstruction, tLInstruction]
                compositionInstructions.append(instruction)
            }
        }
        videoComposition.instructions = compositionInstructions
        videoComposition.renderSize = renderSize
        videoComposition.frameDuration = CMTimeMake(value: 1, timescale: 30)
        videoComposition.renderScale = 1.0 // This is a iPhone only option.
        
        return videoComposition
    }
    
    func makeExportSession(preset: String,
                           videoComposition: AVMutableVideoComposition,
                           composition: AVMutableComposition) -> AVAssetExportSession {
        
        let session = AVAssetExportSession(asset: composition, presetName: preset)!
        session.videoComposition = videoComposition.copy() as? AVVideoComposition
        
        session.outputFileType = AVFileType.mp4
        // session.outputFileType = AVFileType.mov
        return session
    }
    
    func convertMultipleVideos() {
        
        // Now call the functions to do the preperation work for preparing a composition to export.
        // First create the tracks needed for the composition.
        buildCompositionTracks(composition: composition,
                               transitionDuration: transDuration,
                               assetsWithVideoTracks: movieAssets)
        
        // Create the passthru and transition time ranges.
        let timeRanges = calculateTimeRanges(transitionDuration: transDuration,
                                             assetsWithVideoTracks: movieAssets)
        
        // Create the instructions for which movie to show and create the video composition.
        let videoComposition = buildVideoCompositionAndInstructions(
            composition: composition,
            passThroughTimeRanges: timeRanges.passThroughTimeRanges,
            transitionTimeRanges: timeRanges.transitionTimeRanges,
            renderSize: movieSize)
        
        // Make the export session object that we'll use to export the transition movie
        let exportSession = makeExportSession(preset: exportPreset,
                                              videoComposition: videoComposition,
                                              composition: composition)
        
        // Make a expanded file path for export. Delete any previous generated file.
        let expandedFilePath = exportFilePath.expandingTildeInPath
        try? FileManager.default.removeItem(atPath: expandedFilePath)
        
        // Assign the output URL built from the expanded output file path.
        exportSession.outputURL = URL(fileURLWithPath: expandedFilePath, isDirectory: false)
        
        // Since export happens asyncrhonously then this command line tool can exit
        // before the export has completed unless we wait until the export has finished.
        let sessionWaitSemaphore = DispatchSemaphore(value: 0)
        exportSession.exportAsynchronously(completionHandler: {
            sessionWaitSemaphore.signal()
            return
        })
        
        switch sessionWaitSemaphore.wait(timeout: DispatchTime.distantFuture) {
            
        case .success:
            print("Export finished")
        case .timedOut:
            assertionFailure("Some thing went wrong")
        }
        
    }
    
}
