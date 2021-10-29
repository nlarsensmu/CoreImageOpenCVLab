//
//  FingerViewController.swift
//  ImageLab
//
//  Created by Steven Larsen on 10/29/21.
//  Copyright © 2021 Eric Larson. All rights reserved.
//

import UIKit

class FingerViewController: UIViewController {
    
    let bridge = OpenCVBridge()
    var videoManager:VideoAnalgesic! = nil
    lazy var graph:MetalGraph? = {
        return MetalGraph(mainView: self.view)
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.bridge.loadHaarCascade(withFilename: "nose")
        let dummy = UIView()
        self.videoManager = VideoAnalgesic(mainView: dummy)
        self.videoManager.setCameraPosition(position: AVCaptureDevice.Position.back)
        
        self.videoManager.setProcessingBlock(newProcessBlock: self.processImageSwift)
        
        if !videoManager.isRunning{
            videoManager.start()
        }
        
        graph?.addGraph(withName: "redness",
                        shouldNormalize: true,
                        numPointsInGraph: 100)
        
        Timer.scheduledTimer(timeInterval: 0.05, target: self,
            selector: #selector(self.updateGraph),
            userInfo: nil,
            repeats: true)
        
    }
    @objc
    func updateGraph(){
        //TOD: Remove dummy data
        let data = bridge.getRedData()
        var arrayData = [Float]()
        if bridge.captured100() {
            if let data = bridge.getRedData(){
              
            }
        }else{
            
        }
        //TODO: Diplay the redness to the graph
//        self.graph?.updateGraph(
//            data: bridge.getRedData(),
//            forKey: "redness"
//        )
        //TODO:Figure out how to process the data
        
    }
    func processImageSwift(inputImage:CIImage) -> CIImage{
        
        
        var retImage = inputImage
        
        //HINT: you can also send in the bounds of the face to ONLY process the face in OpenCV
        // or any bounds to only process a certain bounding region in OpenCV
        self.bridge.setTransforms(self.videoManager.transform)
        self.bridge.setImage(retImage,
                             withBounds: retImage.extent, // the first face bounds
                             andContext: self.videoManager.getCIContext())
        
//        self.bridge.processImage()
        let finger = self.bridge.processFinger()
        
        if finger {
            fingerDetected()
        } else {
            noFingerDetected()
        }
        
        retImage = self.bridge.getImageComposite() // get back opencv processed part of the image (overlayed on original)
        
        
        
        return retImage
    }
    func fingerDetected() {
        DispatchQueue.main.async {
            self.videoManager.turnOnFlashwithLevel(0.5)
        }
    }
    func noFingerDetected() {
        DispatchQueue.main.async {
            self.videoManager.turnOffFlash()
        }
    }
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
