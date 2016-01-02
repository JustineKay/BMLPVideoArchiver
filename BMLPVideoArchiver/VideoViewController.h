//
//  VideoViewController.h
//  BMLPVideoArchiver
//
//  Created by Justine Beth Kay on 10/26/15.
//  Copyright © 2015 Justine Beth Kay. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "GTMOAuth2ViewControllerTouch.h"
#import "GTLDrive.h"
#import "CameraOverlayViewController.h"
#import "CustomCameraOverlayView.h"

@interface VideoViewController : UIViewController
<
UINavigationControllerDelegate,
UIImagePickerControllerDelegate,
CustomCameraOverlayDelegate
>

{
UITapGestureRecognizer  *recordGestureRecognizer;
UIImagePickerController *camera;
BOOL                     recording;
BOOL                     endSession;
BOOL                     showCameraSelection;
BOOL                     showFlashMode;
}

@property (nonatomic, strong) GTLServiceDrive *service;
@property (nonatomic, strong) UITextView *output;


@end
