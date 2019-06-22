//
//  VideoConverterVC.swift
//  photo-to-video-converter
//
//  Created by Serg Liamthev on 6/22/19.
//  Copyright © 2019 serglam. All rights reserved.
//

import UIKit
import AVKit
import AVFoundation

class VideoConverterVC: UIViewController {
    
    /// MARK: - Outlets
    @IBOutlet weak var photosCountLabel: UILabel!
    @IBOutlet weak var selectedTransitionLabel: UILabel!
    @IBOutlet weak var selectedDurationLabel: UILabel!
    
    @IBOutlet weak var videoPreviewImage: UIImageView!
    
    private let viewModel = VideoConverterVM()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        addImageGesture()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        showSelectedValues()
    }
    
    private func showSelectedValues() {
        
        let defaults = UserDefaultsManager.shared
        photosCountLabel.text = "Photos count: \(String(describing: defaults.selectedImagesCount!))"
        selectedTransitionLabel.text = "Selected transition: \(String(describing: defaults.selectedTransition!))-\(String(describing: defaults.selectedTransitionDirection!))"
        selectedDurationLabel.text = "Selected duration: \(String(defaults.selectedTransitionDuration!))s"
    }
    
    private func addImageGesture() {
        
        let singleTap = UITapGestureRecognizer(target: self, action: #selector(showVideo(recognizer:)))
        singleTap.numberOfTapsRequired = 1
        videoPreviewImage.addGestureRecognizer(singleTap)
    }
    
    // MARK: - Actions
    @IBAction func didTapConvertVideo(_ sender: UIButton) {
        
        viewModel.convertVideo()
    }
    
    
    @IBAction func didTapExportVideo(_ sender: UIButton) {
        
        viewModel.exportVideo()
    }
    
    @objc func showVideo(recognizer: UITapGestureRecognizer) {
        
        let videoURL = URL(string: "https://clips.vorwaerts-gmbh.de/big_buck_bunny.mp4")
        let player = AVPlayer(url: videoURL!)
        let playerViewController = AVPlayerViewController()
        playerViewController.player = player
        self.present(playerViewController, animated: true) {
            playerViewController.player!.play()
        }
    }
    
}
