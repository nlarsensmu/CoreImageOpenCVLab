//
//  ViewController.swift
//  ImageLab
//
//  Created by Eric Larson
//  Copyright © Eric Larson. All rights reserved.
//

import UIKit
import AVFoundation

class FaceViewController: UIViewController   {

    //MARK: Class Properties
    var filtersFaces : [CIFilter]! = nil
    var filtersEyes : [CIFilter]! = nil
    lazy var videoManager:VideoAnalgesic! = {
        let tmpManager = VideoAnalgesic(mainView: self.view)
        tmpManager.setCameraPosition(position: .back)
        return tmpManager
    }()
    let pinchFilterIndex = 2
    
    lazy var detector:CIDetector! = {
        // create dictionary for face detection
        // HINT: you need to manipulate these properties for better face detection efficiency
        let optsDetector = [CIDetectorAccuracy:CIDetectorAccuracyHigh,
                            CIDetectorTracking:true,
                               CIDetectorSmile:true,
                            CIDetectorEyeBlink:true] as [String : Any]
        
        // setup a face detector in swift
        let detector = CIDetector(ofType: CIDetectorTypeFace,
                                  context: self.videoManager.getCIContext(), // perform on the GPU is possible
            options: (optsDetector as [String : AnyObject]))
        
        return detector
    }()
    
    //MARK: Outlets in view
    @IBOutlet weak var leftEyeOutlet: UILabel!
    @IBOutlet weak var rightEyeOutlet: UILabel!
    @IBOutlet weak var smilingOutlet: UILabel!
    
    //MARK: ViewController Hierarchy
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = nil
        self.setupFaceFilters()
        self.setupEyeFilters()
        
        self.videoManager.setProcessingBlock(newProcessBlock: self.processImage)
        self.videoManager.setCameraPosition(position: .front  )
        
        if !videoManager.isRunning{
            videoManager.start()
        }
    
