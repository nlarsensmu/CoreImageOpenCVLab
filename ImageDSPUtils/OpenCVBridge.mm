//
//  OpenCVBridge.m
//  LookinLive
//
//  Created by Eric Larson.
//  Copyright (c) Eric Larson. All rights reserved.
//

#import "OpenCVBridge.hh"
#import <Accelerate/Accelerate.h>

using namespace cv;

@interface OpenCVBridge()
@property (nonatomic) cv::Mat image;
@property (strong,nonatomic) CIImage* frameInput;
@property (nonatomic) CGRect bounds;
@property (nonatomic) CGAffineTransform transform;
@property (nonatomic) CGAffineTransform inverseTransform;
@property (atomic) cv::CascadeClassifier classifier;
@end

@implementation OpenCVBridge



#pragma mark ===Write Your Code Here===
// alternatively you can subclass this class and override the process image function
//varaible to keep track of the redData
//position we are in the array
int pos = 0;

//have we captured encough data
bool capturedEnough = false;
-(bool) capturedEnough{
    return capturedEnough;
}

//Is there a finger over the camera
bool fingerSensed = false;
-(bool) fingerSensed {
    return fingerSensed;
}

//return just the actual array that has the red data
-(float*)getRedData{
    return red;
}

//reset the poistion to 0, should happen when the finger moves
-(void)resetPos{
    pos = 0;
}
//Get the last red value, should be used to add oto the graph
-(float)getLastRed{
    return lastRed;
}

//reset the arrays collecting data and move the pos back to the begining of the array
-(void)resetBuffer {
    for (int i = 0; i < BUFFER_SIZE; i++) {
        red[i] = 0.0;
        green[i] = 0.0;
        blue[i] = 0.0;
    }
    //It is imporant this is not 0, if it was 0 then the code might stop sensing a finger
    pos = skippedValues;
    capturedEnough = false;
}

//amoutn of data we are colecting
const int BUFFER_SIZE = 200;
-(int)getBufferSize {
    return BUFFER_SIZE;
}


const int beforeFlashIndex = 2;     //when a finger is detected we stay on for this many frames as the flash turns on
const int flashTurningOnIndex = 30; //we will not include the first 30 frames in our analyis
const int skippedValues = beforeFlashIndex + flashTurningOnIndex; //we will only insert into array with index pos - skippedValues

float red[BUFFER_SIZE];
float green[BUFFER_SIZE];
float blue[BUFFER_SIZE];
float lastRed = 0.0;

//called every frame there is a finger
-(bool)processFinger:(int *)peaksOut
                outD:(int *)distOut {
    
    *peaksOut = 0;
    *distOut = 0;
    
    cv::Mat frame_gray,image_copy;
    
    Scalar avgPixelIntensity;
    
    cvtColor(_image, image_copy, CV_BGRA2BGR); // get rid of alpha for processing
    avgPixelIntensity = cv::mean( image_copy );
    
    float ts = 40;
    if(pos < beforeFlashIndex) { // to capture the finger initially
        ts = 40;
    }
    else if(pos < flashTurningOnIndex) { // Always think there is a finger from frames 2-10
        // Since there is a huge flash of color as the light turns on.
        ts = 999;
    } else { // to capture the finger after the light is established
        ts = 60;
    }
    
    fingerSensed = avgPixelIntensity.val[2] + avgPixelIntensity.val[1] < ts;
    
    if(pos < BUFFER_SIZE + skippedValues && fingerSensed && pos >= skippedValues) { // If the finger was sensed and we need more samples
        // Ignore the frist two (beforeFlashIndex) frames they tend to be off
        red[pos - skippedValues] = avgPixelIntensity.val[0];
        lastRed = avgPixelIntensity.val[0];
        green[pos - skippedValues] = avgPixelIntensity.val[1];
        blue[pos - skippedValues] = avgPixelIntensity.val[2];
        pos++;
        capturedEnough = false;
    }
    else if (pos < skippedValues && fingerSensed) { // The finger was sensed and we are accpeting it no matter what
        pos++;
        capturedEnough = false;
    }
    else if (!fingerSensed) { // The finger has left the screen
        pos = 0;
        capturedEnough = false;
    } else { // We have captured enough
        capturedEnough = true;
    }
    return fingerSensed;
}


#pragma mark Define Custom Functions Here

#pragma mark ====Do Not Manipulate Code below this line!====
-(void)setTransforms:(CGAffineTransform)trans{
    self.inverseTransform = trans;
    self.transform = CGAffineTransformInvert(trans);
}

-(void)loadHaarCascadeWithFilename:(NSString*)filename{
    NSString *filePath = [[NSBundle mainBundle] pathForResource:filename ofType:@"xml"];
    self.classifier = cv::CascadeClassifier([filePath UTF8String]);
}

-(instancetype)init{
    self = [super init];
    
    if(self != nil){
        self.transform = CGAffineTransformMakeRotation(M_PI_2);
        self.transform = CGAffineTransformScale(self.transform, -1.0, 1.0);
        
        self.inverseTransform = CGAffineTransformMakeScale(-1.0,1.0);
        self.inverseTransform = CGAffineTransformRotate(self.inverseTransform, -M_PI_2);
        
        
    }
    return self;
}

#pragma mark Bridging OpenCV/CI Functions
// code manipulated from
// http://stackoverflow.com/questions/30867351/best-way-to-create-a-mat-from-a-ciimage
// http://stackoverflow.com/questions/10254141/how-to-convert-from-cvmat-to-uiimage-in-objective-c


