//
//  SelectAnimationVC.swift
//  photo-to-video-converter
//
//  Created by Serg Liamthev on 6/22/19.
//  Copyright © 2019 serglam. All rights reserved.
//

import UIKit

class SelectAnimationVC: UIViewController {
    
    /// MARK: - Outlets
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var viewTransitionButton: UIButton!
    @IBOutlet weak var pickerView: UIPickerView!

    private let viewModel = SelectAnimationVM()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configurePickerView()
    }
    
    private func configurePickerView() {
        pickerView.delegate = self
        pickerView.dataSource = self
        
        pickerView.selectRow(viewModel.transitions.count / 2, inComponent: 0, animated: false)
        pickerView.selectRow(viewModel.directions.count / 2, inComponent: 1, animated: false)
        pickerView.selectRow(viewModel.durations.count / 2, inComponent: 2, animated: false)
    }
    
    @IBAction func showTransition(_ sender: UIButton) {
        //Initialize the transition
        let animation = CATransition()
        
        //Set transition properties
        animation.type = viewModel.transitions[pickerView.selectedRow(inComponent: 0)]
        animation.subtype = viewModel.directions[pickerView.selectedRow(inComponent: 1)]
        animation.duration = viewModel.durations[pickerView.selectedRow(inComponent: 2)]
        animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
        
        //Switch the image
        if viewModel.imageName == "imageA.jpg" {
            imageView.image = UIImage(named: "imageB.jpg")
            viewModel.imageName = "imageB.jpg"
        } else {
            imageView.image = UIImage(named: "imageA.jpg")
            viewModel.imageName = "imageA.jpg"
        }
        
        //Add transition to imageView, so that the entire view does not refresh
        imageView.layer.add(animation, forKey: "animation")
    }
}

// MARK: - UIPickerViewDataSource
extension SelectAnimationVC: UIPickerViewDataSource {
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        
        switch component {
        case 0:
            return viewModel.transitions.count
            
        case 1:
            return viewModel.directions.count
            
        case 2:
            return viewModel.durations.count
            
        default:
            return 0
        }
    }
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 3
    }
    
}

extension SelectAnimationVC: UIPickerViewDelegate {
    
    //This method is only necessary because the cameraIris transition sometimes does not go away after the animation is complete
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        
        view.layoutIfNeeded()
        
        switch component {
        case 0:
            UserDefaultsManager.shared.selectedTransition = viewModel.transitions[row].rawValue
            
        case 1:
            UserDefaultsManager.shared.selectedTransitionDirection =  viewModel.directions[row].rawValue
            
        case 2:
            UserDefaultsManager.shared.selectedTransitionDuration = viewModel.durations[row]
            
        default:
            break
        }
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        
        switch component {
        case 0:
            return viewModel.transitions[row].rawValue
            
        case 1:
            return viewModel.directions[row].rawValue
            
        case 2:
            return String(viewModel.durations[row]) + "s"
            
        default:
            return ""
        }
    }
    
}
