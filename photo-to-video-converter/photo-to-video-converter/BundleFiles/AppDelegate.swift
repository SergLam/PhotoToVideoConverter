//
//  AppDelegate.swift
//  photo-to-video-converter
//
//  Created by Serg Liamthev on 6/21/19.
//  Copyright © 2019 serglam. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        UserDefaultsManager.shared.setDefaultValues()
        return true
    }

}

