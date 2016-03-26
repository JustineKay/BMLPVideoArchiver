//
//  InterfaceOrientationNavigationController.m
//  BMLPVideoArchiver
//
//  Created by Justine Kay on 3/25/16.
//  Copyright © 2016 Justine Kay. All rights reserved.
//

#import "InterfaceOrientationNavigationController.h"
#import "AppDelegate.h"

@interface InterfaceOrientationNavigationController ()

@end

@implementation InterfaceOrientationNavigationController

- (BOOL)shouldAutorotate
{
    return NO;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
//    AppDelegate *appDelgate=[[UIApplication sharedApplication] delegate];
//    
//    if (appDelgate.isCameraPresented) {
//        
//        return UIInterfaceOrientationMaskLandscape;
//        
//    }
    return UIInterfaceOrientationMaskLandscape;
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation
{
    return UIInterfaceOrientationLandscapeRight;
}

@end
