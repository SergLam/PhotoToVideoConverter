//
//  UserDefaultsManager.swift
//  photo-to-video-converter
//
//  Created by Serg Liamthev on 6/22/19.
//  Copyright © 2019 serglam. All rights reserved.
//

import Foundation
import UIKit

final class UserDefaultsManager {
    
    static let shared = UserDefaultsManager()
    
    private let defaults = UserDefaults.standard
    
    var selectedImagesCount: Int? {
        get {
            return defaults.integer(forKey: #function)
        }
        set {
            defaults.set(newValue, forKey: #function)
        }
    }
    
    var selectedTransition: String? {
        get {
            return defaults.string(forKey: #function)
        }
        set {
            defaults.set(newValue, forKey: #function)
        }
    }
    
    var selectedTransitionDirection: String? {
        get {
            return defaults.string(forKey: #function)
        }
        set {
            defaults.set(newValue, forKey: #function)
        }
    }
    
    var selectedTransitionDuration: Double? {
        get {
            return defaults.double(forKey: #function)
        }
        set {
            defaults.set(newValue, forKey: #function)
        }
    }
    
    func setDefaultValues() {
        
        let viewModel = SelectAnimationVM()
        selectedTransition = viewModel.transitions[viewModel.transitions.count / 2]
        selectedTransitionDirection = viewModel.directions[viewModel.directions.count / 2].rawValue
        selectedTransitionDuration = viewModel.durations[viewModel.durations.count / 2]
        selectedImagesCount = 0
    }

    
}
