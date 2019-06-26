//
//  SelectAnimationVM.swift
//  photo-to-video-converter
//
//  Created by Serg Liamthev on 6/22/19.
//  Copyright © 2019 serglam. All rights reserved.
//

import UIKit

class SelectAnimationVM {
    
    let transitions: [CATransitionType] = [.fade, .moveIn, .push, .reveal]
    let directions: [CATransitionSubtype] = [.fromLeft, .fromRight, .fromTop, .fromBottom]
    let durations = [0.0, 0.15, 0.25, 0.5, 0.75, 1.0, 1.5, 2.0, 3.0, 4.0]
    
    var imageName = "imageA.jpg"
    
}
