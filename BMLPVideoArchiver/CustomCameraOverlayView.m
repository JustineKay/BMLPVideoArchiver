//
//  CameraOverlayView.m
//  BMLPVideoArchiver
//
//  Created by Justine Kay on 12/26/15.
//  Copyright © 2015 Justine Kay. All rights reserved.
//

#import "CustomCameraOverlayView.h"

@implementation CustomCameraOverlayView

- (instancetype)init {
    
    self = [super init];
    if (self) {
        
        //TODO: Initialize all properties
        
        self.stopRecordingView.alpha =  0.0;
        self.stopRecordingView.layer.cornerRadius = 30.0;
        self.stopRecordingView.backgroundColor = [UIColor whiteColor];
        self.cameraSelectionButton.alpha = 0.0;
        self.flashModeButton.alpha = 0.0;
        self.uploadingLabel.alpha = 0.0;
        self.fileSavedLabel.alpha = 0.0;
        self.backgroundColor = [UIColor clearColor];
        self.menuBarView.backgroundColor = [UIColor colorWithRed:211.0/255.0
                                                           green:211.0/255.0
                                                            blue:211.0/255.0
                                                           alpha:0.25];
    };
    
    return self;
}

- (IBAction)cameraSelectionButtonTapped:(UIButton *)sender
{
    [self.delegate didChangeCamera];
}

- (IBAction)flashModeButtonTapped:(UIButton *)sender
{
    [self.delegate didChangeFlashMode];
}

- (IBAction)menuButtonTapped:(UIButton *)sender
{
    [self.delegate didTapSettingsButton];
    
}

- (IBAction)stopRecordingButtonTapped:(UIButton *)sender {
    
    [self.delegate didStopRecordingVideo];
}


@end
