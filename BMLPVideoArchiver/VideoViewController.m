//
//  VideoViewController.m
//  BMLPVideoArchiver
//
//  Created by Justine Kay on 10/26/15.
//  Copyright © 2015 Justine Kay. All rights reserved.

#import <MobileCoreServices/MobileCoreServices.h>
#import <DMPasscode/DMPasscode.h>
#import "VideoViewController.h"
#import "LogInViewController.h"
#import "GTMOAuth2ViewControllerTouch.h"
#import "GTLDrive.h"
#import "NYAlertViewController.h"

static NSString *const kKeychainItemName = @"BMLP Video Archiver";
static NSString *const kClientID = @"749579524688-b1oaiu8cc4obq06aal4org55qie5lho2.apps.googleusercontent.com";
static NSString *const kClientSecret = @"0U67OQ3UNhX72tmba7ZhMSYK";

@interface VideoViewController ()

- (void)setUpCamera;
- (void)startVideoRecording;
- (void)stopVideoRecording;

- (void)video:(NSString *)videoPath didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo;

@property (nonatomic, retain) GTLServiceDrive *driveService;
@property (nonatomic) GTLDriveParentReference *parentRef;
@property (nonatomic) CustomCameraOverlayView *customCameraOverlayView;
@property (nonatomic) NSInteger timeInSeconds;
@property (nonatomic) NSTimer *timer;
@property (nonatomic) UIBackgroundTaskIdentifier backgroundTask;

@end

@implementation VideoViewController

@synthesize driveService;

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.backgroundTask = UIBackgroundTaskInvalid;
    
    self.navigationController.navigationBarHidden = YES;
    
    [self setUpCamera];
    [self prepareAudioRecorder];
    
    self.timeInSeconds = 0;
    
    // Initialize the drive service & load existing credentials from the keychain if available
    self.driveService = [[GTLServiceDrive alloc] init];
    self.driveService.authorizer = [GTMOAuth2ViewControllerTouch authForGoogleFromKeychainForName:kKeychainItemName
                                                                                         clientID:kClientID
                                                                                     clientSecret:kClientSecret];
    //Background/Foreground notifications
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appDidEnterBackground)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appWillEnterForeground)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appDidBecomeActive)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appWillResignActive)
                                                 name:UIApplicationWillResignActiveNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(cameraIsReady:)
                                                 name:AVCaptureSessionDidStartRunningNotification object:nil];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if (![self isAuthorized]) {

        [self presentViewController:[self createAuthController] animated:YES completion:nil];
        
    }else {
        
        [self presentViewController:camera animated:animated completion:nil];
    }
}

- (void)cameraIsReady:(NSNotification *)notification
{
    NSLog(@"Camera is ready...");
    
    if (videoSessionInProgress) {
        
        videoRecording = YES;
        [camera startVideoCapture];
        [self startRecordingTimer];
        
        self.customCameraOverlayView.stopRecordingView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.5];
        self.customCameraOverlayView.stopRecordingView.alpha = 1.0;
        
        NSLog(@"Video recording continued...");
        
    }

}

- (void)appDidBecomeActive
{
    NSLog(@"App did become active.");   
}

- (void)appWillResignActive
{
    if (videoSessionInProgress) {
        
        [self stopVideoRecording];
    }
    
    NSLog(@"App will resign active.");
}

- (void)appDidEnterBackground{
    
    inBackground = YES;
    
    if (!audioRecorder.recording && [self isAuthorized]) {
        
        AVAudioSession *audioSession = [AVAudioSession sharedInstance];
        [audioSession setActive:YES error:nil];
        
        [self startAudioRecording];
        
        audioSessionInProgress = YES;
    }
    
    
    UIApplication *app = [UIApplication sharedApplication];
    
    self.backgroundTask = [app beginBackgroundTaskWithName:@"MyTask" expirationHandler:^{
        // Clean up any unfinished task business by marking where you
        // stopped or ending the task outright.
        
        NSLog(@"Background handler called. Not running background tasks anymore.");
        [app endBackgroundTask:self.backgroundTask];
        self.backgroundTask = UIBackgroundTaskInvalid;
    }];
    
    // Start the long-running task
//    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
//        
//        // Do the work associated with the task, preferably in chunks.
//        if (!audioRecorder.recording && [self isAuthorized]) {
//            
//            AVAudioSession *audioSession = [AVAudioSession sharedInstance];
//            [audioSession setActive:YES error:nil];
//            
//            [self startAudioRecording];
//        }
//        
//    });
   
}

