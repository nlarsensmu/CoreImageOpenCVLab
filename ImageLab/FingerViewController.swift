//
//  FingerViewController.swift
//  ImageLab
//
//  Created by Steven Larsen on 10/29/21.
//  Copyright © 2021 Eric Larson. All rights reserved.
//

import UIKit
import Accelerate

class FingerViewController: UIViewController {
    
    // MARK: Class Variables
    let debug = true
    let bridge = OpenCVBridge()
    var videoManager:VideoAnalgesic! = nil
    lazy var graph:MetalGraph? = {
        return MetalGraph(mainView: self.view)
    }()
    var PPG = 0.0
    var fingerDataPos = 0
    var fingerData:[Float] = []
    
    
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
                        shouldNormalize: false,
                        numPointsInGraph: 100)
        
        fingerData = Array.init(repeating: 0.0, count:Int(bridge.getBufferSize()))
        
        Timer.scheduledTimer(timeInterval: 0.05, target: self,
            selector: #selector(self.updateFingerData),
            userInfo: nil,
            repeats: true)
        Timer.scheduledTimer(timeInterval: 0.05, target: self,
            selector: #selector(self.updateGraph),
            userInfo: nil,
            repeats: true)
        
    }
    
    // MARK: UI Objects
    
    @IBOutlet weak var PPGReadingLabel: UILabel!
    @IBOutlet weak var peaksLabelDebug: UILabel!
    @IBOutlet weak var distanceLabelDebug: UILabel!
    
    func getFingerDataInOrder() -> [Float]{
        
        if fingerDataPos >= 100 {
            var data:[Float] = []
            data.append(contentsOf: fingerData[fingerDataPos-100..<fingerDataPos])
            return data
        }
        
        var data:[Float] = []
        data.append(contentsOf: fingerData[fingerData.count - (100 - fingerDataPos)..<fingerData.count])
        data.append(contentsOf: fingerData[0..<fingerDataPos])
        return data
    }
    
    @objc
    func updateGraph() {
        
        self.graph?.updateGraph(
            data: getFingerDataInOrder(),
            forKey: "redness"
        )
        
    }
    
    @objc
    func updateFingerData() {
        //TOD: Remove dummy data
        
        var redData: UnsafeMutablePointer<Float>
        
        // If the phone has captured enough frames to make a reading on PPG.
        if bridge.capturedEnough() {
            redData = bridge.getRedData()
            
            let (peaks, dist) = windowedMaxFor(nums: redData, windowSize: 10, arraySize: Int(bridge.getBufferSize()))
            
            if debug {
                DispatchQueue.main.async {
                    self.peaksLabelDebug.text = String(format: "%d", peaks)
                    self.distanceLabelDebug.text = String(format: "%d", dist)
                }
            }
            
            let FPS = 30.0
            let seconds = Double(dist)/FPS
            if seconds == 0.0 { return } // dont crash if the phone is on the table
            PPG = Double(peaks)/seconds*60
            
            DispatchQueue.main.async {
                self.PPGReadingLabel.text = String(format: "PPG Reading: %.2lf", self.PPG)
            }
            
            bridge.resetBuffer()
        }
        else if bridge.fingerSensed() && PPG == 0.0 {
            DispatchQueue.main.async {
                self.PPGReadingLabel.text = "Reading"
            }
        }
        else if !bridge.fingerSensed() { // Fill in 0 for no data, if the finger is not there.
            PPG = 0.0
            DispatchQueue.main.async {
                self.PPGReadingLabel.text = "Not Reading"
            }
        }
        //TODO:Figure out how to process the data
        
        if bridge.fingerSensed() { // Only graph every other point
            fingerData[fingerDataPos] = bridge.getLastRed()/255*0.2
            fingerDataPos = (fingerDataPos + 1) % fingerData.count
        }
        
    }
    
    
    func processImageSwift(inputImage:CIImage) -> CIImage{
        
        
        var retImage = inputImage
        
        //HINT: you can also send in the bounds of the face to ONLY process the face in OpenCV
        // or any bounds to only process a certain bounding region in OpenCV
        self.bridge.setTransforms(self.videoManager.transform)
        self.bridge.setImage(retImage,
                             withBounds: retImage.extent, // the first face bounds
                             andContext: self.videoManager.getCIContext())
        
        self.bridge.processImage()
        var distance:Int32 = 0
        var peaks:Int32 = 0
        let finger = self.bridge.processFinger(&peaks, outD: &distance)

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
    
    // MARK: Peak finding from pervious lab
    
    // Take a set of readings, return the count of peaks, and the distance
    // from the first peak to the last peak
    func windowedMaxFor(nums:UnsafeMutablePointer<Float>, windowSize:Int, arraySize:Int) -> (Int, Int) {
        
        var max = nums[0]
        var peakCount = 0
        var repeatCount = 0
        var firstMax = -1
        var lastMax = -1

        var maxes:[(Int, Float)] = []
        for i in 0..<arraySize - windowSize{
            let maxPoint = getMaxPoint(startIndex: i, endIndex: i + windowSize, arr: nums)
            let currMax = maxPoint.1
            //we are in a platue
            if currMax == max{
                repeatCount += 1
            }
            //We have left the platue need to add the median index
            else if repeatCount >= windowSize {
                if firstMax == -1 { firstMax = i } // the first peak found
                lastMax = i // The last peak found
                peakCount += 1
                repeatCount = 0
                maxes.append(maxPoint)
            }
            else{
                repeatCount = 1
                max = currMax
            }
        }
        
        return (peakCount - 1, lastMax-firstMax) // Don't count the last peak found
    }
    
    func getMaxPoint(startIndex:Int, endIndex:Int, arr:UnsafeMutablePointer<Float>) -> (Int, Float) {
        
//        var data = arr[10...11]
//        var a:[Float] = data[startIndex...endIndex]
        let a = arr+startIndex
        var c: Float = .nan
        var i: vDSP_Length = 0
        let n = vDSP_Length(endIndex - startIndex)
        
        vDSP_maxvi(a, 1, &c, &i, n)
        return (startIndex + Int(i), Float(c))
        
//        var max = arr[startIndex]
//        var maxIndex = startIndex
//        for i in startIndex + 1...endIndex{
//            if arr[i] > max {
//                max = arr[i]
//                maxIndex = i
//            }
//        }
//        return (maxIndex, max)
    }
}
