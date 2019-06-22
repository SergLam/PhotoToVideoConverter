//
//  ViewController.swift
//  photo-to-video-converter
//
//  Created by Serg Liamthev on 6/21/19.
//  Copyright © 2019 serglam. All rights reserved.
//

import UIKit
import Photos
import TLPhotoPicker
import DZNEmptyDataSet

class SelectImagesVC: UIViewController {

    @IBOutlet private weak var collectionView: UICollectionView!
    
    private let itemsSpacing: CGFloat = 0.5
    private let viewModel = SelectImagesVM()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCollectionView()
    }
    
    private func setupCollectionView() {
        
//        collectionView.register(SelectedImageCell.self, forCellWithReuseIdentifier: SelectedImageCell.identifier)
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.emptyDataSetSource = self
        collectionView.emptyDataSetDelegate = self
    }

    @IBAction func didTapSelectNavigationItem(_ sender: Any) {
        
        let viewController = TLPhotosPickerViewController()
        
        var configure = TLPhotosPickerConfigure()
        configure.allowedVideo = false
        configure.allowedVideoRecording = true
        
        viewController.configure = configure
        viewController.delegate = self
        present(viewController, animated: true, completion: nil)
    }
    
}

// MARK: - TLPhotosPickerViewControllerDelegate
extension SelectImagesVC: TLPhotosPickerViewControllerDelegate {
    
    func dismissPhotoPicker(withPHAssets: [PHAsset]) {
        
        viewModel.images = withPHAssets
        UserDefaultsManager.shared.selectedImagesCount = withPHAssets.count
    }
    
    func dismissComplete() {
        collectionView.reloadData()
    }
    
    func handleNoAlbumPermissions(picker: TLPhotosPickerViewController) {
        
        AlertPresenter.showPermissionDeniedAlert(at: self, errorMessage: "No Album Permission")
    }
    
    func handleNoCameraPermissions(picker: TLPhotosPickerViewController) {
        
        AlertPresenter.showPermissionDeniedAlert(at: self, errorMessage: "No Camera Permission")
    }
}

// MARK: - UICollectionViewDataSource
extension SelectImagesVC: UICollectionViewDataSource {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return viewModel.images.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: SelectedImageCell.identifier, for: indexPath) as? SelectedImageCell else {
            fatalError("Unable to dequeue cell")
        }
        cell.update(with: viewModel.images[indexPath.row].getAssetThumbnail())
        return cell
    }
    
}


// MARK: - UICollectionViewDelegate
extension SelectImagesVC: UICollectionViewDelegate {
    
}


// MARK: - UICollectionViewDelegateFlowLayout
extension SelectImagesVC: UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = (collectionView.bounds.width / 3) - itemsSpacing * 2
        return CGSize(width: width, height: width)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return itemsSpacing * 2
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return itemsSpacing
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets.zero
    }
    
}

// MARK: - DZNEmptyDataSetSource, DZNEmptyDataSetDelegates
extension SelectImagesVC: DZNEmptyDataSetSource, DZNEmptyDataSetDelegate {
    
    func title(forEmptyDataSet scrollView: UIScrollView!) -> NSAttributedString! {
        
        let string = "Select images for video conversion"
        
        let attributes = [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 18.0, weight: .bold),
                          NSAttributedString.Key.foregroundColor: UIColor.darkGray]
        
        return NSAttributedString(string: string, attributes: attributes)
    }
}
