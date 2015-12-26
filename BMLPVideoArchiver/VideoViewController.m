//
//  VideoViewController.m
//  BMLPVideoArchiver
//
//  Created by Justine Beth Kay on 10/26/15.
//  Copyright © 2015 Justine Beth Kay. All rights reserved.
//
//From ViewDidLoad
//    CGRect screenRect = [[UIScreen mainScreen] bounds];
//
//    // create camera with standard settings
//    self.camera = [[LLSimpleCamera alloc] init];
//
//    // camera with video recording capability
//    self.camera =  [[LLSimpleCamera alloc] initWithVideoEnabled:YES];
//
//    // camera with precise quality, position and video parameters.
//    self.camera = [[LLSimpleCamera alloc] initWithQuality:AVCaptureSessionPresetHigh
//                                                 position:CameraPositionBack
//                                             videoEnabled:YES];
//    // attach to the view
//    [self.camera attachToViewController:self withFrame:CGRectMake(0, 0, screenRect.size.width, screenRect.size.height)];


#import "VideoViewController.h"
#import <LLSimpleCamera/LLSimpleCamera.h>
#import <MobileCoreServices/MobileCoreServices.h>

#import "GTMOAuth2ViewControllerTouch.h"
#import "GTLDrive.h"

static NSString *const kKeychainItemName = @"BMLP Video Archiver";
static NSString *const kClientID = @"749579524688-b1oaiu8cc4obq06aal4org55qie5lho2.apps.googleusercontent.com";
static NSString *const kClientSecret = @"0U67OQ3UNhX72tmba7ZhMSYK";

@interface VideoViewController ()

{
    BOOL isAuthorized;
}

- (void)changeVideoQuality:(id)sender;
- (void)changeFlashMode:(id)sender;
- (void)changeCamera:(id)sender;

- (void)createCamera;
- (void)startRecording;
- (void)stopRecording;

- (void)video:(NSString *)videoPath didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo;

//@property (nonatomic) LLSimpleCamera *LLSCamera;
@property (nonatomic, retain) GTLServiceDrive *driveService;

@end

@implementation VideoViewController

@synthesize driveService;

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    cameraSelectionButton.alpha = 0.0;
    flashModeButton.alpha = 0.0;
    recordIndicatorView.alpha = 0.0;
    
    [self createCamera];
    
    recordGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleVideoRecording)];
    recordGestureRecognizer.numberOfTapsRequired = 2;
    
    [cameraOverlayView addGestureRecognizer:recordGestureRecognizer];
    
    // Initialize the drive service & load existing credentials from the keychain if available
    self.driveService = [[GTLServiceDrive alloc] init];
    self.driveService.authorizer = [GTMOAuth2ViewControllerTouch authForGoogleFromKeychainForName:kKeychainItemName
                                                                                         clientID:kClientID
                                                                                     clientSecret:kClientSecret];
}

- (void)viewWillAppear:(BOOL)animated
{
//    CGRect theRect = [camera.view frame];
//    [cameraOverlayView setFrame:theRect];
    
//    [self presentViewController:camera animated:animated completion:nil];
//    camera.cameraOverlayView = cameraOverlayView;
}

- (void)viewDidAppear:(BOOL)animated
{
    //cameraOverlayView = [[UIView alloc] init];
    CGRect theRect = [camera.view frame];
    [cameraOverlayView setFrame:theRect];
    
     camera.cameraOverlayView = cameraOverlayView;
    
    [self presentViewController:camera animated:animated completion:nil];
    
   
    
//    // Always display the camera UI.
//    [self showCamera];
}

//- (void)dealloc {
//    [recordGestureRecognizer release];
//    
//    [super dealloc];
//}


