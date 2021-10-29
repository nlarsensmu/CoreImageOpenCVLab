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
        self.setupFaceFilters()
        
        self.videoManager.setProcessingBlock(newProcessBlock: self.processImage)
        self.videoManager.setCameraPosition(position: .front  )
        
        if !videoManager.isRunning{
            videoManager.start()
        }
    
    
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
                }
                else if filter.name == "CISourceOverCompositing" {
                    filter.setValue(subImage, forKey: kCIInputImageKey)
                    filter.setValue(retImage, forKey: "InputBackgroundImage")
                    retImage = filter.outputImage!
                }
                
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
