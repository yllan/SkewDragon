//
//  YLFaceLayer.m
//  SkewDragon
//
//  Created by Yung-Luen Lan on 1/16/14.
//  Copyright (c) 2014 Yung-Luen Lan. All rights reserved.
//

#import "YLFaceLayer.h"

@implementation YLFaceLayer
- (id) init
{
    self = [super init];
    if (self) {
        CGFloat eyeRadii = 12;
        
        self.textLayer = [CATextLayer layer];
        self.leftEyeLayer = [CALayer layer];
        self.leftEyeLayer.borderColor = [NSColor yellowColor].CGColor;
        self.leftEyeLayer.borderWidth = 1;
        self.leftEyeLayer.bounds = CGRectMake(0, 0, eyeRadii, eyeRadii);
        self.leftEyeLayer.cornerRadius = eyeRadii / 2;

        self.rightEyeLayer = [CALayer layer];
        self.rightEyeLayer.borderColor = [NSColor yellowColor].CGColor;
        self.rightEyeLayer.borderWidth = 1;
        self.rightEyeLayer.bounds = CGRectMake(0, 0, eyeRadii, eyeRadii);
        self.rightEyeLayer.cornerRadius = eyeRadii / 2;
        
        self.mouthLayer = [CALayer layer];
        
        [self addSublayer: self.leftEyeLayer];
        [self addSublayer: self.rightEyeLayer];
        [self addSublayer: self.mouthLayer];
        [self addSublayer: self.textLayer];
    }
    return self;
}
@end
