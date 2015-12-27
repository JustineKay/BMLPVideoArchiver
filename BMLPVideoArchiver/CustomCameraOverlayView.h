//
//  CameraOverlayView.h
//  BMLPVideoArchiver
//
//  Created by Justine Gartner on 12/26/15.
//  Copyright © 2015 Justine Kay. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol CustomCameraOverlayDelegate <NSObject>

-(void)didChangeCamera;

@end

@interface CustomCameraOverlayView : UIView

@property (weak, nonatomic) id <CustomCameraOverlayDelegate> delegate;

@property (weak, nonatomic) IBOutlet UIButton *cameraSelectionButton;

@end