        // hide all the labels to start
        self.leftEyeOutlet.isHidden = true
        self.rightEyeOutlet.isHidden = true
        self.smilingOutlet.isHidden = true
        
    
    }
    
    //MARK: Setup filtering
    func setupFaceFilters(){
        filtersFaces = []
        
        // Add a crop filter to get only the face
        let cropFilter = CIFilter(name: "CICrop")!
        filtersFaces.append(cropFilter)
        
        // Add MonoChromeFilter.
        let monochromeFilter = CIFilter(name: "CIColorMonochrome")!
        monochromeFilter.setValue(CIColor.yellow, forKey: "inputColor")
        filtersFaces.append(monochromeFilter)
        
        // Add a composite filter to put the new face back in the image.
        let compositeFilter = CIFilter(name:"CISourceOverCompositing")!
        filtersFaces.append(compositeFilter)
        
    }
    
    func setupEyeFilters(){
        filtersEyes = []
        
        // Add a crop filter to get only the face
        let cropFilter = CIFilter(name: "CICrop")!
        filtersEyes.append(cropFilter)
        
        // Add MonoChromeFilter.
        let monochromeFilter = CIFilter(name: "CIColorMonochrome")!
        monochromeFilter.setValue(CIColor.blue, forKey: "inputColor")
        filtersEyes.append(monochromeFilter)
        
        // Add a composite filter to put the new face back in the image.
        let compositeFilter = CIFilter(name:"CISourceOverCompositing")!
        filtersEyes.append(compositeFilter)
        
    }
    
    //MARK: Process image output
    func processImage(inputImage:CIImage) -> CIImage{
        
        // detect faces
        let faces = getFaces(img: inputImage)
        
        // if no faces, just return original image
        if faces.count == 0 { return inputImage }
        
        //otherwise apply the filters to the faces
        return applyFiltersToFaces(inputImage: inputImage, features: faces)
    }
    
    //MARK: Setup Face Detection
    
    func getFaces(img:CIImage) -> [CIFaceFeature]{
        // this ungodly mess makes sure the image is the correct orientation
        let optsFace = [CIDetectorImageOrientation:self.videoManager.ciOrientation,
                                   CIDetectorSmile:true,
                                CIDetectorEyeBlink:true] as [String : Any]
        // get Face Features
        return self.detector.features(in: img, options: optsFace) as! [CIFaceFeature]
    }
    
    //MARK: Apply filters and apply feature detectors
    func applyFiltersToFaces(inputImage:CIImage,features:[CIFaceFeature])->CIImage{
        
        var anyRightEyeClosed = false
        var anyLeftEyeClosed = false
        var anySmile = false
        var retImage = inputImage
        
        for f in features {
            //set where to apply filter
            
            var subImage:CIImage = inputImage
            for filter in filtersFaces {
                // Crop out the face
                if filter.name == "CICrop" {
                    filter.setValue(retImage, forKey: kCIInputImageKey)
                    let rect = CIVector(cgRect: CGRect(x: f.bounds.minX,
                                                       y: f.bounds.minY,
                                                       width: f.bounds.width,
                                                       height: f.bounds.height))
                    filter.setValue(rect, forKey: "inputRectangle")
                    subImage = filter.outputImage!
                }
                // Highlight only the face from the subImage
                else if filter.name == "CIColorMonochrome" {
                    filter.setValue(subImage, forKey: kCIInputImageKey)
                    filter.setValue(CIColor.yellow, forKey: "inputColor")
                    subImage = filter.outputImage!
                    if f.hasRightEyePosition {
                        subImage = applyFiltersToEye(faceImage: subImage,
                                                     position: f.rightEyePosition,
                                                     widthPercent: 1/10,
                                                     heightPercent: 1/5)
                    }
                    if f.hasLeftEyePosition {
                        subImage = applyFiltersToEye(faceImage: subImage,
                                                     position: f.leftEyePosition,
                                                     widthPercent: 1/10,
                                                     heightPercent: 1/5	)
                    }
                    if f.hasMouthPosition {
                        subImage = applyFiltersToEye(faceImage: subImage,
                                                     position: f.mouthPosition,
                                                     widthPercent: 1/8,
                                                     heightPercent: 1/3)
                    }
                }
                else if filter.name == "CISourceOverCompositing" {
                    filter.setValue(subImage, forKey: kCIInputImageKey)
                    filter.setValue(retImage, forKey: "InputBackgroundImage")
                    retImage = filter.outputImage!
                }
            }
            if f.hasSmile && f.hasMouthPosition { anySmile = true }
            if f.leftEyeClosed && f.hasLeftEyePosition { anyLeftEyeClosed = true }
            if f.rightEyeClosed && f.hasRightEyePosition { anyRightEyeClosed = true }
        }
        
        // Act on any face detection
        DispatchQueue.main.async {
            if anySmile { self.smilingOutlet.isHidden = false }
            else { self.smilingOutlet.isHidden = true }
            
            if anyLeftEyeClosed { self.leftEyeOutlet.isHidden = false }
            else { self.leftEyeOutlet.isHidden = true }
            
            if anyRightEyeClosed { self.rightEyeOutlet.isHidden = false }
            else { self.rightEyeOutlet.isHidden = true }
        }
        
        return retImage
    }
    
    // Take the yellow face image and add a blue filter to the eyes
    func applyFiltersToEye(faceImage:CIImage, position:CGPoint, widthPercent:Double, heightPercent:Double) -> CIImage{
        var retImage = faceImage
        
        var subImage = faceImage
        for filter in filtersEyes {
            // Crop out the eye
            if filter.name == "CICrop" {
                filter.setValue(retImage, forKey: kCIInputImageKey)
                let eyeWidth = subImage.extent.width*widthPercent
                let eyeHeight = subImage.extent.height*heightPercent
                let rect = CIVector(cgRect: CGRect(x: position.x-eyeWidth/2,
                                                   y: position.y-eyeHeight/2,
                                                   width: eyeWidth,
                                                   height: eyeHeight))
                
                filter.setValue(rect, forKey: "inputRectangle")
                subImage = filter.outputImage!
            }
            // Highlight only the face from the subImage
            else if filter.name == "CIColorMonochrome" {
                filter.setValue(subImage, forKey: kCIInputImageKey)
                filter.setValue(CIColor.green, forKey: "inputColor")
                subImage = filter.outputImage!
            }
            else if filter.name == "CISourceOverCompositing" {
                filter.setValue(subImage, forKey: kCIInputImageKey)
                filter.setValue(retImage, forKey: "InputBackgroundImage")
                retImage = filter.outputImage!
            }
        }
        
        return retImage
    }
    
    
    
    // change the type of processing done in OpenCV
//    @IBAction func swipeRecognized(_ sender: UISwipeGestureRecognizer) {
//        switch sender.direction {
//        case .left:
//            self.bridge.processType += 1
//        case .right:
//            self.bridge.processType -= 1
//        default:
//            break
//
//        }
//
//        stageLabel.text = "Stage: \(self.bridge.processType)"
//    }


}
