//
//  YLDocument.h
//  SkewDragon
//
//  Created by Yung-Luen Lan on 1/14/14.
//  Copyright (c) 2014 Yung-Luen Lan. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "YLPlayerView.h"

@class YLTimeSlider;

@interface YLDocument : NSDocument <YLPlayerViewDelegate>

@property (nonatomic, assign) IBOutlet YLPlayerView *playerView;
@property (nonatomic, assign) IBOutlet NSButton *playPauseButton;
@property (nonatomic, assign) IBOutlet YLTimeSlider *currentTimeSlider;

@property double currentTime;
@property (readonly) double duration;

- (IBAction) togglePlayPause: (id)sender;

@end
