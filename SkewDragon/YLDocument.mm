//
//  YLDocument.m
//  SkewDragon
//
//  Created by Yung-Luen Lan on 1/14/14.
//  Copyright (c) 2014 Yung-Luen Lan. All rights reserved.
//

#import "YLDocument.h"
#import <AVFoundation/AVFoundation.h>
#import "YLFaceLayer.h"

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
@property (nonatomic, strong) CIDetector *detector;
@property (nonatomic, strong) NSArray *faceImages;
@property (nonatomic, strong) NSSet *displayingFaceIDs;
@property (nonatomic, strong) NSArray *quotes;
@end

@implementation YLDocument

- (id) init
{
    self = [super init];
    if (self) {
        _player = [[AVPlayer alloc] init];
        [self addTimeObserverToPlayer];
        self.detector = [CIDetector detectorOfType: CIDetectorTypeFace context: nil options: @{CIDetectorAccuracy: CIDetectorAccuracyHigh, CIDetectorTracking: @YES}];
        self.faceImages = @[[NSImage imageNamed: @"kp"], [NSImage imageNamed: @"kp2"], [NSImage imageNamed: @"kp3"], [NSImage imageNamed: @"kp4"], [NSImage imageNamed: @"kp5"]];
        self.quotes = @[
                        @"事實上，政府原來的GMP、CAS制度，現在通通都失靈。",
                        @"先進節能城市",
                        @"公車路線大調整",
                        @"各單位各挖各補的結果就是破壞市容、影響道路安全。",
                        @"安心生孩子，輕鬆養孩子",
                        @"家醫制度",
                        @"我絕對相信，台北市民對預算提出的能力，不會比市政府差！",
                        @"所謂參與式預算，便是制度化地讓市民可以參與預算的提出跟審查，藉此達到市民對台北市政興利跟除弊的雙重目的。",
                        @"接駁式服務",
                        @"改變台北從文化開始",
                        @"政府應當積極解決褓姆供應的問題，而非只是花錢的補助政策，然後讓人民自謀生路，這是懶惰的行政態度。",
                        @"文化基金會應當是一個獨立、專業、多元的文化獎助機構，並不是市長跟企業家社交的機構。",
                        @"文化政策諮詢審議會",
                        @"派隻烏龜去送公文都比那個快！",
                        @"海綿城市",
                        @"真正落實十二年國教，必需打造均優質的高中職",
                        @"笨蛋，問題不在工程，而在管理。",
                        @"緊急救護",
                        @"能源",
                        @"自動體外電擊器AED",
                        @"要讓經濟成長，用電零成長",
                        @"要透過資源的公開透明，把文化還給文化人！",
                        @"解救血汗計程車",
                        @"課後及寒暑假照顧班",
                        @"買不起，至少要讓市民住得起。",
                        @"透過網路投票，全民當市長的理想可以實現！",
                        @"道路統一挖補",
                        @"銀髮照顧",
                        @"開源",
                        @"難道要像經濟學人說的，台灣的未來由街頭來決定嗎？",
                        @"雨天儲水，晴天散熱",
                        @"食品安全微笑標章"
                        ];
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
    AVMutableComposition *composition = [AVMutableComposition composition];
    AVURLAsset* videoAsset = [[AVURLAsset alloc] initWithURL: url options: nil];
    
    AVMutableCompositionTrack *compositionVideoTrack = [composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    NSError* error = NULL;
    
    [compositionVideoTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero,videoAsset.duration)
                                   ofTrack:[[videoAsset tracksWithMediaType:AVMediaTypeVideo]objectAtIndex:0]
                                    atTime:kCMTimeZero
                                     error:&error];
    
//    NSMutableArray *allAudio = [[NSMutableArray alloc]init];
//    for (int i=1; i < [allAudioTracks count]; i++) {
    NSURL *audioURL = [[NSBundle mainBundle] URLForResource: @"kp" withExtension: @"mp3"];
    AVURLAsset* audioAsset = [[AVURLAsset alloc] initWithURL: audioURL options: nil];
//        [allAudio addObject:audioAsset];
//    }
//
//    for (int i=0; i < [allAudio count]; i++) {
    error = NULL;
//        //audioAsset = [allAudio objectAtIndex:i];

    CMTime duration = (videoAsset.duration.value > audioAsset.duration.value) ? audioAsset.duration : videoAsset.duration;
    AVMutableCompositionTrack *compositionAudioTrack = [composition addMutableTrackWithMediaType: AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
    [compositionAudioTrack insertTimeRange: CMTimeRangeMake(kCMTimeZero, duration)
                                   ofTrack: [[audioAsset tracksWithMediaType: AVMediaTypeAudio] firstObject]
                                    atTime: kCMTimeZero
                                     error: &error];
//
//        NSLog(@"Error : %@", error);
//        //[allCompositionTrack addObject:compositionAudioTrack];
//        [audioAsset release];
//    }
    
    
	AVPlayerItem *playerItem = [AVPlayerItem playerItemWithAsset: composition];
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

- (CGRect) transformRect: (CGRect)rect inSize: (CGSize)inSize
{
    CGPoint baseOffset = CGPointZero;
    CGSize scaledSize = CGSizeZero;
    CGFloat ratio = 0;
    if (self.playerView.frame.size.width / self.playerView.frame.size.height >= inSize.width / inSize.height) {
        scaledSize.width = inSize.width * self.playerView.frame.size.height / inSize.height;
        scaledSize.height = self.playerView.frame.size.height;
        ratio = self.playerView.frame.size.height / inSize.height;
    } else {
        scaledSize.width = self.playerView.frame.size.width;
        scaledSize.height = inSize.height * self.playerView.frame.size.width / inSize.width;
        ratio = self.playerView.frame.size.width / inSize.width;
    }
    baseOffset = CGPointMake((self.playerView.frame.size.width - scaledSize.width) / 2, (self.playerView.frame.size.height - scaledSize.height) / 2);
    
    
    return CGRectMake(baseOffset.x + rect.origin.x * ratio, baseOffset.y + rect.origin.y * ratio, rect.size.width * ratio, rect.size.height * ratio);
}

#pragma mark - Player View Delegate
- (void) displayPixelBuffer: (CVPixelBufferRef)pixelBuffer atTime: (CMTime)outputTime
{
    @autoreleasepool {
        CIImage *image = [[CIImage alloc] initWithCVImageBuffer: pixelBuffer];
        
        size_t imageWidth = CVPixelBufferGetWidth(pixelBuffer);
        size_t imageHeight = CVPixelBufferGetHeight(pixelBuffer);
        CGSize imageSize = CGSizeMake(imageWidth, imageHeight);
        
        NSArray *features = [self.detector featuresInImage: image];

        NSMutableSet *newFaceIDs = [NSMutableSet set];
        NSMutableSet *existingFaceIDs = [NSMutableSet set];
        NSMutableSet *disappearedFaceIDs = [self.displayingFaceIDs mutableCopy];

        /* Classify the faces' state */
        for (CIFaceFeature *f in features) {
            if (f.trackingFrameCount == 1) {
                [newFaceIDs addObject: @(f.trackingID)];
            } else {
                [existingFaceIDs addObject: @(f.trackingID)];
            }
            [disappearedFaceIDs removeObject: @(f.trackingID)];
        }
        self.displayingFaceIDs = [[existingFaceIDs copy] setByAddingObjectsFromSet: newFaceIDs];
        
        image = nil;
        [CATransaction begin];
        [CATransaction setValue:(id)kCFBooleanTrue forKey: kCATransactionDisableActions];
        
        NSArray *sublayers = [self.playerView.layer sublayers];
        NSMutableArray *faceLayers = [NSMutableArray array];

        for (YLFaceLayer *faceLayer in sublayers)
            if ([faceLayer.name isEqualToString: @"FaceLayer"]) {
                [faceLayers addObject: faceLayer];
                faceLayer.hidden = YES;
            }
        
        CGFloat subtitleY = 0;

        if (features.count > 0) {
            NSInteger sublayersCount = [faceLayers count], currentSublayer = 0;
            for (NSUInteger idx = sublayersCount; idx < features.count; idx++) {
                YLFaceLayer *layer = [YLFaceLayer layer];
                layer.name = @"FaceLayer";
//                layer.borderColor = [NSColor redColor].CGColor;
//                layer.borderWidth = 1;
                
                [self.playerView.layer addSublayer: layer];
                [faceLayers addObject: layer];
            }
            
            for (CIFaceFeature *f in features) {
                YLFaceLayer *faceLayer = [faceLayers objectAtIndex: currentSublayer++];
                
                faceLayer.frame = [self transformRect: f.bounds inSize: imageSize];
                faceLayer.contents= self.faceImages[f.trackingID % self.faceImages.count];

//                faceLayer.leftEyeLayer.hidden = !f.hasLeftEyePosition;
//                faceLayer.rightEyeLayer.hidden = !f.hasRightEyePosition;
//                faceLayer.mouthLayer.hidden = !f.hasMouthPosition;

                faceLayer.leftEyeLayer.hidden = YES;
                faceLayer.rightEyeLayer.hidden = YES;
                faceLayer.mouthLayer.hidden = YES;

                
                faceLayer.textLayer.string = [NSString stringWithFormat: @"「%@」", self.quotes[f.trackingID % self.quotes.count]];
                CGFloat lineHeight = self.playerView.frame.size.height / 10;
                faceLayer.textLayer.frame = CGRectMake(-faceLayer.frame.origin.x, -faceLayer.frame.origin.y + subtitleY, self.playerView.frame.size.width, lineHeight);
                faceLayer.textLayer.fontSize = lineHeight / 2.2;
                subtitleY += lineHeight;
                
                faceLayer.hidden = NO;
                
            }
        }
        [CATransaction commit];
    }
}
@end
