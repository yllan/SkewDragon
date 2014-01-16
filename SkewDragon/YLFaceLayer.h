//
//  YLFaceLayer.h
//  SkewDragon
//
//  Created by Yung-Luen Lan on 1/16/14.
//  Copyright (c) 2014 Yung-Luen Lan. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>

@interface YLFaceLayer : CALayer
@property (strong, nonatomic) CATextLayer *textLayer;
@property (strong, nonatomic) CALayer *leftEyeLayer;
@property (strong, nonatomic) CALayer *rightEyeLayer;
@property (strong, nonatomic) CALayer *mouthLayer;
@end