- (void)appWillEnterForeground
{
    inBackground = NO;
    
    [self stopAudioRecording];
    
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    [audioSession setActive:NO error:nil];
    
    audioSessionInProgress = NO;
    
    self.customCameraOverlayView.stopRecordingView.alpha = 0.0;
    
    NSLog(@"audio session ended");
    
    if (self.backgroundTask != UIBackgroundTaskInvalid)
    {
        [[UIApplication sharedApplication] endBackgroundTask:self.backgroundTask];
        self.backgroundTask = UIBackgroundTaskInvalid;
    }
    
}


#pragma mark - audioRecorder

- (void)prepareAudioRecorder
{
    //set audio session
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    [audioSession setCategory:AVAudioSessionCategoryRecord error:nil];
    
    //set audio file path
    NSArray *searchPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentPath = searchPaths[0];
    
    NSString *pathToSave = [documentPath stringByAppendingPathComponent:[self dateString]];
    
    // File URL
    NSURL *url = [NSURL fileURLWithPath:pathToSave];
    
    //Save recording path to NSUserDefaults
    NSUserDefaults *paths = [NSUserDefaults standardUserDefaults];
    [paths setURL:url forKey:@"filePath"];
    [paths synchronize];
  
    NSError *error;
    
    // Create recorder
    audioRecorder = [[AVAudioRecorder alloc] initWithURL:url settings:[self audioRecorderSettings] error:&error];
    audioRecorder.delegate = self;
    audioRecorder.meteringEnabled = YES;
    [audioRecorder prepareToRecord];
}

- (NSString *)dateString
{
    // return a formatted string for a file name
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"ddMMMYY_hhmmssa";
    return [[formatter stringFromDate:[NSDate date]] stringByAppendingString:@".m4a"];
}


-(NSDictionary *)audioRecorderSettings
{
    // Recording settings
    NSDictionary *settings = [NSDictionary dictionary];
    
    settings = [NSDictionary dictionaryWithObjectsAndKeys:
                [NSNumber numberWithInt: kAudioFormatMPEG4AAC], AVFormatIDKey,
                [NSNumber numberWithFloat:16000.0], AVSampleRateKey,
                [NSNumber numberWithInt: 1], AVNumberOfChannelsKey,
                nil];
    
    return settings;
    
}

-(void)audioRecorderDidFinishRecording:(AVAudioRecorder *)recorder successfully:(BOOL)flag {
    
    //save audio file to google drive
    //***(TO DO: Save on device?...)***
    
    //Load recording path from preferences
    NSUserDefaults *paths = [NSUserDefaults standardUserDefaults];
    NSURL *audioFileUrl = [paths URLForKey:@"filePath"];
    NSString *audioFilePath = [audioFileUrl path];
    
    //Upload to google drive
    isVideoFile = NO;
    [self uploadToGoogleDriveInDatedFolder:audioFilePath];
    
    //restart audioRecorder
    if (inBackground) {
        
        [self startAudioRecording];
    }
}

-(void)startAudioRecording
{
        [audioRecorder record];
        [self startRecordingTimer];
        
        NSLog(@"Audio recording started");
}

-(void)stopAudioRecording
{
        [audioRecorder stop];
        [self resetTimer];
        
        NSLog(@"Audio recording stopped");
}


#pragma mark - camera and customCameraOverlay set up

-(void)customCameraOverlay
{
    CameraOverlayViewController *overlayVC = [[CameraOverlayViewController alloc] initWithNibName:@"CameraOverlayViewController" bundle:nil];
    self.customCameraOverlayView = (CustomCameraOverlayView *)overlayVC.view;
    
    self.customCameraOverlayView.delegate = self;
    
    self.customCameraOverlayView.stopRecordingView.alpha = 0.0;
    self.customCameraOverlayView.stopRecordingView.layer.cornerRadius = 30.0;
    self.customCameraOverlayView.stopRecordingView.backgroundColor = [UIColor whiteColor];
    
    self.customCameraOverlayView.cameraSelectionButton.alpha = 0.0;
    self.customCameraOverlayView.flashModeButton.alpha = 0.0;
    self.customCameraOverlayView.uploadingLabel.alpha = 0.0;
    self.customCameraOverlayView.fileSavedLabel.alpha = 0.0;
    self.customCameraOverlayView.backgroundColor = [UIColor clearColor];
    self.customCameraOverlayView.menuBarView.backgroundColor = [UIColor colorWithRed:211.0/255.0 green:211.0/255.0 blue:211.0/255.0 alpha:0.25];
    
    self.customCameraOverlayView.frame = camera.view.frame;
    
    recordGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(beginVideoRecordingSession)];
    recordGestureRecognizer.numberOfTapsRequired = 2;
    
    [self.customCameraOverlayView addGestureRecognizer:recordGestureRecognizer];
    
}

