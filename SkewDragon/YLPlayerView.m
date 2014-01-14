//
//  YLPlayerView.m
//  SkewDragon
//
//  Created by Yung-Luen Lan on 1/14/14.
//  Copyright (c) 2014 Yung-Luen Lan. All rights reserved.
//

#import "YLPlayerView.h"
@import AVFoundation.AVPlayerItemOutput;

#define FREEWHEELING_PERIOD_IN_SECONDS 0.5
#define ADVANCE_INTERVAL_IN_SECONDS 0.1

@interface YLPlayerView ()
{
    AVPlayerItem *_playerItem;
	CVDisplayLinkRef _displayLink;
	CMVideoFormatDescriptionRef _videoInfo;
	
	uint64_t _lastHostTime;
	dispatch_queue_t _queue;
}
@property (nonatomic, strong) AVPlayerItemVideoOutput *playerItemVideoOutput;
@property (nonatomic, strong) NSImage *faceImage;
@end

@interface YLPlayerView (AVPlayerItemOutputPullDelegate) <AVPlayerItemOutputPullDelegate>
@end

@implementation YLPlayerView

static CVReturn displayLinkCallback(CVDisplayLinkRef displayLink, const CVTimeStamp *inNow, const CVTimeStamp *inOutputTime, CVOptionFlags flagsIn, CVOptionFlags *flagsOut, void *displayLinkContext);

- (id) initWithFrame: (NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _queue = dispatch_queue_create(NULL, NULL);
        self.playerItemVideoOutput = [[AVPlayerItemVideoOutput alloc] initWithPixelBufferAttributes: @{(id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32ARGB)}];
        if (self.playerItemVideoOutput) {
            // Create a CVDisplayLink to receive a callback at every vsync
			CVDisplayLinkCreateWithActiveCGDisplays(&_displayLink);
			CVDisplayLinkSetOutputCallback(_displayLink, displayLinkCallback, (__bridge void *)self);
			// Pause the displayLink till ready to conserve power
			CVDisplayLinkStop(_displayLink);
			// Request notification for media change in advance to start up displayLink or any setup necessary
			[_playerItemVideoOutput setDelegate: self queue: _queue];
			[_playerItemVideoOutput requestNotificationOfMediaDataChangeWithAdvanceInterval: ADVANCE_INTERVAL_IN_SECONDS];

        }
        
        self.videoLayer = [[AVSampleBufferDisplayLayer alloc] init];
		self.videoLayer.bounds = self.bounds;
		self.videoLayer.position = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
		self.videoLayer.videoGravity = AVLayerVideoGravityResizeAspect;
		self.videoLayer.backgroundColor = CGColorGetConstantColor(kCGColorBlack);
        
		[self setLayer: self.videoLayer];
		[self setWantsLayer: YES];
        
        self.detector = [CIDetector detectorOfType: CIDetectorTypeFace context: nil options: @{CIDetectorAccuracy: CIDetectorAccuracyHigh, CIDetectorTracking: @YES}];
        self.faceImage = [NSImage imageNamed: @"face.png"];
    }
    return self;
}

- (void) viewWillMoveToSuperview: (NSView *)newSuperview
{
	if (!newSuperview) {
        
		if (_videoInfo) CFRelease(_videoInfo);
		
		if (_displayLink)
		{
			CVDisplayLinkStop(_displayLink);
			CVDisplayLinkRelease(_displayLink);
		}
        
		dispatch_sync(_queue, ^{
			[self.playerItemVideoOutput setDelegate: nil queue: NULL];
		});
	}
}

#pragma mark -
- (void) setPlayerItem: (AVPlayerItem *)aPlayerItem
{
    if (_playerItem != aPlayerItem) {
        if (_playerItem) [_playerItem removeOutput: self.playerItemVideoOutput];
        
        _playerItem = aPlayerItem;
        
        if (_playerItem) [_playerItem addOutput: self.playerItemVideoOutput];
    }
}

#pragma mark -

