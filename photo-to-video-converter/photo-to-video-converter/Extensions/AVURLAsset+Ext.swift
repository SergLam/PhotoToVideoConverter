//
//  AVURLAsset+Ext.swift
//  photo-to-video-converter
//
//  Created by Serg Liamthev on 6/27/19.
//  Copyright © 2019 serglam. All rights reserved.
//

import UIKit
import AVFoundation

extension AVURLAsset {
    
    func getImage(at time: CMTime) -> UIImage? {
        
        let generator = AVAssetImageGenerator(asset: self)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceAfter = CMTime.zero
        generator.requestedTimeToleranceBefore = CMTime.zero
        
        do {
            let imageRef = try generator.copyCGImage(at: time, actualTime: nil)
            return UIImage(cgImage: imageRef)
        } catch {
            assertionFailure(error.localizedDescription)
            return nil
        }
        
    }
}