- (void)setUpCamera
{
    camera = [[UIImagePickerController alloc] init];
    camera.sourceType = UIImagePickerControllerSourceTypeCamera;
    
    camera.mediaTypes = [[NSArray alloc] initWithObjects:(NSString *)kUTTypeMovie, nil];
    camera.cameraCaptureMode = UIImagePickerControllerCameraCaptureModeVideo;
    
    camera.showsCameraControls = NO;
    camera.cameraViewTransform = CGAffineTransformIdentity;
    
    //create custom overlay and apply to camera
    [self customCameraOverlay];
    camera.cameraOverlayView = self.customCameraOverlayView;
    
    // not all devices have two cameras or a flash so just check here
    if ( [UIImagePickerController isCameraDeviceAvailable: UIImagePickerControllerCameraDeviceRear] ) {
        
        camera.cameraDevice = UIImagePickerControllerCameraDeviceRear;
        
        if ( [UIImagePickerController isCameraDeviceAvailable: UIImagePickerControllerCameraDeviceFront] ) {
            
            [self.customCameraOverlayView.cameraSelectionButton setImage:[UIImage imageNamed:@"camera-toggle"] forState:UIControlStateNormal];
            self.customCameraOverlayView.cameraSelectionButton.imageView.contentMode = UIViewContentModeScaleAspectFit;
            self.customCameraOverlayView.cameraSelectionButton.alpha = 1.0;
            showCameraSelection = YES;
        }
        
    } else {
        
        camera.cameraDevice = UIImagePickerControllerCameraDeviceFront;
    
    }
    
    
    if ( [UIImagePickerController isFlashAvailableForCameraDevice:camera.cameraDevice] ) {
        
        camera.cameraFlashMode = UIImagePickerControllerCameraFlashModeOff;
        [self.customCameraOverlayView.flashModeButton setImage:[UIImage imageNamed:@"flash-off.png"] forState:UIControlStateNormal];
        self.customCameraOverlayView.flashModeButton.imageView.contentMode = UIViewContentModeScaleAspectFit;
        self.customCameraOverlayView.flashModeButton.alpha = 1.0;
        showFlashMode = YES;
    
    }
    
    
    camera.videoQuality = UIImagePickerControllerQualityType640x480;
    
    camera.delegate = self;
    camera.edgesForExtendedLayout = UIRectEdgeAll;
    
    
}

-(void)showCameraControls
{
    void (^showControls)(void);
    showControls = ^(void) {
        
        self.customCameraOverlayView.menuBarView.alpha = 1.0;
        if (showCameraSelection) self.customCameraOverlayView.cameraSelectionButton.alpha = 1.0;
        if (showFlashMode) self.customCameraOverlayView.flashModeButton.alpha = 1.0;
        
    };
    
    // Show controls
    [UIView  animateWithDuration:0.3 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:showControls completion:NULL];
}

#pragma mark - Recording Timer

-(void)startRecordingTimer
{
    dispatch_async(dispatch_get_main_queue(), ^{
        
        [self.timer invalidate];
        self.timer = nil;
        
        self.timer = [NSTimer timerWithTimeInterval:1.0 target:self selector:@selector(fireTimer:) userInfo:nil repeats:YES];
        [[NSRunLoop currentRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];
        
        NSDate *timerTimeStamp = [NSDate date];
        [[NSUserDefaults standardUserDefaults] setValue:timerTimeStamp forKey:@"startTimeStamp"];
        
        
    });
    
}

-(void)fireTimer: (NSTimer *) timer
{
    NSDate *startTime = [[NSUserDefaults standardUserDefaults] valueForKey:@"startTimeStamp"];
    NSTimeInterval stopTimeInterval = 30.0;
    NSTimeInterval currentTimeInterval = [[NSDate date] timeIntervalSinceDate:startTime];
    
    //For debugging only
    self.timeInSeconds += 1;
    
    if (currentTimeInterval >= stopTimeInterval) {
    
        [self stopVideoRecording];
        [self stopAudioRecording];
        
    }
    
    NSLog(@"Timer Fired, time in seconds: %ld", (long)self.timeInSeconds);
}

-(void)resetTimer
{
    dispatch_async(dispatch_get_main_queue(), ^{
        
        if (self.timer){
            
            [self.timer invalidate];
            self.timer = nil;
            
            self.timeInSeconds = 0;
            
            NSLog(@"Timer reset");
        }
    });
}


#pragma Mark - CustomCameraOverlayDelegate methods

-(void)didStopRecordingVideo
{
    [self showVideoRecordingActiveAlertView];
}

-(void)didTapSettingsButton
{
    [self showSettingsAlertView];

}

-(void)signOutOfGoogleDrive
{
    [GTMOAuth2ViewControllerTouch removeAuthFromKeychainForName:kKeychainItemName];
    
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:SignedInKey];
    
    UINavigationController *navigationController = self.navigationController;
    
    //Get all view controllers in navigation controller currently
    NSMutableArray *controllers=[[NSMutableArray alloc] initWithArray:navigationController.viewControllers] ;
    
    //Remove the last view controller
    [controllers removeLastObject];
    
    //set the new set of view controllers
    [navigationController setViewControllers:controllers];
    
    [camera dismissViewControllerAnimated:NO completion:^{
        
        [navigationController popToRootViewControllerAnimated:NO];
        
    }];

}

