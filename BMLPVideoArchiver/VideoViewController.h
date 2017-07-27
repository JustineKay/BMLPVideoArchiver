//
//  VideoViewController.h
//  BMLPVideoArchiver
//
//  Created by Justine Kay on 10/26/15.
//  Copyright © 2015 Justine Kay. All rights reserved.
//

// TODO(cspickert): Most of the content of this file (#imports, protocol conformance, ivars) can be moved into the .m file to keep it hidden from the rest of your code.
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import "CameraOverlayViewController.h"
#import "CustomCameraOverlayView.h"

// TODO(cspickert): It's better to use "static NSString *const" instead of #define for NSString constants.
#define SignedInKey @"SignedIn"

@interface VideoViewController : UIViewController
<
AVAudioRecorderDelegate,
UINavigationControllerDelegate,
UIImagePickerControllerDelegate,
CustomCameraOverlayDelegate
>

{
// TODO(cspickert): Best practices for ivars: declare them in the @implementation instead of @interface, and prefix them with a single underscore.
UITapGestureRecognizer  *recordGestureRecognizer;
UIImagePickerController *camera;
AVAudioRecorder *audioRecorder;
BOOL passcodeFailed;
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
