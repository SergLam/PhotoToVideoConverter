//
//  NSError+Ext.swift
//  photo-to-video-converter
//
//  Created by Andrii Mazepa on 6/25/19.
//  Copyright © 2019 serglam. All rights reserved.
//

import Foundation

extension NSError {
    
    static func create(domain: String, errorCode: Int, description: String) -> NSError {
        
        return NSError(domain: domain, code: errorCode, userInfo: ["description": description])
    }
}
