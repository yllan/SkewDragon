//
//  YLDocument.m
//  SkewDragon
//
//  Created by Yung-Luen Lan on 1/14/14.
//  Copyright (c) 2014 Yung-Luen Lan. All rights reserved.
//

#import "YLDocument.h"
@import AVFoundation.AVBase;
@import AVFoundation.AVPlayer;
@import AVFoundation.AVAsset;
@import AVFoundation.AVMediaFormat;
@import AVFoundation.AVAssetTrack;

static void *YLPlayerItemStatusContext = &YLPlayerItemStatusContext;
NSString* const YLMouseDownNotification = @"YLMouseDownNotification";
NSString* const YLMouseUpNotification = @"YLMouseUpNotification";

@interface YLTimeSliderCell : NSSliderCell

@end

@interface YLTimeSlider : NSSlider

@end

// Custom NSSlider and NSSliderCell subclasses to track scrubbing

@implementation YLTimeSliderCell

- (void) stopTracking: (NSPoint)lastPoint at: (NSPoint)stopPoint inView: (NSView *)controlView mouseIsUp: (BOOL)flag
{
	if (flag) {
		[[NSNotificationCenter defaultCenter] postNotificationName: YLMouseUpNotification object: self];
	}
	[super stopTracking: lastPoint at: stopPoint inView: controlView mouseIsUp: flag];
}

@end

@implementation YLTimeSlider

- (void) mouseDown: (NSEvent *)theEvent
{
	[[NSNotificationCenter defaultCenter] postNotificationName: YLMouseDownNotification object: self];
	[super mouseDown: theEvent];
}
@end


@interface YLDocument ()
{
    AVPlayer *_player;
    AVPlayerItem *_currentPlayerItem;
	float _playRateToRestore;
	id _observer;
}
@end

@implementation YLDocument

- (id) init
{
    self = [super init];
    if (self) {
        _player = [[AVPlayer alloc] init];
        [self addTimeObserverToPlayer];
    }
    return self;
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver: self name: AVPlayerItemDidPlayToEndTimeNotification object: nil];
    [[NSNotificationCenter defaultCenter] removeObserver: self name: YLMouseDownNotification object: nil];
    [[NSNotificationCenter defaultCenter] removeObserver: self name: YLMouseUpNotification object: nil];

	[_player removeTimeObserver: _observer];
	
	_player = nil;
	_currentPlayerItem = nil;

}

#pragma mark - NSDocument

- (NSString *) windowNibName
{
    return @"YLDocument";
}

- (void) windowControllerDidLoadNib: (NSWindowController *)aController
{
    _currentPlayerItem = [_player currentItem];
	self.playerView.playerItem = _currentPlayerItem;
 
    AVAsset *asset = _currentPlayerItem.asset;
    AVAssetTrack *videoTrack = [[asset tracksWithMediaType: AVMediaTypeVideo] firstObject];
    CGSize size = videoTrack.naturalSize;
    size.height += 62;
    [aController.window setFrame: NSMakeRect(0, 0, size.width, size.height) display: YES];
    [aController.window center];
    
	[self.currentTimeSlider setDoubleValue: 0.0];
    
	[self addObserver: self forKeyPath: @"self.player.currentItem.status" options: NSKeyValueObservingOptionNew context: YLPlayerItemStatusContext];
    
    [[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(playerItemDidPlayToEndTime:) name: AVPlayerItemDidPlayToEndTimeNotification object: _currentPlayerItem];
    [[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(beginScrubbing:) name: YLMouseDownNotification object:self.currentTimeSlider];
    [[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(endScrubbing:) name: YLMouseUpNotification object: self.currentTimeSlider.cell];
}

- (void) close
{
    self.playerView = nil;
	self.playPauseButton = nil;
	self.currentTimeSlider = nil;
	[self removeObserver: self forKeyPath: @"self.player.currentItem.status"];
	[super close];
}

- (BOOL) readFromURL: (NSURL *)url ofType: (NSString *)typeName error: (NSError *__autoreleasing *)outError
{
	AVPlayerItem *playerItem = [AVPlayerItem playerItemWithURL: url];
	if (playerItem) {
		[_player replaceCurrentItemWithPlayerItem: playerItem];
		return YES;
	}
	return NO;
}

#pragma mark - Time Observing

- (void) playerItemDidPlayToEndTime: (NSNotification *)notification
{
	[(NSButton *)self.playPauseButton setTitle:([_player rate] == 0.0f ? @"Play" : @"Pause")];
}

- (void) addTimeObserverToPlayer
{
	if (_observer) return;
    // __weak is used to ensure that a retain cycle between the document, player and notification block is not formed.
	__weak YLDocument* weakSelf = self;
	_observer = [_player addPeriodicTimeObserverForInterval: CMTimeMakeWithSeconds(1, 10) queue: dispatch_get_main_queue() usingBlock: ^(CMTime time) {
        [weakSelf syncScrubber];
    }];
}

- (void) removeTimeObserverFromPlayer
{
	if (_observer) {
		[_player removeTimeObserver: _observer];
		_observer = nil;
	}
}

#pragma mark - KVC

+ (NSSet *) keyPathsForValuesAffectingDuration
{
	return [NSSet setWithObjects: @"player.currentItem", @"player.currentItem.status", nil];
}

- (void) observeValueForKeyPath: (NSString *)keyPath ofObject: (id)object change: (NSDictionary *)change context: (void *)context
{
	if (context == YLPlayerItemStatusContext) {
		AVPlayerStatus status = [[change objectForKey: NSKeyValueChangeNewKey] integerValue];
		if (status == AVPlayerItemStatusReadyToPlay) {
			self.playerView.videoLayer.controlTimebase = _player.currentItem.timebase;
		}
	} else {
		[super observeValueForKeyPath: keyPath ofObject: object change: change context: context];
	}
}

#pragma mark - Accessors

- (double) duration
{
	AVPlayerItem *playerItem = [_player currentItem];
	
	if ([playerItem status] == AVPlayerItemStatusReadyToPlay)
		return CMTimeGetSeconds([[playerItem asset] duration]);
	else
		return 0.f;
}

- (double) currentTime
{
	return CMTimeGetSeconds([_player currentTime]);
}

- (void) setCurrentTime: (double)time
{
	// Flush the previous enqueued sample buffers for display while scrubbing
	[self.playerView.videoLayer flush];
	
	[_player seekToTime: CMTimeMakeWithSeconds(time, 1)];
}

#pragma mark - Scrubbing Utilities

- (void) beginScrubbing: (NSNotification*)notification
{
	_playRateToRestore = [_player rate];
	[self removeTimeObserverFromPlayer];
	[_player setRate: 0.0];
}

- (void) endScrubbing: (NSNotification*)notification
{
	[_player setRate: _playRateToRestore];
	[self addTimeObserverToPlayer];
}

- (void) syncScrubber
{
	double time = CMTimeGetSeconds([_player currentTime]);
	[self.currentTimeSlider setDoubleValue: time];
}

#pragma mark - Action

- (IBAction) togglePlayPause: (id)sender
{
	if (CMTIME_COMPARE_INLINE([[_player currentItem] currentTime], >=, [[_player currentItem] duration]))
		[[_player currentItem] seekToTime:kCMTimeZero];
	
	[_player setRate:([_player rate] == 0.0f ? 1.0f : 0.0f)];
	
	[(NSButton *)sender setTitle: ([_player rate] == 0.0f ? @"Play" : @"Pause")];
}

#pragma mark - Player View Delegate
- (void) displayPixelBuffer: (CVPixelBufferRef)pixelBuffer atTime: (CMTime)outputTime
{

}
@end
