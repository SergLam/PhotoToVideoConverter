//
//  AlertPresenter.swift
//  SwiftCoreTraining
//
//  Created by Serg Liamthev on 3/23/19.
//  Copyright © 2019 serglam. All rights reserved.
//

import UIKit

class AlertPresenter {
    
    static func showError(at vc: UIViewController, error: String) {
        
        DispatchQueue.main.async {
            let alert = UIAlertController(title: "Error", message: error, preferredStyle: .alert)
            let action = UIAlertAction(title: "Ok", style: .default) { _ in }
            alert.addAction(action)
            vc.present(alert, animated: true, completion: nil)
        }
    }
    
    static func showPermissionDeniedAlert(at vc: UIViewController, errorMessage: String) {
        
        DispatchQueue.main.async {
            let alert = UIAlertController(title: "Error", message: errorMessage, preferredStyle: .alert)
            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
            let openSettignsAction = UIAlertAction(title: "Open app settings", style: .default) { (_) in
                guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(settingsURL)
            }
            alert.addAction(cancelAction)
            alert.addAction(openSettignsAction)
            vc.present(alert, animated: true, completion: nil)
        }
    }
    
    static func showSuccessMessage(at vc: UIViewController, message: String) {
        
        DispatchQueue.main.async {
            let alert = UIAlertController(title: "Success", message: message, preferredStyle: .alert)
            let action = UIAlertAction(title: "Ok", style: .default) { _ in }
            alert.addAction(action)
            vc.present(alert, animated: true, completion: nil)
        }
    }
    
}