- (void)didChangeFlashMode
{
    if (camera.cameraFlashMode == UIImagePickerControllerCameraFlashModeOff) {
        
        camera.cameraFlashMode = UIImagePickerControllerCameraFlashModeOn;
        [self.customCameraOverlayView.flashModeButton setImage:[UIImage imageNamed:@"flash-on.png"] forState:UIControlStateNormal];
    
    } else {
        
        camera.cameraFlashMode = UIImagePickerControllerCameraFlashModeOff;
        [self.customCameraOverlayView.flashModeButton setImage:[UIImage imageNamed:@"flash-off.png"] forState:UIControlStateNormal];
    
    }
}

- (void)didChangeCamera
{
    if (camera.cameraDevice == UIImagePickerControllerCameraDeviceRear) {
        
        camera.cameraDevice = UIImagePickerControllerCameraDeviceFront;
    
    } else {
        
        camera.cameraDevice = UIImagePickerControllerCameraDeviceRear;
    }
    
    if ( ![UIImagePickerController isFlashAvailableForCameraDevice:camera.cameraDevice] ) {
        
        [UIView animateWithDuration:0.3 animations:^(void) {self.customCameraOverlayView.flashModeButton.alpha = 0;}];
        showFlashMode = NO;
    
    } else {
        
        [UIView animateWithDuration:0.3 animations:^(void) {self.customCameraOverlayView.flashModeButton.alpha = 1.0;}];
        showFlashMode = YES;
    
    }
}


#pragma mark - UIImagePickerController camera and delegate methods

- (void)beginVideoRecordingSession
{
    if (!videoRecording) {
        
        videoSessionInProgress = YES;
        
        [self startVideoRecording];
        
        NSLog(@"video recording started");
        
    }
}

- (void)startVideoRecording
{
    void (^hideControls)(void);
    hideControls = ^(void) {
        self.customCameraOverlayView.menuBarView.alpha = 0.0;
        self.customCameraOverlayView.cameraSelectionButton.alpha = 0.0;
        self.customCameraOverlayView.flashModeButton.alpha = 0.0;
        self.customCameraOverlayView.stopRecordingView.alpha = 1.0;
        self.customCameraOverlayView.stopRecordingView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.5];
    };
    
    void (^recordMovie)(BOOL finished);
    recordMovie = ^(BOOL finished) {
        
        videoRecording = YES;
        [camera startVideoCapture];
        [self startRecordingTimer];
    };
    
    // Hide controls
    [UIView  animateWithDuration:0.3 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:hideControls completion:recordMovie];
}

- (void)stopVideoRecording
{
    if (videoRecording) {
     
        [self resetTimer];
        
        videoRecording = NO;
        
        [camera stopVideoCapture];
        
        if (!videoSessionInProgress && !inBackground) {
            
            self.customCameraOverlayView.stopRecordingView.alpha = 0.0;
        }
        
        NSLog(@"Video recording: %@", (videoRecording ? @"YES" : @"NO"));
    }
    
}


// Handle most recent video recording
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    NSString *mediaType = [info objectForKey: UIImagePickerControllerMediaType];
    
    if (CFStringCompare ((__bridge CFStringRef) mediaType, kUTTypeMovie, 0) == kCFCompareEqualTo) {
        NSURL *videoUrl = (NSURL*)[info objectForKey:UIImagePickerControllerMediaURL];
        NSString *videoPath = [videoUrl path];
        
        if (UIVideoAtPathIsCompatibleWithSavedPhotosAlbum (videoPath)) {
            
            //save to Google Drive
            isVideoFile = YES;
            [self uploadToGoogleDriveInDatedFolder:videoPath];
                        
            //save to photo album
            UISaveVideoAtPathToSavedPhotosAlbum(videoPath, self, @selector(video:didFinishSavingWithError:contextInfo:), NULL);
            
        } else {
            
            [self video:videoPath didFinishSavingWithError:nil contextInfo:NULL];
        }
    
    }
    
    
    if (videoSessionInProgress && !inBackground) {
        
        videoRecording = YES;
        [camera startVideoCapture];
        [self startRecordingTimer];
        
        NSLog(@"recording continued...");
    }
}

