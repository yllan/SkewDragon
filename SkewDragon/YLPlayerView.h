//
//  YLPlayerView.h
//  SkewDragon
//
//  Created by Yung-Luen Lan on 1/14/14.
//  Copyright (c) 2014 Yung-Luen Lan. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <AVFoundation/AVFoundation.h>
#import <QuartzCore/QuartzCore.h>

@protocol YLPlayerViewDelegate <NSObject>
- (void) displayPixelBuffer: (CVPixelBufferRef)pixelBuffer atTime: (CMTime)outputTime;
@end

@interface YLPlayerView : NSView

@property (nonatomic, weak) IBOutlet id<YLPlayerViewDelegate> delegate;
@property (nonatomic, strong) AVPlayerItem *playerItem;
@property (nonatomic, strong) AVSampleBufferDisplayLayer *videoLayer;
@property (nonatomic, strong) CIDetector *detector;

@end
