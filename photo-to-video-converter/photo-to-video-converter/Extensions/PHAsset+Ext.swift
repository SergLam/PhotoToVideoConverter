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
    
}
