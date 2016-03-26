//
//  LandscapeImagePickerController.m
//  BMLPVideoArchiver
//
//  Created by Justine Gartner on 3/25/16.
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
