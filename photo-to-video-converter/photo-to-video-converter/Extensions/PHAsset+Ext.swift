//
//  PHAsset+Ext.swift
//  photo-to-video-converter
//
//  Created by Serg Liamthev on 6/22/19.
//  Copyright © 2019 serglam. All rights reserved.
//

import Photos
import UIKit

extension PHAsset {
    
    func getAssetThumbnail() -> UIImage? {
        
        let manager = PHImageManager.default()
        let option = PHImageRequestOptions()
        var thumbnail: UIImage?
        option.isSynchronous = true
        manager.requestImage(for: self, targetSize: CGSize(width: UIScreen.width / 3, height: UIScreen.width / 3), contentMode: .aspectFit, options: option, resultHandler: { (result, info) -> Void in
            thumbnail = result
        })
        return thumbnail
    }
    
    func getImage() -> UIImage? {
        
        let manager = PHImageManager.default()
        let option = PHImageRequestOptions()
        
        var resultImage: UIImage?
        option.isSynchronous = true
        option.deliveryMode = .highQualityFormat
        manager.requestImage(for: self, targetSize: CGSize(width: self.pixelWidth, height: self.pixelHeight), contentMode: .aspectFit, options: option) { (image, info) in
            resultImage = image
        }
        return resultImage
    }
    
    func getImage(width: CGFloat, height: CGFloat) -> UIImage? {
        
        let manager = PHImageManager.default()
        let option = PHImageRequestOptions()
        
        var resultImage: UIImage?
        option.isSynchronous = true
        option.deliveryMode = .highQualityFormat
        manager.requestImage(for: self, targetSize: CGSize(width: width, height: height), contentMode: .aspectFit, options: option) { (image, info) in
            resultImage = image
        }
        return resultImage
    }
    
}
