//
//  CameraOverlayView.m
//  BMLPVideoArchiver
//
//  Created by Justine Gartner on 12/26/15.
//  Copyright © 2015 Justine Kay. All rights reserved.
//

#import "CustomCameraOverlayView.h"

@implementation CustomCameraOverlayView

- (IBAction)cameraSelectionButtonTapped:(UIButton *)sender
{
    [self.delegate didChangeCamera];
}

- (IBAction)flashModeButtonTapped:(UIButton *)sender
{
    [self.delegate didChangeFlashMode];
}

- (IBAction)videoQualitySelectionButtonTapped:(UIButton *)sender
{
    [self.delegate didChangeVideoQuality];
}

@end