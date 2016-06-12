//
//  CameraOverlayViewController.m
//  BMLPVideoArchiver
//
//  Created by Justine Kay on 12/26/15.
//  Copyright © 2015 Justine Kay. All rights reserved.
//

#import "CameraOverlayViewController.h"

@interface CameraOverlayViewController ()

@end

@implementation CameraOverlayViewController

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.customCameraOverlayView = [[CustomCameraOverlayView alloc] init];
    }
    return [self initWithNibName:@"CameraOverlayViewController" bundle:nil];
}

@end