- (void)createCamera
{
    camera = [[UIImagePickerController alloc] init];
    //if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera])
    //{
        camera.sourceType = UIImagePickerControllerSourceTypeCamera;
    //};
//    else
//    {
//        // In case we're running the iPhone simulator, fall back on the photo library instead.
//        cameraUI.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
//        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
//        {
//            [self showAlert:@"Error" message:@"Sorry, iPad Simulator not supported!"];
//            return;
//        }
//    };
    
    
    camera.mediaTypes = [[NSArray alloc] initWithObjects:(NSString *)kUTTypeMovie, nil];
    camera.cameraCaptureMode = UIImagePickerControllerCameraCaptureModeVideo;
    //cameraUI.allowsEditing = YES;
    camera.showsCameraControls = NO;
    camera.cameraViewTransform = CGAffineTransformIdentity;
    
    // not all devices have two cameras or a flash so just check here
    if ( [UIImagePickerController isCameraDeviceAvailable: UIImagePickerControllerCameraDeviceRear] ) {
        camera.cameraDevice = UIImagePickerControllerCameraDeviceRear;
        if ( [UIImagePickerController isCameraDeviceAvailable: UIImagePickerControllerCameraDeviceFront] ) {
            cameraSelectionButton.alpha = 1.0;
            showCameraSelection = YES;
        }
    } else {
        camera.cameraDevice = UIImagePickerControllerCameraDeviceFront;
    }
    
    if ( [UIImagePickerController isFlashAvailableForCameraDevice:camera.cameraDevice] ) {
        camera.cameraFlashMode = UIImagePickerControllerCameraFlashModeOff;
        flashModeButton.alpha = 1.0;
        showFlashMode = YES;
    }
    
    camera.videoQuality = UIImagePickerControllerQualityType640x480;
    
    camera.delegate = self;
    camera.edgesForExtendedLayout = UIRectEdgeAll;
    
    //[self presentViewController:camera animated:YES completion:nil];
    
    if (![self isAuthorized])
    {
        // Not yet authorized, request authorization and push the login UI onto the navigation stack.
        [camera pushViewController:[self createAuthController] animated:YES];
    }
}

- (void)toggleVideoRecording {
    if (!recording) {
        recording = YES;
        [self startRecording];
    } else {
        recording = NO;
        [self stopRecording];
    }
}

- (void)changeVideoQuality:(id)sender {
    if (camera.videoQuality == UIImagePickerControllerQualityType640x480) {
        camera.videoQuality = UIImagePickerControllerQualityTypeHigh;
        [videoQualitySelectionButton setImage:[UIImage imageNamed:@"hd-selected.png"] forState:UIControlStateNormal];
    } else {
        camera.videoQuality = UIImagePickerControllerQualityType640x480;
        [videoQualitySelectionButton setImage:[UIImage imageNamed:@"sd-selected.png"] forState:UIControlStateNormal];
    }
}

- (void)changeFlashMode:(id)sender {
    if (camera.cameraFlashMode == UIImagePickerControllerCameraFlashModeOff) {
        camera.cameraFlashMode = UIImagePickerControllerCameraFlashModeOn;
        [flashModeButton setImage:[UIImage imageNamed:@"flash-on.png"] forState:UIControlStateNormal];
    } else {
        camera.cameraFlashMode = UIImagePickerControllerCameraFlashModeOff;
        [flashModeButton setImage:[UIImage imageNamed:@"flash-off.png"] forState:UIControlStateNormal];
    }
}

- (void)changeCamera:(id)sender {
    if (camera.cameraDevice == UIImagePickerControllerCameraDeviceRear) {
        camera.cameraDevice = UIImagePickerControllerCameraDeviceFront;
    } else {
        camera.cameraDevice = UIImagePickerControllerCameraDeviceRear;
    }
    
    if ( ![UIImagePickerController isFlashAvailableForCameraDevice:camera.cameraDevice] ) {
        [UIView animateWithDuration:0.3 animations:^(void) {flashModeButton.alpha = 0;}];
        showFlashMode = NO;
    } else {
        [UIView animateWithDuration:0.3 animations:^(void) {flashModeButton.alpha = 1.0;}];
        showFlashMode = YES;
    }
}

- (void)startRecording {
    
    void (^hideControls)(void);
    hideControls = ^(void) {
        cameraSelectionButton.alpha = 0;
        flashModeButton.alpha = 0;
        videoQualitySelectionButton.alpha = 0;
        recordIndicatorView.alpha = 1.0;
    };
    
    void (^recordMovie)(BOOL finished);
    recordMovie = ^(BOOL finished) {
        [camera startVideoCapture];
    };
    
    // Hide controls
    [UIView  animateWithDuration:0.3 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:hideControls completion:recordMovie];
}

- (void)stopRecording {
    [camera stopVideoCapture];
}


// Handle selection of an image
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    NSString *mediaType = [info objectForKey: UIImagePickerControllerMediaType];
    
    if (CFStringCompare ((__bridge CFStringRef) mediaType, kUTTypeMovie, 0) == kCFCompareEqualTo) {
        NSURL *videoUrl=(NSURL*)[info objectForKey:UIImagePickerControllerMediaURL];
        NSString *videoPath = [videoUrl path];
        
        if (UIVideoAtPathIsCompatibleWithSavedPhotosAlbum (videoPath)) {
            
            //save to Google Drive
            [self uploadVideo:videoPath];
            
            //save to photo album
            UISaveVideoAtPathToSavedPhotosAlbum(videoPath, self, @selector(video:didFinishSavingWithError:contextInfo:), NULL);
            
        } else {
            
            [self video:videoPath didFinishSavingWithError:nil contextInfo:NULL];
        }
    }
    
}