-(void) setImage:(CIImage*)ciFrameImage
      withBounds:(CGRect)faceRectIn
      andContext:(CIContext*)context{
    
    CGRect faceRect = CGRect(faceRectIn);
    faceRect = CGRectApplyAffineTransform(faceRect, self.transform);
    ciFrameImage = [ciFrameImage imageByApplyingTransform:self.transform];
    
    
    //get face bounds and copy over smaller face image as CIImage
    //CGRect faceRect = faceFeature.bounds;
    _frameInput = ciFrameImage; // save this for later
    _bounds = faceRect;
    CIImage *faceImage = [ciFrameImage imageByCroppingToRect:faceRect];
    CGImageRef faceImageCG = [context createCGImage:faceImage fromRect:faceRect];
    
    // setup the OPenCV mat fro copying into
    CGColorSpaceRef colorSpace = CGImageGetColorSpace(faceImageCG);
    CGFloat cols = faceRect.size.width;
    CGFloat rows = faceRect.size.height;
    cv::Mat cvMat(rows, cols, CV_8UC4); // 8 bits per component, 4 channels
    _image = cvMat;
    
    // setup the copy buffer (to copy from the GPU)
    CGContextRef contextRef = CGBitmapContextCreate(cvMat.data,                // Pointer to backing data
                                                    cols,                      // Width of bitmap
                                                    rows,                      // Height of bitmap
                                                    8,                         // Bits per component
                                                    cvMat.step[0],             // Bytes per row
                                                    colorSpace,                // Colorspace
                                                    kCGImageAlphaNoneSkipLast |
                                                    kCGBitmapByteOrderDefault); // Bitmap info flags
    // do the copy
    CGContextDrawImage(contextRef, CGRectMake(0, 0, cols, rows), faceImageCG);
    
    // release intermediary buffer objects
    CGContextRelease(contextRef);
    CGImageRelease(faceImageCG);
    
}

-(CIImage*)getImage{
    
    // convert back
    // setup NS byte buffer using the data from the cvMat to show
    NSData *data = [NSData dataWithBytes:_image.data
                                  length:_image.elemSize() * _image.total()];
    
    CGColorSpaceRef colorSpace;
    if (_image.elemSize() == 1) {
        colorSpace = CGColorSpaceCreateDeviceGray();
    } else {
        colorSpace = CGColorSpaceCreateDeviceRGB();
    }
    
    // setup buffering object
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    
    // setup the copy to go from CPU to GPU
    CGImageRef imageRef = CGImageCreate(_image.cols,                                     // Width
                                        _image.rows,                                     // Height
                                        8,                                              // Bits per component
                                        8 * _image.elemSize(),                           // Bits per pixel
                                        _image.step[0],                                  // Bytes per row
                                        colorSpace,                                     // Colorspace
                                        kCGImageAlphaNoneSkipLast | kCGBitmapByteOrderDefault,  // Bitmap info flags
                                        provider,                                       // CGDataProviderRef
                                        NULL,                                           // Decode
                                        false,                                          // Should interpolate
                                        kCGRenderingIntentDefault);                     // Intent
    
    // do the copy inside of the object instantiation for retImage
    CIImage* retImage = [[CIImage alloc]initWithCGImage:imageRef];
    CGAffineTransform transform = CGAffineTransformMakeTranslation(self.bounds.origin.x, self.bounds.origin.y);
    retImage = [retImage imageByApplyingTransform:transform];
    retImage = [retImage imageByApplyingTransform:self.inverseTransform];
    
    // clean up
    CGImageRelease(imageRef);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(colorSpace);
    
    return retImage;
}

-(CIImage*)getImageComposite{
    
    // convert back
    // setup NS byte buffer using the data from the cvMat to show
    NSData *data = [NSData dataWithBytes:_image.data
                                  length:_image.elemSize() * _image.total()];
    
    CGColorSpaceRef colorSpace;
    if (_image.elemSize() == 1) {
        colorSpace = CGColorSpaceCreateDeviceGray();
    } else {
        colorSpace = CGColorSpaceCreateDeviceRGB();
    }
    
    // setup buffering object
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    
    // setup the copy to go from CPU to GPU
    CGImageRef imageRef = CGImageCreate(_image.cols,                                     // Width
                                        _image.rows,                                     // Height
                                        8,                                              // Bits per component
                                        8 * _image.elemSize(),                           // Bits per pixel
                                        _image.step[0],                                  // Bytes per row
                                        colorSpace,                                     // Colorspace
                                        kCGImageAlphaNoneSkipLast | kCGBitmapByteOrderDefault,  // Bitmap info flags
                                        provider,                                       // CGDataProviderRef
                                        NULL,                                           // Decode
                                        false,                                          // Should interpolate
                                        kCGRenderingIntentDefault);                     // Intent
    
    // do the copy inside of the object instantiation for retImage
    CIImage* retImage = [[CIImage alloc]initWithCGImage:imageRef];
    // now apply transforms to get what the original image would be inside the Core Image frame
    CGAffineTransform transform = CGAffineTransformMakeTranslation(self.bounds.origin.x, self.bounds.origin.y);
    retImage = [retImage imageByApplyingTransform:transform];
    CIFilter* filt = [CIFilter filterWithName:@"CISourceAtopCompositing"
                          withInputParameters:@{@"inputImage":retImage,@"inputBackgroundImage":self.frameInput}];
    retImage = filt.outputImage;
    
    // clean up
    CGImageRelease(imageRef);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(colorSpace);
    
    retImage = [retImage imageByApplyingTransform:self.inverseTransform];
    
    return retImage;
}

@end
