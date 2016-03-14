//
//  VideoViewController.h
//  BMLPVideoArchiver
//
//  Created by Justine Kay on 10/26/15.
//  Copyright © 2015 Justine Kay. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import "GTMOAuth2ViewControllerTouch.h"
#import "GTLDrive.h"
#import "CameraOverlayViewController.h"
#import "CustomCameraOverlayView.h"

#define SignedInKey @"SignedIn"

@interface VideoViewController : UIViewController
<
AVAudioRecorderDelegate,
UINavigationControllerDelegate,
UIImagePickerControllerDelegate,
CustomCameraOverlayDelegate
>

{
UITapGestureRecognizer  *recordGestureRecognizer;
UIImagePickerController *camera;
AVAudioRecorder *audioRecorder;
BOOL inBackground;
BOOL videoRecording;
BOOL sessionInProgress;
BOOL showCameraSelection;
BOOL showFlashMode;
}

@property (nonatomic, strong) GTLServiceDrive *service;
@property (nonatomic, strong) UITextView *output;
@property (nonatomic) NSTimer *timer;

@end