- (void)video:(NSString *)videoPath didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo {
    
    void (^showControls)(void);
    showControls = ^(void) {
        if (showCameraSelection) cameraSelectionButton.alpha = 1.0;
        if (showFlashMode) flashModeButton.alpha = 1.0;
        videoQualitySelectionButton.alpha = 1.0;
        recordIndicatorView.alpha = 0.0;
    };
    
    // Show controls
    [UIView  animateWithDuration:0.3 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:showControls completion:NULL];
    
}

// Handle cancel from image picker/camera.
- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

// Helper to check if user is authorized
- (BOOL)isAuthorized
{
    return [((GTMOAuth2Authentication *)self.driveService.authorizer) canAuthorize];
}

// Creates the auth controller for authorizing access to Google Drive.
- (GTMOAuth2ViewControllerTouch *)createAuthController
{
    GTMOAuth2ViewControllerTouch *authController;
    authController = [[GTMOAuth2ViewControllerTouch alloc] initWithScope:kGTLAuthScopeDriveFile
                                                                clientID:kClientID
                                                            clientSecret:kClientSecret
                                                        keychainItemName:kKeychainItemName
                                                                delegate:self
                                                        finishedSelector:@selector(viewController:finishedWithAuth:error:)];
    return authController;
}

// Handle completion of the authorization process, and updates the Drive service
// with the new credentials.
- (void)viewController:(GTMOAuth2ViewControllerTouch *)viewController
      finishedWithAuth:(GTMOAuth2Authentication *)authResult
                 error:(NSError *)error
{
    if (error != nil)
    {
        [self showAlert:@"Authentication Error" message:error.localizedDescription];
        self.driveService.authorizer = nil;
    }
    else
    {
        self.driveService.authorizer = authResult;
    }
}

// Upload video to Google Drive
- (void)uploadVideo:(NSString *)videoURLPath
{
    NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
    [dateFormat setDateFormat:@"BMLP Video Archiver Uploaded File ('EEEE MMMM d, YYYY h:mm a, zzz')"];
    
    GTLDriveFile *file = [GTLDriveFile object];
    file.title = [dateFormat stringFromDate:[NSDate date]];
    file.descriptionProperty = @"Uploaded from BMLP Video Archiver";
    file.mimeType = @"video/quicktime";
    
    NSError *error = nil;
    
    NSData *data = [NSData dataWithContentsOfFile:videoURLPath options:NSDataReadingMappedIfSafe error:&error];
    
    GTLUploadParameters *uploadParameters = [GTLUploadParameters uploadParametersWithData:data MIMEType:file.mimeType];
    GTLQueryDrive *query = [GTLQueryDrive queryForFilesInsertWithObject:file
                                                       uploadParameters:uploadParameters];
    
    UIAlertView *waitIndicator = [self showWaitIndicator:@"Uploading to Google Drive"];
    
    [self.driveService executeQuery:query
                  completionHandler:^(GTLServiceTicket *ticket,
                                      GTLDriveFile *insertedFile, NSError *error) {
                      [waitIndicator dismissWithClickedButtonIndex:0 animated:YES];
                      if (error == nil)
                      {
                          NSLog(@"File ID: %@", insertedFile.identifier);
                          [self showAlert:@"Google Drive" message:@"File saved!"];
                      }
                      else
                      {
                          NSLog(@"An error occurred: %@", error);
                          [self showAlert:@"Google Drive" message:@"Sorry, an error occurred!"];
                      }
                  }];
}

// Helper for showing a wait indicator in a popup
- (UIAlertView*)showWaitIndicator:(NSString *)title
{
    UIAlertView *progressAlert;
    progressAlert = [[UIAlertView alloc] initWithTitle:title
                                               message:@"Please wait..."
                                              delegate:nil
                                     cancelButtonTitle:nil
                                     otherButtonTitles:nil];
    [progressAlert show];
    
    UIActivityIndicatorView *activityView;
    activityView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    activityView.center = CGPointMake(progressAlert.bounds.size.width / 2,
                                      progressAlert.bounds.size.height - 45);
    
    [progressAlert addSubview:activityView];
    [activityView startAnimating];
    return progressAlert;
}

// Helper for showing an alert
- (void)showAlert:(NSString *)title message:(NSString *)message
{
    UIAlertView *alert;
    alert = [[UIAlertView alloc] initWithTitle: title
                                       message: message
                                      delegate: nil
                             cancelButtonTitle: @"OK"
                             otherButtonTitles: nil];
    [alert show];
}

@end