- (void)video:(NSString *)videoPath didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo
{
   if (!videoSessionInProgress) {
        
       [self showCameraControls];
    }
    
}

// Handle cancel from image picker/camera.
- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma Mark - Google Drive Authorization and Uploading methods

// Helper to check if user is authorized
- (BOOL)isAuthorized
{
    
    BOOL auth = [((GTMOAuth2Authentication *)self.driveService.authorizer) canAuthorize];
    
    if (auth == YES) {
        
        //Set Bool for presenting LogInVC
        [[NSUserDefaults standardUserDefaults] setBool:auth forKey:SignedInKey];

    }
    
    return auth;
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
        NSString *errorMessage = [NSString stringWithFormat:@"Authentication Error: %@", error];
        NSLog( @"%@", errorMessage);
        self.driveService.authorizer = nil;
    }
    else
    {
        [self.parentViewController dismissViewControllerAnimated:NO completion:nil];
        [viewController removeFromParentViewController];
        
        self.driveService.authorizer = authResult;
        


    }
}

-(void)uploadToGoogleDriveInDatedFolder: (NSString *)filePath
{
    [self searchForMainBMLPFolder:^(BOOL finished) {
        
        if (finished) {
            
            if (!mainFolder) {
                
                [self createMainBMLPfolder:^(GTLDriveParentReference *identifier) {
                    
                    [self createNewDatedFolderWithParentRef:identifier completion:^(GTLDriveParentReference *identifier) {
                        
                        if (isVideoFile) {
                            
                            [self uploadVideo:filePath WithParentRef:identifier];
                            
                        }else {
                            
                            [self uploadAudio:filePath WithParentRef:identifier];
                        }
                        
                        
                    }];
                    
                }];
                
            }else {
                
                [self searchForDatedFolder:^(BOOL finished) {
                    
                    if (finished) {
                        
                        if (!datedFolder) {
                            
                            [self createNewDatedFolderWithParentRef:self.parentRef completion:^(GTLDriveParentReference *identifier) {
                                
                                if (isVideoFile) {
                                    
                                    [self uploadVideo:filePath WithParentRef:identifier];
                                    
                                }else {
                                    
                                    [self uploadAudio:filePath WithParentRef:identifier];
                                }
                                
                            }];
                            
                        } else {
                            
                            if (isVideoFile) {
                                
                                [self uploadVideo:filePath WithParentRef:self.parentRef];
                                
                            }else {
                                
                                [self uploadAudio:filePath WithParentRef:self.parentRef];
                            }
                            
                        }
                        
                    }
                    
                }];
                
            }
            
        }
    }];
    
    
}

//Check if a main BMLP folder has been created
typedef void(^completion)(BOOL);

- (void)searchForMainBMLPFolder:(completion) compblock
{
    NSString *parentId = @"root";
    
    GTLQueryDrive *query = [GTLQueryDrive queryForFilesList];
    query.q = [NSString stringWithFormat:@"'%@' in parents and trashed=false", parentId];
    [self.driveService executeQuery:query completionHandler:^(GTLServiceTicket *ticket,
                                                              GTLDriveFileList *fileList,
                                                              NSError *error) {
        if (error == nil) {
            NSLog(@"Have results");
            
            // Iterate over fileList.items array
            [self folder: @"BMLP Video Archiver Files" FoundInFileList:fileList.items Completion:^(bool folderFound) {
             
                mainFolder = folderFound;
                
                compblock(YES);
            }];
            
        } else {
            
            NSLog(@"An error occurred: %@", error);
            compblock(YES);
        }
        
    }];
}

//Check if dated folder has been created
- (void)searchForDatedFolder:(completion) compblock
{
    NSString *parentId = self.parentRef.identifier;
    
    GTLQueryDrive *query = [GTLQueryDrive queryForFilesList];
    query.q = [NSString stringWithFormat:@"'%@' in parents and trashed=false", parentId];
    [self.driveService executeQuery:query completionHandler:^(GTLServiceTicket *ticket,
                                                              GTLDriveFileList *fileList,
                                                              NSError *error) {
        if (error == nil) {
            NSLog(@"Have results");
            
            // Iterate over fileList.items array
            [self folder:[self datedFolderDateString] FoundInFileList:fileList.items Completion:^(bool folderFound) {
                
                datedFolder = folderFound;
                compblock(YES);
            }];
            
        } else {
            
            NSLog(@"An error occurred: %@", error);
            compblock(YES);
        }
        
    }];
}

