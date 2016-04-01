//
//  VideoViewController.h
//  BMLPVideoArchiver
//
//  Created by Justine Kay on 10/26/15.
//  Copyright © 2015 Justine Kay. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
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
BOOL isVideoFile;
BOOL inBackground;
BOOL mainFolder;
BOOL datedFolder;
BOOL videoRecording;
BOOL videoSessionInProgress;
BOOL audioSessionInProgress;
BOOL showCameraSelection;
BOOL showFlashMode;
}

@property (nonatomic, strong) UITextView *output;

@end
