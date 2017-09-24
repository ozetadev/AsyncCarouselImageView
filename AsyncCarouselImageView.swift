//
//  AsyncImageView.swift
//  Monkey
//
//  Created by Philip Bernstein on 9/2/17.
//  Copyright © 2017 Monkey Squad. All rights reserved.
//

import UIKit
import Alamofire

protocol AsyncImageDelegate {
    /// Notifies the delegate that the image has been loaded so it can display the image
    func asyncImage(_ asyncImage:AsyncImage, didLoad success:Bool)
}

class AsyncCarouselImageView: UIImageView, AsyncImageDelegate {
    /// An array containing all the images that need to be loaded async
    private var asyncImages:[AsyncImage] = []
    /// The index of the current image being displayed
    private var currentIndex = 0
    /// When true, indicator that the next image should auto display when it finishes loading
    var waitingForNextImage = false
    
    func loadURLs(_ urls:[URL]) {
        for url in urls {
            let asyncImage = AsyncImage(url: url)
            asyncImage.delegate = self
            asyncImage.startRequest()
            asyncImages.append(asyncImage)
        }
    }
    
    /// Stops loading any images that havent been fully loaded
    func cancel() {
        for image in self.asyncImages {
            image.cancelRequest()
        }
    }
    
    func asyncImage(_ asyncImage:AsyncImage, didLoad success:Bool) {
        guard success else {
            return
        }
        
        guard self.asyncImages.count != 0 else { // fix crash when user tries tapping out of tutorial before first image is loaded
            // image is loading indicator for the user
            self.waitingForNextImage = true
            return
        }
        
        if currentIndex == -1 {
            currentIndex = 0
        }
        
        guard (self.asyncImages[currentIndex].url == asyncImage.url) || (self.waitingForNextImage && self.asyncImages[currentIndex + 1].url == asyncImage.url) else {
            return
        }
        
        guard Achievements.shared.shownInstagramTutorial else {
            return
        }
        
        self.image = asyncImage.image
    }
    
    /// Displays the next image in the CarouselView
    /// Note: also handles corner cases, like dismissing the tutorial adn wrapping around once user hs reached end
    func next() {
        
        if self.asyncImages.count <= currentIndex + 1 || !Achievements.shared.shownInstagramTutorial {
            currentIndex = -1
        }
        
        guard self.asyncImages.count != 0 else { // fix crash when user tries tapping out of tutorial before first image is loaded
            // image is loading indicator for the user
            return
        }
        
        guard let nextImage = self.asyncImages[currentIndex+1] as? AsyncImage, let loadedImage = nextImage.image else {
            waitingForNextImage = true
            return
        }
        
        self.currentIndex = currentIndex + 1
        self.image = loadedImage
    }
    
    deinit {
        self.cancel()
        self.asyncImages.removeAll()
    }
}

class AsyncImage {
    /// The URL of the image to load
    let url:URL
    /// The loaded image
    var image:UIImage?
    var dataRequest:DataRequest?
    var delegate:AsyncImageDelegate?
    
    init(url: URL) {
        self.url = url
    }
    
    func startRequest() {
        guard self.dataRequest == nil else {
            return
        }
        
        self.dataRequest = Alamofire.request(self.url, method: .get)
            .validate(statusCode: 200..<300)
            .responseData { [weak self] (response) in
                guard let `self` = self else { return }
                switch response.result {
                case .success(let data):
                    self.image = UIImage(data: data)
                    self.delegate?.asyncImage(self, didLoad: true)
                    break
                case .failure(let error):
                    print("Image load error: \(error)")
                    self.delegate?.asyncImage(self, didLoad: false)
                    break
                }
        }
    }
    func cancelRequest() {
        self.dataRequest?.cancel()
        self.dataRequest = nil
    }
    deinit {
        self.cancelRequest()
    }
}