//Check for folder and set self.parentRef if found
- (void)folder: (NSString *)folderTitle FoundInFileList: (NSArray *)items Completion: (void (^)(bool folderFound))handler
{
    BOOL found = NO;
    GTLDriveParentReference *parentRef = [GTLDriveParentReference object];
    
    for (GTLDriveFile *item in items) {
        
        if ([item.title isEqualToString:folderTitle]) {
            
            found = YES;
            parentRef.identifier = item.identifier;
            self.parentRef = parentRef;
        }
    }
    
    handler(found);
}

//Create main folder in Google Drive for BMLP files
- (void)createMainBMLPfolder:(void (^)(GTLDriveParentReference *identifier))handler
{
    GTLDriveFile *folder = [GTLDriveFile object];
    folder.title = @"BMLP Video Archiver Files";
    folder.mimeType = @"application/vnd.google-apps.folder";
    GTLDriveParentReference *parentRef = [GTLDriveParentReference object];
    
    GTLQueryDrive *query = [GTLQueryDrive queryForFilesInsertWithObject:folder uploadParameters:nil];
    [self.driveService executeQuery:query completionHandler:^(GTLServiceTicket *ticket,
                                                  GTLDriveFile *updatedFile,
                                                  NSError *error) {
        if (error == nil) {
            NSLog(@"Created main BMLP files folder");
            mainFolder = YES;
            parentRef.identifier = updatedFile.identifier; // identifier property of the folder
            
        } else {
            NSLog(@"An error occurred: %@", error);
        }
        
        handler(parentRef);
    }];
    
}



//Create a new folder inside the main folder for each date
- (GTLDriveFile *)createNewDatedFolderWithParentRef: (GTLDriveParentReference *)mainFolderParentRef completion: (void (^)(GTLDriveParentReference *identifier))handler
{
    GTLDriveFile *folder = [GTLDriveFile object];
    folder.title = [self datedFolderDateString];
    folder.mimeType = @"application/vnd.google-apps.folder";
    folder.parents = @[mainFolderParentRef];
    
    GTLDriveParentReference *newFolderParentRef = [GTLDriveParentReference object];
    
    GTLQueryDrive *query = [GTLQueryDrive queryForFilesInsertWithObject:folder uploadParameters:nil];
    [self.driveService executeQuery:query completionHandler:^(GTLServiceTicket *ticket,
                                                  GTLDriveFile *updatedFile,
                                                  NSError *error) {
        if (error == nil) {
            
            NSLog(@"Created new dated folder");
            datedFolder = YES;
            newFolderParentRef.identifier = updatedFile.identifier; // identifier property of the folder
        
        } else {
            
            NSLog(@"An error occurred: %@", error);
        }
        
        handler(newFolderParentRef);
    }];
    
    return folder;
}


//date formatter helper method
- (NSString *)datedFolderDateString
{
    // return a formatted string for a file name
    NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
    [dateFormat setDateFormat:@"yyyy-MM-dd"];
    return [dateFormat stringFromDate:[NSDate date]];
}


// Upload audio to Google Drive
- (void)uploadAudio:(NSString *)audioURLPath WithParentRef: (GTLDriveParentReference *)parentRef
{
    NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
    [dateFormat setDateFormat:@"BMLP Video Archiver Audio File ('EEEE MMMM d, YYYY h:mm a, zzz')"];
    
    GTLDriveFile *file = [GTLDriveFile object];
    file.originalFilename = [dateFormat stringFromDate:[NSDate date]];
    file.title = file.originalFilename;
    file.descriptionProperty = @"Uploaded from BMLP Video Archiver";
    //file.mimeType = @"audio/mp4";
    
    if (parentRef) {
        
        file.parents = @[parentRef];
    }
    
    NSError *error = nil;
    
    NSData *data = [NSData dataWithContentsOfFile:audioURLPath options:NSDataReadingMappedIfSafe error:&error];
    
    GTLUploadParameters *uploadParameters = [GTLUploadParameters uploadParametersWithData:data MIMEType:file.mimeType];
    GTLQueryDrive *query = [GTLQueryDrive queryForFilesInsertWithObject:file
                                                       uploadParameters:uploadParameters];
    
    
    [self.driveService executeQuery:query
                  completionHandler:^(GTLServiceTicket *ticket,
                                      GTLDriveFile *insertedFile, NSError *error) {
                      
                      
                      if (error == nil) {
                          
                          NSLog(@"File ID: %@", insertedFile.identifier);
                          
                      } else {
                          
                          NSLog(@"An error occurred: %@", error);
                      }
                      
                  }];
}


