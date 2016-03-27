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

-(BOOL)shouldAutorotate
{
    return YES;
}

-(UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    
    return UIInterfaceOrientationMaskLandscape;
}

-(UIInterfaceOrientation)preferredInterfaceOrientationForPresentation
{
    
    return UIInterfaceOrientationLandscapeLeft;
}

@end
