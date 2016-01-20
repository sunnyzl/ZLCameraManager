//
//  UIImage+OFGCrop.h
//  ZLCameraManagerDemo
//
//  Created by Ömer Faruk Gül on 27/10/14.
//  Copyright (c) 2014 Ömer Faruk Gül. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIImage (OFGCropCategory)

- (UIImage *)croppedImageWithRect:(CGRect)rect;

@end