// Upload video to Google Drive
- (void)uploadVideo:(NSString *)videoURLPath WithParentRef: (GTLDriveParentReference *)parentRef
{
    NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
    [dateFormat setDateFormat:@"BMLP Video Archiver Video File ('EEEE MMMM d, YYYY h:mm a, zzz')"];
    
    GTLDriveFile *file = [GTLDriveFile object];
    file.originalFilename = [dateFormat stringFromDate:[NSDate date]];
    file.title = file.originalFilename;
    file.descriptionProperty = @"Uploaded from BMLP Video Archiver";
    file.mimeType = @"video/quicktime";

    
    if (parentRef) {
        
        file.parents = @[parentRef];
    }
    
    
    NSError *error = nil;
    
    NSData *data = [NSData dataWithContentsOfFile:videoURLPath options:NSDataReadingMappedIfSafe error:&error];
    
    GTLUploadParameters *uploadParameters = [GTLUploadParameters uploadParametersWithData:data MIMEType:file.mimeType];
    GTLQueryDrive *query = [GTLQueryDrive queryForFilesInsertWithObject:file
                                                       uploadParameters:uploadParameters];
    
    
    //create animation
    CABasicAnimation *animation = [self animateOpacity];
    
    //animation will start immediately
    [self.customCameraOverlayView.uploadingLabel.layer addAnimation:animation forKey:@"animateOpacity"];
    
    [self.driveService executeQuery:query
                  completionHandler:^(GTLServiceTicket *ticket,
                                      GTLDriveFile *insertedFile, NSError *error) {
                      
                      
                      if (error == nil)
                      {
                          NSLog(@"File ID: %@", insertedFile.identifier);
                          
                          [self.customCameraOverlayView.uploadingLabel.layer removeAllAnimations];
                          self.customCameraOverlayView.uploadingLabel.alpha = 0.0;
                          
                          [self fadeInFadeOutInfoLabel:self.customCameraOverlayView.fileSavedLabel WithMessage:@"File Saved"];
                          
                          
                      }
                      else
                      {
                          NSLog(@"An error occurred: %@", error);
                          
                          [self.customCameraOverlayView.uploadingLabel.layer removeAllAnimations];
                          self.customCameraOverlayView.uploadingLabel.alpha = 0.0;
                          
                          [self fadeInFadeOutInfoLabel:self.customCameraOverlayView.fileSavedLabel WithMessage:@"Sorry an error occurred."];
                          
                      }
                  }];
}

#pragma mark - alert animations

// Helper for showing Info Label

-(void)fadeInFadeOutInfoLabel:(UILabel *)label WithMessage: (NSString *) message{

    
    label.text = message;
    label.backgroundColor = [UIColor blackColor];
    label.textColor = [UIColor whiteColor];

    //fade in
    [UIView animateWithDuration:0.5f animations:^{

        [label setAlpha:1.0f];

    } completion:^(BOOL finished) {

        //fade out
        [UIView animateWithDuration:5.0f animations:^{

            [label setAlpha:0.0f];

        } completion:nil];

    }];
}

-(CABasicAnimation *)animateOpacity
{
    //Create an animation with pulsating effect
    CABasicAnimation *theAnimation;
    
    //within the animation we will adjust the "opacity"
    //value of the layer
    theAnimation=[CABasicAnimation animationWithKeyPath:@"opacity"];
    
    //animation lasts 0.7 seconds
    theAnimation.duration=0.7;
    
    //and it repeats forever
    theAnimation.repeatCount= HUGE_VALF;
    
    //we want a reverse animation
    theAnimation.autoreverses=YES;
    
    //justify the opacity as you like (1=fully visible, 0=unvisible)
    theAnimation.fromValue=[NSNumber numberWithFloat:1.0];
    theAnimation.toValue=[NSNumber numberWithFloat:0.1];
    
    return theAnimation;
    
}

#pragma mark - NYAlertViewController methods

