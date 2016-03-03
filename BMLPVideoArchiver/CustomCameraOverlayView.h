//
//  CameraOverlayView.h
//  BMLPVideoArchiver
//
//  Created by Justine Kay on 12/26/15.
//  Copyright © 2015 Justine Kay. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol CustomCameraOverlayDelegate <NSObject>

-(void)didChangeCamera;
-(void)didChangeFlashMode;
-(void)didSignOut;
-(void)didStopRecording;

@end

@interface CustomCameraOverlayView : UIView

@property (weak, nonatomic) id <CustomCameraOverlayDelegate> delegate;

@property (weak, nonatomic) IBOutlet UIButton *cameraSelectionButton;
@property (weak, nonatomic) IBOutlet UIButton *flashModeButton;
@property (weak, nonatomic) IBOutlet UILabel *uploadingLabel;
@property (weak, nonatomic) IBOutlet UILabel *fileSavedLabel;
@property (weak, nonatomic) IBOutlet UIButton *menuButton;
@property (weak, nonatomic) IBOutlet UIView *menuBarView;
@property (weak, nonatomic) IBOutlet UIView *stopRecordingView;
@property (weak, nonatomic) IBOutlet UIButton *stopRecordingButton;

@end
