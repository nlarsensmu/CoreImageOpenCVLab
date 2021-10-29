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
        
        let filter = CIFilter(name:"CIPinchDistortion")!
        
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
        var filterRadiusX = 0.0
        var filterRadiusY = 0.0
        for f in features {
            //set where to apply filter
            filterCenter.x = f.bounds.midX
            filterCenter.y = f.bounds.midY
            filterRadiusX = (f.bounds.maxX - f.bounds.minX)/2
            filterRadiusY = (f.bounds.maxY - f.bounds.minY)/2
            
            let radialMask = CIFilter(name:"CIRadialGradient")!
            let h = inputImage.extent.size.height
            let w = inputImage.extent.size.width
            
            let cropFilter = CIFilter(name: "CICrop")!
            cropFilter.setValue(inputImage, forKey: kCIInputImageKey)
            let rect = CIVector(cgRect: CGRect(x: f.bounds.minX, y: f.bounds.minY,
                                               width: f.bounds.minX + f.bounds.width, height: f.bounds.minY + f.bounds.height))
            
            cropFilter.setValue(rect, forKey: "inputRectangle")
            
            var subImage = cropFilter.outputImage!
            
            // Add MonoChromeFilter.
            
            let monochromeFilter = CIFilter(name: "CIColorMonochrome")!
            monochromeFilter.setValue(subImage, forKey: kCIInputImageKey)
            monochromeFilter.setValue(CIColor.yellow, forKey: "inputColor")
            subImage = monochromeFilter.outputImage!
            
            let compositeFilter = CIFilter(name:"CISourceOverCompositing")!
            compositeFilter.setValue(subImage, forKey: kCIInputImageKey)
            compositeFilter.setValue(inputImage, forKey: "InputBackgroundImage")
            
            retImage = compositeFilter.outputImage!
            
            return retImage
            
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


// MARK: Useful
// copied from https://stackoverflow.com/questions/27896410/given-a-ciimage-what-is-the-fastest-way-to-write-image-data-to-disk
extension CIImage {

    @objc func saveJPEG(_ name:String, inDirectoryURL:URL? = nil, quality:CGFloat = 1.0) -> String? {
        
        var destinationURL = inDirectoryURL
        
        if destinationURL == nil {
            destinationURL = try? FileManager.default.url(for:.documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        }
        
        if var destinationURL = destinationURL {
            
            destinationURL = destinationURL.appendingPathComponent(name)
            
            if let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) {
                
                do {

                    let context = CIContext()

                    try context.writeJPEGRepresentation(of: self, to: destinationURL, colorSpace: colorSpace, options: [kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption : quality])
                    
                    return destinationURL.path
                    
                } catch {
                    return nil
                }
            }
        }
        
        return nil
    }
}