- (void)showSettingsAlertView
{
    NYAlertViewController *alertViewController = [[NYAlertViewController alloc] initWithNibName:nil bundle:nil];
    
    alertViewController.backgroundTapDismissalGestureEnabled = YES;
    alertViewController.swipeDismissalGestureEnabled = YES;
    
    alertViewController.title = NSLocalizedString(@"Settings", nil);
    alertViewController.message = nil;
    
    alertViewController.buttonCornerRadius = 20.0f;
    alertViewController.view.tintColor = self.view.tintColor;
    
    alertViewController.titleFont = [UIFont fontWithName:@"AvenirNext-Bold" size:18.0f];
    alertViewController.buttonTitleFont = [UIFont fontWithName:@"AvenirNext-Medium" size:alertViewController.buttonTitleFont.pointSize];
    alertViewController.cancelButtonTitleFont = [UIFont fontWithName:@"AvenirNext-Regular" size:alertViewController.cancelButtonTitleFont.pointSize];
    
    alertViewController.alertViewBackgroundColor = [UIColor blackColor];
    alertViewController.alertViewCornerRadius = 10.0f;
    
    alertViewController.titleColor = [UIColor lightGrayColor];
    
    alertViewController.buttonColor = [UIColor redColor];
    alertViewController.buttonTitleColor = [UIColor colorWithWhite:0.19f alpha:1.0f];
    
    alertViewController.cancelButtonColor = [UIColor lightGrayColor];
    alertViewController.cancelButtonTitleColor = [UIColor colorWithWhite:0.19f alpha:1.0f];
    
    [alertViewController addAction:[NYAlertAction actionWithTitle:NSLocalizedString(@"Change Passcode", nil)
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(NYAlertAction *action) {
                                                            
                                                              [camera dismissViewControllerAnimated:YES completion:^{
                                                                  
                                                                  //***TO DO: Set up Passcode here ***
                                                                  if ([[NSUserDefaults standardUserDefaults] objectForKey:@"userPasscode"]) {
                                                                      
                                                                      [DMPasscode removePasscode];
                                                                  }
                                                                  
                                                                  [DMPasscode setupPasscodeInViewController:camera completion:nil];
                                                              }];
                                                              
                                                          }]];
    
    [alertViewController addAction:[NYAlertAction actionWithTitle:NSLocalizedString(@"Switch Google Drive Account", nil)
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(NYAlertAction *action) {
                                                              
                                                              [camera dismissViewControllerAnimated:YES completion:^{
                                                                  
                                                                  [self signOutOfGoogleDrive];
                                                              }];
                                                          }]];
    
    [alertViewController addAction:[NYAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil)
                                                            style:UIAlertActionStyleCancel
                                                          handler:^(NYAlertAction *action) {
                                                              
                                                              [camera dismissViewControllerAnimated:YES completion:nil];
                                                          }]];
    
    [camera presentViewController:alertViewController animated:YES completion:nil];
}


- (void)showVideoRecordingActiveAlertView
{
    NYAlertViewController *alertViewController = [[NYAlertViewController alloc] initWithNibName:nil bundle:nil];
    alertViewController.title = NSLocalizedString(@"Video Recording Active", nil);
    alertViewController.message = NSLocalizedString(@"To stop recording you must enter your passcode", nil);
    
    alertViewController.view.tintColor = self.view.tintColor;
    alertViewController.backgroundTapDismissalGestureEnabled = YES;
    alertViewController.swipeDismissalGestureEnabled = YES;
    alertViewController.transitionStyle = NYAlertViewControllerTransitionStyleFade;
    
    alertViewController.titleFont = [UIFont fontWithName:@"AvenirNext-Bold" size:alertViewController.titleFont.pointSize];
    alertViewController.messageFont = [UIFont fontWithName:@"AvenirNext-Regular" size:alertViewController.messageFont.pointSize];
    alertViewController.buttonTitleFont = [UIFont fontWithName:@"AvenirNext-Regular" size:alertViewController.buttonTitleFont.pointSize];
    alertViewController.cancelButtonTitleFont = [UIFont fontWithName:@"AvenirNext-Medium" size:alertViewController.cancelButtonTitleFont.pointSize];
    
    NYAlertAction *submitAction = [NYAlertAction actionWithTitle:NSLocalizedString(@"Submit", nil)
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(NYAlertAction *action) {
                                                             
                                                             //if passcode is correct, stop video recording session
                                                             //*** TO DO: Set up Passcode ***
                                                             
                                                             videoSessionInProgress = NO;
                                                             
                                                             [self stopVideoRecording];
                                                             
                                                             NSLog(@"session ended");

                                                             [camera dismissViewControllerAnimated:NO completion:nil];
                                                         }];
    submitAction.enabled = NO;
    [alertViewController addAction:submitAction];
    
    // Disable the submit action until the user has filled out the text field
    [[NSNotificationCenter defaultCenter] addObserverForName:UITextFieldTextDidChangeNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {
                                                      
                                                      UITextField *passwordTextField = [alertViewController.textFields firstObject];
                                                      
                                                      submitAction.enabled = ([passwordTextField.text length]);
                                                  }];
    
    [alertViewController addAction:[NYAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil)
                                                            style:UIAlertActionStyleCancel
                                                          handler:^(NYAlertAction *action) {
                                                              [camera dismissViewControllerAnimated:NO completion:nil];
                                                          }]];
    
    
    [alertViewController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = NSLocalizedString(@"passcode", nil);
        textField.font = [UIFont fontWithName:@"AvenirNext-Regular" size:16.0f];
        textField.secureTextEntry = YES;
    }];

    
    [camera presentViewController:alertViewController animated:YES completion:nil];
}

@end