- (void) displayPixelBuffer: (CVPixelBufferRef)pixelBuffer atTime:(CMTime)outputTime
{
	// CVPixelBuffer is wrapped in a CMSampleBuffer and then displayed on a AVSampleBufferDisplayLayer
	CMSampleBufferRef sampleBuffer = NULL;
	OSStatus err = noErr;
    
	if (!_videoInfo || !CMVideoFormatDescriptionMatchesImageBuffer(_videoInfo, pixelBuffer)) {
		err = CMVideoFormatDescriptionCreateForImageBuffer(NULL, pixelBuffer, &_videoInfo);
	}
    
	if (err) {
		NSLog(@"Error at CMVideoFormatDescriptionCreateForImageBuffer %d", err);
	}
	
	// decodeTimeStamp is set to kCMTimeInvalid since we already receive decoded frames
	CMSampleTimingInfo sampleTimingInfo = {
		.duration = kCMTimeInvalid,
		.presentationTimeStamp = outputTime,
		.decodeTimeStamp = kCMTimeInvalid
	};
    
	// Wrap the pixel buffer in a sample buffer
	err = CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault, pixelBuffer, true, NULL, NULL, _videoInfo, &sampleTimingInfo, &sampleBuffer);
	if (err) {
		NSLog(@"Error at CMSampleBufferCreateForImageBuffer %d", err);
	}
    
    [self.delegate displayPixelBuffer: pixelBuffer atTime: outputTime];
    
	// Enqueue sample buffers which will be displayed at their above set presentationTimeStamp
	if (self.videoLayer.readyForMoreMediaData) {
		[self.videoLayer enqueueSampleBuffer: sampleBuffer];
	}
	
	CFRelease(sampleBuffer);
}


#pragma mark -

static CVReturn displayLinkCallback(CVDisplayLinkRef displayLink, const CVTimeStamp *inNow, const CVTimeStamp *inOutputTime, CVOptionFlags flagsIn, CVOptionFlags *flagsOut, void *displayLinkContext)
{
	YLPlayerView *self = (__bridge YLPlayerView *)displayLinkContext;
	AVPlayerItemVideoOutput *playerItemVideoOutput = self.playerItemVideoOutput;
	
	// The displayLink calls back at every vsync (screen refresh)
	// Compute itemTime for the next vsync
	CMTime outputItemTime = [playerItemVideoOutput itemTimeForCVTimeStamp: *inOutputTime];
	if ([playerItemVideoOutput hasNewPixelBufferForItemTime: outputItemTime]) {
		self->_lastHostTime = inOutputTime->hostTime;
		
		// Copy the pixel buffer to be displayed next and add it to AVSampleBufferDisplayLayer for display
		CVPixelBufferRef pixBuff = [playerItemVideoOutput copyPixelBufferForItemTime: outputItemTime itemTimeForDisplay: NULL];
		[self displayPixelBuffer: pixBuff atTime: outputItemTime];
		
		CVBufferRelease(pixBuff);
	} else {
		CMTime elapsedTime = CMClockMakeHostTimeFromSystemUnits(inNow->hostTime - self->_lastHostTime);
		if (CMTimeGetSeconds(elapsedTime) > FREEWHEELING_PERIOD_IN_SECONDS) {
			// No new images for a while.  Shut down the display link to conserve power, but request a wakeup call if new images are coming.
			
			CVDisplayLinkStop(displayLink);
			
			[playerItemVideoOutput requestNotificationOfMediaDataChangeWithAdvanceInterval:ADVANCE_INTERVAL_IN_SECONDS];
		}
	}
	return kCVReturnSuccess;
}
@end

#pragma mark -

@implementation YLPlayerView (AVPlayerItemOutputPullDelegate)

- (void) outputMediaDataWillChange: (AVPlayerItemOutput *)sender
{
	// Start running again.
	_lastHostTime = CVGetCurrentHostTime();
	CVDisplayLinkStart(_displayLink);
}
@end
