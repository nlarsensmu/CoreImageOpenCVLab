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
                        shouldNormalize: false,
                        numPointsInGraph: 1000)
        
        Timer.scheduledTimer(timeInterval: 0.05, target: self,
            selector: #selector(self.updateGraph),
            userInfo: nil,
            repeats: true)
        
    }
    @objc
    func updateGraph(){
        //TOD: Remove dummy data
        var dummyData:[Float] = [Float]()
        for _ in 0..<1000{
            dummyData.append(Float(1))
        }
        var redData: UnsafeMutablePointer<Float>
        if bridge.captured100() {
            redData = bridge.getRedData()
            for i in 0..<1000{
                dummyData[i] = redData[i] - 240
            }
            var beats = windowedMaxFor(nums: dummyData, windowSize: 18)
            for i in 0..<1000 {
                print("(\(i),\(dummyData[i]))")
            }
            var a = 0
            //TODO: Diplay the redness to the graph
        }
        else{
            for i in 0..<1000{
                dummyData[i] = 0
            }
        }
        self.graph?.updateGraph(
            data: dummyData,
            forKey: "redness"
        )


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
        
        self.bridge.processImage()
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
    func windowedMaxFor(nums:[Float], windowSize:Int) -> Int {
        
        var max = nums[0]
        var peakCount = 0
        var repeatCount = 0

        for i in 0..<nums.count - windowSize{
            let maxes = getMaxPoint(startIndex: i, endIndex: i + windowSize, arr: nums)
            let currMax = maxes.1
            //we are in a platue
            if currMax == max{
                repeatCount += 1
            }
            //We have left the platue need to add the median index
            else if repeatCount >= 2 {
                peakCount += 1
                repeatCount = 0
            }
            else{
                repeatCount = 0
                max = currMax
            }
        }
        return peakCount
    }
    func getMaxPoint(startIndex:Int, endIndex:Int, arr:[Float]) -> (Int, Float) {
        var max = arr[startIndex]
        var maxIndex = startIndex
        for i in startIndex + 1...endIndex{
            if arr[i] > max {
                max = arr[i]
                maxIndex = i
            }
        }
        return (maxIndex, max)
    }
}
