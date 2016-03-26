//
//  LandscapeImagePickerController.m
//  BMLPVideoArchiver
//
//  Created by Justine Kay on 3/25/16.
//  Copyright © 2016 Justine Kay. All rights reserved.
//

#import "LandscapeImagePickerController.h"

@interface LandscapeImagePickerController ()

@end

@implementation LandscapeImagePickerController

//- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
//{
//    return (interfaceOrientation == UIInterfaceOrientationLandscapeLeft);
//}

//- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
//{
//    return UIInterfaceOrientationIsLandscape(toInterfaceOrientation);
//}

-(BOOL)shouldAutorotate
{
    return NO;
}

-(UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    
    return UIInterfaceOrientationMaskLandscape;
}

-(UIInterfaceOrientation)preferredInterfaceOrientationForPresentation
{
    
    return UIInterfaceOrientationLandscapeRight;
}

@end
