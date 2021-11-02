//
//  OpenCVBridge.h
//  LookinLive
//
//  Created by Eric Larson.
//  Copyright (c) Eric Larson. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreImage/CoreImage.h>
#import "AVFoundation/AVFoundation.h"

#import "PrefixHeader.pch"

@interface OpenCVBridge : NSObject

@property (nonatomic) NSInteger processType;


// set the image for processing later
-(void) setImage:(CIImage*)ciFrameImage
      withBounds:(CGRect)rect
      andContext:(CIContext*)context;

//get the image raw opencv
-(CIImage*)getImage;

//get the image inside the original bounds
-(CIImage*)getImageComposite;

// call this to perfrom processing (user controlled for better transparency)
-(void)processImage;

// for the video manager transformations
-(void)setTransforms:(CGAffineTransform)trans;

-(void)loadHaarCascadeWithFilename:(NSString*)filename;
-(bool)processFinger:(int *)peaksOut
                outD:(int *)distOut;
-(bool)capturedEnough;
-(bool)fingerSensed;
-(float*)getRedData;
-(float)getLastRed;
-(int)getBufferSize;

-(void)resetBuffer;
-(int)getFundamentalPeaksFromBuffer:(float *)magBuffer
                              withLength:(NSUInteger)length
                         usingWindowSize:(NSUInteger)windowSize
                 andPeakMagnitudeMinimum:(float)peakMagnitude
                    distanceBetweenPeaks:(long *)dist;
@end
