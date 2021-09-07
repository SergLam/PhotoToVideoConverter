//
//  LocalFileManager.swift
//  photo-to-video-converter
//
//  Created by Serg Liamthev on 6/23/19.
//  Copyright © 2019 serglam. All rights reserved.
//

import UIKit

class LocalFileManager {
    
    static let shared = LocalFileManager()
    
    static let appCacheDirectoryName = Bundle.main.bundleIdentifier ?? "PhotoToVideoConverter"
    
    private let manager = FileManager.default
    
    /// For image saving
    var cacheDirectoryURL: URL? {
        
        guard let cacheDirectory = manager.urls(for: .cachesDirectory,
                                                in: .userDomainMask).first else {
                                                    assertionFailure("Unable to get cache directory")
                                                    return nil
        }
        let folderURL = cacheDirectory.appendingPathComponent(LocalFileManager.appCacheDirectoryName)
        return manager.fileExists(atPath: folderURL.path) ? folderURL : nil
    }
    
    
    /// For video saving
    var documentsDirectoryURL: URL? {
        guard let cacheDirectory = manager.urls(for: .documentDirectory,
                                                in: .userDomainMask).first else {
                                                    assertionFailure("Unable to get cache directory")
                                                    return nil
        }
        let folderURL = cacheDirectory.appendingPathComponent(LocalFileManager.appCacheDirectoryName)
        return manager.fileExists(atPath: folderURL.path) ? folderURL : nil
    }
    
}


// MARK: - Image storing methods
extension LocalFileManager {
    
    func saveImageToCache(imageName: String, image: UIImage) {
        
        guard let cacheDirectory = createSubFolderInCacheDirectory(folderName: LocalFileManager.appCacheDirectoryName) else {
            assertionFailure("Unable to get cache directory")
            return
        }
        
        guard let data = image.jpegData(compressionQuality: 1) else {
            assertionFailure("Unable to get image data")
            return
        }
        
        let fileURL = cacheDirectory.appendingPathComponent(imageName+".jpeg")
        
        if manager.fileExists(atPath: fileURL.path) {
            do {
                try manager.removeItem(atPath: fileURL.path)
            } catch {
                assertionFailure(error.localizedDescription)
            }
        }
        
        do {
            try data.write(to: fileURL)
        } catch {
            assertionFailure(error.localizedDescription)
        }
    }
    
    func loadImageFromCache(fileName: String) -> UIImage? {
        
        guard let cacheDirectory = cacheDirectoryURL else {
            assertionFailure("Unable to get cache directory")
            return nil
        }
        
        let imageUrl = cacheDirectory.appendingPathComponent(fileName)
        do {
            let imageData = try Data(contentsOf: imageUrl)
            return UIImage(data: imageData)
        } catch {
            assertionFailure(error.localizedDescription)
        }
        return nil
    }
    
    func loadImageURLFromCache(fileName: String) -> URL? {
        
        guard let cacheDirectory = cacheDirectoryURL else {
            assertionFailure("Unable to get cache directory")
            return nil
        }
        
        let imageUrl = cacheDirectory.appendingPathComponent(fileName)
        return imageUrl
    }
    
    func removeImage(filePath: String) {
        
        do {
            try manager.removeItem(atPath: filePath)
        } catch {
            assertionFailure(error.localizedDescription)
        }
    }
    
    func removeAllCachedImages() {
        
        guard let cacheDirectory = cacheDirectoryURL else {
            return
        }
        
        do {
            let fileUrls = try manager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            for fileUrl in fileUrls {
                try manager.removeItem(at: fileUrl)
            }
        } catch {
            assertionFailure(error.localizedDescription)
        }
        
    }
    
    func createSubFolderInCacheDirectory(folderName: String) -> URL? {
        
        guard let cacheDirectory = manager.urls(for: .cachesDirectory,
                                                in: .userDomainMask).first else {
                                                    assertionFailure("Unable to get cache directory")
                                                    return nil
        }
        
        let folderURL = cacheDirectory.appendingPathComponent(folderName)
        // If folder URL does not exist, create it
        if !manager.fileExists(atPath: folderURL.path) {
            do {
                // Attempt to create folder
                try manager.createDirectory(atPath: folderURL.path,
                                            withIntermediateDirectories: true,
                                            attributes: nil)
            } catch {
                // Creation failed.
                assertionFailure(error.localizedDescription)
                return nil
            }
        }
        // Folder either exists, or was created. Return URL
        return folderURL
    }
    
}


// MARK: - Video storing methods
extension LocalFileManager {
  
    func createVideoURL(videoName: String) -> URL? {
        
        guard let documentsDirectory = createSubFolderInDocumentsDirectory(folderName: LocalFileManager.appCacheDirectoryName) else {
            assertionFailure("Unable to get cache directory")
            return nil
        }
        let videoURL = documentsDirectory.appendingPathComponent("\(videoName).mp4")
        return videoURL
    }
    
    @discardableResult
    func createSubFolderInDocumentsDirectory(folderName: String) -> URL? {
        
        guard let documentsDirectory = manager.urls(for: .documentDirectory,
                                                in: .userDomainMask).first else {
                                                    assertionFailure("Unable to get cache directory")
                                                    return nil
        }
        
        let folderURL = documentsDirectory.appendingPathComponent(folderName)
        
        guard manager.fileExists(atPath: folderURL.path) else {
            do {
                try manager.createDirectory(atPath: folderURL.path,
                                            withIntermediateDirectories: true,
                                            attributes: nil)
                return folderURL
            } catch {
                assertionFailure(error.localizedDescription)
                return nil
            }
        }
        
        return folderURL
    }
    
    func removeAllOutputVideos() {
        
        guard let directory = documentsDirectoryURL else {
            return
        }
        
        do {
            let fileUrls = try manager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            for fileUrl in fileUrls {
                try manager.removeItem(at: fileUrl)
            }
        } catch {
            assertionFailure(error.localizedDescription)
        }
        
    }
    
    func checkIfDocumentsDirectoryIsEmpty() -> Bool {
        
        guard let directory = documentsDirectoryURL else {
            assertionFailure("documentsDirectoryURL is nil")
            return false
        }
        do {
            let fileUrls = try manager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            return fileUrls.count == 0
        } catch {
            assertionFailure(error.localizedDescription)
            return false
        }
        
    }
    
}
