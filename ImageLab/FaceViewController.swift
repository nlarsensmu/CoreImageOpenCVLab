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
    var filters : [CIFilter]! = nil
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
                            CIDetectorTracking:true] as [String : Any]
        
        // setup a face detector in swift
        let detector = CIDetector(ofType: CIDetectorTypeFace,
                                  context: self.videoManager.getCIContext(), // perform on the GPU is possible
            options: (optsDetector as [String : AnyObject]))
        
        return detector
    }()
    
    let bridge = OpenCVBridge()
    
    //MARK: Outlets in view
    
    
    //MARK: ViewController Hierarchy
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = nil
        self.setupFilters()
        
        self.videoManager.setProcessingBlock(newProcessBlock: self.processImage)
        self.videoManager.setCameraPosition(position: .front  )
        
        if !videoManager.isRunning{
            videoManager.start()
        }
    
    
    }
    
    //MARK: Setup filtering
    func setupFilters(){
        filters = []
        
        let filter = CIFilter(name:"CIColorMonochrome")!
        
        filters.append(filter)
        
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
        let optsFace = [CIDetectorImageOrientation:self.videoManager.ciOrientation]
        // get Face Features
        return self.detector.features(in: img, options: optsFace) as! [CIFaceFeature]
        
    }
    
    
    
    //MARK: Apply filters and apply feature detectors
    func applyFiltersToFaces(inputImage:CIImage,features:[CIFaceFeature])->CIImage{
        var retImage = inputImage
        var filterCenter = CGPoint()
        
        for f in features {
            //set where to apply filter
            filterCenter.x = f.bounds.midX
            filterCenter.y = f.bounds.midY
            
            //do for each filter (assumes all filters have property, "inputCenter")
            for filt in filters{
                filt.setValue(retImage, forKey: kCIInputImageKey)
    //                filt.setValue(CIVector(cgPoint: filterCenter), forKey: "inputCenter")
                // could also manipulate the radius of the filter based on face size!
                retImage = filt.outputImage!
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

