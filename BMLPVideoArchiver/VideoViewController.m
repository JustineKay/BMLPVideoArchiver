//
//  VideoViewController.m
//  BMLPVideoArchiver
//
//  Created by Justine Kay on 10/26/15.
//  Copyright © 2015 Justine Kay. All rights reserved.

#import <AVFoundation/AVFoundation.h>
#import "CameraOverlayViewController.h"
#import "CustomCameraOverlayView.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import <DMPasscode/DMPasscode.h>
#import "VideoViewController.h"
#import "LogInViewController.h"
#import "GTMOAuth2ViewControllerTouch.h"
#import "GTLDrive.h"
#import "NYAlertViewController.h"
#import "Connectivity.h"
#import "ConnectivityViewController.h"
#import "SetPasscodeViewController.h"
#import "BMLPConstants.h"

// TODO(cspickert): So it's pretty clear that your entire app is basically implemented in this one file. Splitting it into multiple classes will make things much clearer and easier to test and maintain. You should start by identifying the main types of tasks you're trying to accomplish here:
// 1. Recording video (obviously)
// 2. Recording audio
// 3. Saving media locally
// 4. Saving media to Drive
// Each of these categories of functionality should be implemented using _at least_ one *non-UIViewController* class. It's important to do as much outside of UIKit as possible to make your code simpler, more maintainable, and more testable. For example, let's say you run into an intermittent case where recorded videos aren't making it to Drive. If the logic for uploading media is tied up with the rest of the code for building and displaying the UI, interacting with NSUserDefaults, etc., it might be very difficult for you to find the root of the problem and reproduce the exact circumstances that cause it.
// The guiding principle behind every class you write should be: "do one thing, and do it well" (a la the Unix philosophy).

@interface VideoViewController ()
<
AVAudioRecorderDelegate,
UINavigationControllerDelegate,
UIImagePickerControllerDelegate,
CustomCameraOverlayDelegate
>

@property (nonatomic) GTLServiceDrive *driveService;
@property (nonatomic) GTLDriveParentReference *parentRef;
@property (nonatomic) CustomCameraOverlayView *customCameraOverlayView;
@property (nonatomic) NSInteger timeInSeconds;
@property (nonatomic) NSTimer *timer;
@property (nonatomic) UIBackgroundTaskIdentifier backgroundTask;
@property (nonatomic) NSInteger passcodeAttempts;

@end

@implementation VideoViewController

UITapGestureRecognizer  *_recordGestureRecognizer;
UIImagePickerController *_camera;
AVAudioRecorder *_audioRecorder;
BOOL _passcodeFailed;
BOOL _isVideoFile;
BOOL _inBackground;
BOOL _mainFolder;
BOOL _datedFolder;
BOOL _videoRecording;
BOOL _videoSessionInProgress;
BOOL _audioSessionInProgress;
BOOL _showCameraSelection;
BOOL _showFlashMode;

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.backgroundTask = UIBackgroundTaskInvalid;
    self.navigationController.navigationBarHidden = YES;
    
    [self setUpCamera];
    [self prepareAudioRecorder];
    
    self.timeInSeconds = 0;
    self.passcodeAttempts = 0;
    
    [self initializeDriveService];
    [self addNotificationObservers];
}

- (void)initializeDriveService
{
    // Initialize the drive service
    self.driveService = [[GTLServiceDrive alloc] init];
    
    //Load existing credentials from the keychain if available
    self.driveService.authorizer = [GTMOAuth2ViewControllerTouch authForGoogleFromKeychainForName:kKeychainItemName
                                                                                         clientID:kClientID
                                                                                     clientSecret:kClientSecret];
}

- (void)addNotificationObservers
{
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
    
    if ([[Connectivity reachabilityForInternetConnection]currentReachabilityStatus] == NotReachable){
        [self presentConnectivityVC];
    }else {
        if (![self isAuthorized]) {
            [self.navigationController presentViewController:[self createAuthController] animated:YES completion:nil];
        }else {
            if (![[NSUserDefaults standardUserDefaults] valueForKey:UserPasscodeKey]){
                [self presentPasscodeVC];
            }else {
                [self.navigationController presentViewController:_camera animated:animated completion:nil];
            }
        }
    }
}

- (void)presentConnectivityVC
{
    ConnectivityViewController *connectivityVC = [[UIStoryboard storyboardWithName:@"Main" bundle:nil] instantiateViewControllerWithIdentifier:@"ConnectivityViewController"];
    [self.navigationController presentViewController:connectivityVC animated:YES completion:nil];
}

- (void)presentPasscodeVC
{
    [self.navigationController presentViewController:_camera animated:YES completion:^{
        SetPasscodeViewController *setPasscodeVC = [[UIStoryboard storyboardWithName:@"Main" bundle:nil] instantiateViewControllerWithIdentifier:@"SetPasscodeViewController"];
        [_camera presentViewController:setPasscodeVC animated:YES completion:nil];
    }];
}

- (void)cameraIsReady:(NSNotification *)notification
{
    // TODO(cspickert): Although it depends on the situation, it's usually better to use some kind of logging macro instead of using NSLog directly. One reason is that NSLog is extremely slow.
    NSLog(@"Camera is ready...");
    
    if (![[NSUserDefaults standardUserDefaults] boolForKey:RecordingInfoPresentedKey]) {
        
        // TODO(cspickert): Is this notification happening on a background queue? If so, you might be able to avoid the dispatch_asyncs by making sure this entire method executes on the main queue (there are various ways to do that).
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showRecordingInfoAlertView];
        });
    }
    
    if (_videoSessionInProgress) {
        
        _videoRecording = YES;
        
        [self startRecordingTimer];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            [_camera startVideoCapture];
            self.customCameraOverlayView.stopRecordingView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.5];
            self.customCameraOverlayView.stopRecordingView.alpha = 1.0;
        });
        
        NSLog(@"Video recording continued...");
        
    }

}

- (void)appDidBecomeActive
{
    NSLog(@"App did become active.");   
}

- (void)appWillResignActive
{
    if (_videoSessionInProgress) {
        
        [self stopVideoRecording];
    }
    
    NSLog(@"App will resign active.");
}

- (void)appDidEnterBackground{
    
    _inBackground = YES;
    
    if (!_audioRecorder.recording && [self isAuthorized] && _videoSessionInProgress) {
        
        AVAudioSession *audioSession = [AVAudioSession sharedInstance];
        [audioSession setActive:YES error:nil];
        
        [self startAudioRecording];
        
        NSLog(@"Audio recording: %@", (_audioRecorder.recording ? @"YES" : @"NO"));
        
        _audioSessionInProgress = YES;
    }
    
    
    UIApplication *app = [UIApplication sharedApplication];
    
    self.backgroundTask = [app beginBackgroundTaskWithName:@"MyTask" expirationHandler:^{
        // Clean up any unfinished task business by marking where you
        // stopped or ending the task outright.
        
        // TODO(cspickert): Should the audio recording session end here?

        NSLog(@"Background handler called. Not running background tasks anymore.");
        [app endBackgroundTask:self.backgroundTask];
        self.backgroundTask = UIBackgroundTaskInvalid;
    }];
}

- (void)appWillEnterForeground
{
    _inBackground = NO;
    
    [self stopAudioRecording];
    
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    [audioSession setActive:NO error:nil];
    
    _audioSessionInProgress = NO;
    
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
    
    NSString *pathToSave = [documentPath stringByAppendingPathComponent:[self audioFileName]];
    
    // File URL
    NSURL *url = [NSURL fileURLWithPath:pathToSave];
    
    //Save recording path to NSUserDefaults
    NSUserDefaults *paths = [NSUserDefaults standardUserDefaults];
    [paths setURL:url forKey:@"filePath"];
    [paths synchronize];
  
    NSError *error;
    
    // Create recorder
    _audioRecorder = [[AVAudioRecorder alloc] initWithURL:url settings:[self audioRecorderSettings] error:&error];
    _audioRecorder.delegate = self;
    _audioRecorder.meteringEnabled = YES;
    [_audioRecorder prepareToRecord];
}

- (NSString *)audioFileName
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
    
    // TODO(cspickert): Using object literals (@{}, @YES, etc.) would make this a lot more readable.
    settings = [NSDictionary dictionaryWithObjectsAndKeys:
                [NSNumber numberWithInt: kAudioFormatMPEG4AAC], AVFormatIDKey,
                [NSNumber numberWithFloat:16000.0], AVSampleRateKey,
                [NSNumber numberWithInt: 1], AVNumberOfChannelsKey,
                nil];
    
    return settings;
    
}

-(void)audioRecorderDidFinishRecording:(AVAudioRecorder *)recorder successfully:(BOOL)flag {
    
    //save audio file to google drive
    
    //Load recording path from preferences
    NSUserDefaults *paths = [NSUserDefaults standardUserDefaults];
    NSURL *audioFileUrl = [paths URLForKey:FilePathKey];
    NSString *audioFilePath = [audioFileUrl path];
    
    //Upload to google drive
    _isVideoFile = NO;
    [self uploadToGoogleDriveInDatedFolder:audioFilePath];
    
    //***(TO DO: Save on device)***
    
    //restart audioRecorder
    if (_inBackground && _audioSessionInProgress) {
        
        [self startAudioRecording];
    }
}

-(void)startAudioRecording
{
        [_audioRecorder record];
        [self startRecordingTimer];
        
        NSLog(@"Audio recording started");
}

-(void)stopAudioRecording
{
        [_audioRecorder stop];
        [self resetTimer];
        
        NSLog(@"Audio recording stopped");
}


#pragma mark - camera and customCameraOverlay set up

-(void)customCameraOverlay
{
    CameraOverlayViewController *cameraOverlayVC = [[CameraOverlayViewController alloc] init];
    self.customCameraOverlayView = (CustomCameraOverlayView *)cameraOverlayVC.view;
    
    self.customCameraOverlayView.delegate = self;
    self.customCameraOverlayView.frame = _camera.view.frame;
    
    //TODO(Justine): Move to CameraOverlayVC 
    self.customCameraOverlayView.stopRecordingView.layer.cornerRadius = 30.0;
    self.customCameraOverlayView.menuBarView.backgroundColor = [UIColor colorWithRed:211.0/255.0
                                                                               green:211.0/255.0
                                                                                blue:211.0/255.0
                                                                               alpha:0.25
                                                                ];
    
    [self.customCameraOverlayView addGestureRecognizer:[self tapTwiceRecordGesture]];
    
}

- (UITapGestureRecognizer *)tapTwiceRecordGesture
{
    UITapGestureRecognizer *gestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(beginVideoRecordingSession)];
    gestureRecognizer.numberOfTapsRequired = 2;
    
    return gestureRecognizer;
}

- (void)setUpCamera
{
    _camera = [[UIImagePickerController alloc] init];
    _camera.sourceType = UIImagePickerControllerSourceTypeCamera;
    
    _camera.mediaTypes = [[NSArray alloc] initWithObjects:(NSString *)kUTTypeMovie, nil];
    _camera.cameraCaptureMode = UIImagePickerControllerCameraCaptureModeVideo;
    
    _camera.showsCameraControls = NO;
    _camera.cameraViewTransform = CGAffineTransformIdentity;
    
    //create custom overlay and apply to camera
    [self customCameraOverlay];
    _camera.cameraOverlayView = self.customCameraOverlayView;
    
    // not all devices have two cameras or a flash so just check here
    if ( [UIImagePickerController isCameraDeviceAvailable: UIImagePickerControllerCameraDeviceRear] ) {
        
        _camera.cameraDevice = UIImagePickerControllerCameraDeviceRear;
        
        if ( [UIImagePickerController isCameraDeviceAvailable: UIImagePickerControllerCameraDeviceFront] ) {
            
            [self.customCameraOverlayView.cameraSelectionButton setImage:[UIImage imageNamed:@"camera-toggle"] forState:UIControlStateNormal];
            self.customCameraOverlayView.cameraSelectionButton.imageView.contentMode = UIViewContentModeScaleAspectFit;
            self.customCameraOverlayView.cameraSelectionButton.alpha = 1.0;
            _showCameraSelection = YES;
        }
        
    } else {
        
        // TODO(cspickert): What happens if the device has no cameras? Definitely an edge case, but something to consider.
        _camera.cameraDevice = UIImagePickerControllerCameraDeviceFront;
    
    }
    
    
    if ( [UIImagePickerController isFlashAvailableForCameraDevice:_camera.cameraDevice] ) {
        
        _camera.cameraFlashMode = UIImagePickerControllerCameraFlashModeOff;
        [self.customCameraOverlayView.flashModeButton setImage:[UIImage imageNamed:@"flash-off.png"] forState:UIControlStateNormal];
        self.customCameraOverlayView.flashModeButton.imageView.contentMode = UIViewContentModeScaleAspectFit;
        self.customCameraOverlayView.flashModeButton.alpha = 1.0;
        _showFlashMode = YES;
    
    }
    
    
    // TODO(cspickert): This is extremely low-quality video by today's standards. It might be worth checking to see if the device/internet connection can handle higher-quality video, or record at a higher quality either way and downsample prior to uploading.
    _camera.videoQuality = UIImagePickerControllerQualityType640x480;
    
    _camera.delegate = self;
    _camera.edgesForExtendedLayout = UIRectEdgeAll;
    
    
}

-(void)showCameraControls
{
    // TODO(cspickert): This initialization can be all on one line. To make this easier, you could use dispatch_block_t.
    void (^showControls)(void);
    showControls = ^(void) {
        
        self.customCameraOverlayView.menuBarView.alpha = 1.0;
        if (_showCameraSelection) self.customCameraOverlayView.cameraSelectionButton.alpha = 1.0;
        if (_showFlashMode) self.customCameraOverlayView.flashModeButton.alpha = 1.0;
        
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
        [[NSUserDefaults standardUserDefaults] setValue:timerTimeStamp forKey:StartTimeStampKey];
        
    });
    
}

-(void)fireTimer: (NSTimer *) timer
{
    NSDate *startTime = [[NSUserDefaults standardUserDefaults] valueForKey:StartTimeStampKey];
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
    // TODO(cspickert): This "controllers" array can be removed with one line: [navigationController popViewControllerAnimated:NO].
    [navigationController setViewControllers:controllers];
    
    [_camera dismissViewControllerAnimated:NO completion:^{
        
        [navigationController popToRootViewControllerAnimated:NO];
        
    }];

}

// TODO(cspickert): These notifications could be handled internally within the custom camera overlay class.
- (void)didChangeFlashMode
{
    if (_camera.cameraFlashMode == UIImagePickerControllerCameraFlashModeOff) {
        
        _camera.cameraFlashMode = UIImagePickerControllerCameraFlashModeOn;
        [self.customCameraOverlayView.flashModeButton setImage:[UIImage imageNamed:@"flash-on.png"] forState:UIControlStateNormal];
    
    } else {
        
        _camera.cameraFlashMode = UIImagePickerControllerCameraFlashModeOff;
        [self.customCameraOverlayView.flashModeButton setImage:[UIImage imageNamed:@"flash-off.png"] forState:UIControlStateNormal];
    
    }
}

- (void)didChangeCamera
{
    if (_camera.cameraDevice == UIImagePickerControllerCameraDeviceRear) {
        
        _camera.cameraDevice = UIImagePickerControllerCameraDeviceFront;
    
    } else {
        
        _camera.cameraDevice = UIImagePickerControllerCameraDeviceRear;
    }
    
    if ( ![UIImagePickerController isFlashAvailableForCameraDevice:_camera.cameraDevice] ) {
        
        [UIView animateWithDuration:0.3 animations:^(void) {
            
            self.customCameraOverlayView.flashModeButton.alpha = 0;
        }];
        
        _showFlashMode = NO;
    
    } else {
        
        [UIView animateWithDuration:0.3 animations:^(void) {
            self.customCameraOverlayView.flashModeButton.alpha = 1.0;
        }];
        
        _showFlashMode = YES;
    
    }
}


#pragma mark - UIImagePickerController camera and delegate methods

- (void)beginVideoRecordingSession
{
    // TODO(cspickert): Wouldn't it be better if you could record even when offline?
    if ([[Connectivity reachabilityForInternetConnection]currentReachabilityStatus] == NotReachable){
        
        ConnectivityViewController *connectivityVC = [[UIStoryboard storyboardWithName:@"Main" bundle:nil] instantiateViewControllerWithIdentifier:@"ConnectivityViewController"];
        [_camera presentViewController:connectivityVC animated:YES completion:nil];
        
    }else if (!_videoRecording) {
        
        if (![[NSUserDefaults standardUserDefaults] valueForKey:UserPasscodeKey]){
            
            SetPasscodeViewController *setPasscodeVC = [[UIStoryboard storyboardWithName:@"Main" bundle:nil] instantiateViewControllerWithIdentifier:@"SetPasscodeViewController"];
            [_camera presentViewController:setPasscodeVC animated:YES completion:nil];
            
        }else {
            
            _videoSessionInProgress = YES;
            
            [self startVideoRecording];
            
            NSLog(@"video recording started");

        }
        
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
        
        _videoRecording = YES;
        [_camera startVideoCapture];
        [self startRecordingTimer];
    };
    
    // Hide controls
    [UIView  animateWithDuration:0.3 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:hideControls completion:recordMovie];
    
}

- (void)stopVideoRecording
{
    if (_videoRecording) {
     
        [self resetTimer];
        
        _videoRecording = NO;
        
        [_camera stopVideoCapture];
        
        if (!_videoSessionInProgress && !_inBackground) {
            
            self.customCameraOverlayView.stopRecordingView.alpha = 0.0;
        }
        
        NSLog(@"Video recording: %@", (_videoRecording ? @"YES" : @"NO"));
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
            _isVideoFile = YES;
            [self uploadToGoogleDriveInDatedFolder:videoPath];
                        
            //save to photo album
            UISaveVideoAtPathToSavedPhotosAlbum(videoPath, self, @selector(video:didFinishSavingWithError:contextInfo:), NULL);
            
        } else {
            
            [self video:videoPath didFinishSavingWithError:nil contextInfo:NULL];
        }
    
    }
    
    if (_videoSessionInProgress && !_inBackground && _passcodeFailed) {
        
        [self didChangeCamera];
        _videoRecording = YES;
        [_camera startVideoCapture];
        [self startRecordingTimer];
        
        _passcodeFailed = NO;
        
        NSLog(@"Camera changed and recording continued...");
        
    } else if (_videoSessionInProgress && !_inBackground && !_passcodeFailed){
        
        _videoRecording = YES;
        [_camera startVideoCapture];
        [self startRecordingTimer];
        
        NSLog(@"recording continued...");
    }
}

- (void)video:(NSString *)videoPath didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo
{
   if (!_videoSessionInProgress) {
        
       [self showCameraControls];
    }
    
}

#pragma Mark - Google Drive Authorization and Uploading methods

// Helper to check if user is authorized
- (BOOL)isAuthorized
{
    
    BOOL auth = [((GTMOAuth2Authentication *)self.driveService.authorizer) canAuthorize];
    
    if (auth == YES) {
        
        //Set Bool for presenting LogInVC
        // TODO(cspickert): It's generally poor form to do things like this ("side effects") inside a getter, because it's impossible for callers to tell that this is happening, and it might result in odd behavior if the calling code gets refactored.
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

// TODO(cspickert): Generally when methods get this long, it means you're trying to do too much at once, and you should break it up into smaller methods. Unit-testing a method like this is also pretty much impossible. You may even want to consider moving this logic into its own class.
-(void)uploadToGoogleDriveInDatedFolder: (NSString *)filePath
{
    [self searchForMainBMLPFolder:^(BOOL finished) {
        
        if (finished) {
            
            if (!_mainFolder) {
                
                [self createMainBMLPfolder:^(GTLDriveParentReference *identifier) {
                    
                    [self createNewDatedFolderWithParentRef:identifier completion:^(GTLDriveParentReference *identifier) {
                        
                        if (_isVideoFile) {
                            
                            [self uploadVideo:filePath WithParentRef:identifier];
                            
                        }else {
                            
                            [self uploadAudio:filePath WithParentRef:identifier];
                        }
                        
                        
                    }];
                    
                }];
                
            }else {
                
                [self searchForDatedFolder:^(BOOL finished) {
                    
                    if (finished) {
                        
                        if (!_datedFolder) {
                            
                            [self createNewDatedFolderWithParentRef:self.parentRef completion:^(GTLDriveParentReference *identifier) {
                                
                                if (_isVideoFile) {
                                    
                                    [self uploadVideo:filePath WithParentRef:identifier];
                                    
                                }else {
                                    
                                    [self uploadAudio:filePath WithParentRef:identifier];
                                }
                                
                            }];
                            
                        } else {
                            
                            if (_isVideoFile) {
                                
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
// TODO(cspickert): It's usually best to capitalize types, and make them more descriptive ("CompletionBlock" instead of "completion").
typedef void(^completion)(BOOL);

// TODO(cspickert): All of this file manipulation and Drive integration should be in a separate (non-UIViewController) class.

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
             
                _mainFolder = folderFound;
                
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
                
                _datedFolder = folderFound;
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
            _mainFolder = YES;
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
            _datedFolder = YES;
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
    file.title = [dateFormat stringFromDate:[NSDate date]];
    file.descriptionProperty = @"Uploaded from BMLP Video Archiver";
    
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
    file.title = [dateFormat stringFromDate:[NSDate date]];
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
                      
                      
                      if (error == nil){
                          
                          NSLog(@"File ID: %@", insertedFile.identifier);
                          
                          [self.customCameraOverlayView.uploadingLabel.layer removeAllAnimations];
                          self.customCameraOverlayView.uploadingLabel.alpha = 0.0;
                          
                          [self fadeInFadeOutInfoLabel:self.customCameraOverlayView.fileSavedLabel WithMessage:@"File Saved"];
                          
                          
                      }else {
                          
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

- (void)showRecordingInfoAlertView
{
    NYAlertViewController *alertViewController = [[NYAlertViewController alloc] initWithNibName:nil bundle:nil];
    
    alertViewController.backgroundTapDismissalGestureEnabled = NO;
    alertViewController.swipeDismissalGestureEnabled = NO;
    
    alertViewController.title = NSLocalizedString(@"Start Recording", nil);
    alertViewController.message = NSLocalizedString(@"Double tap anywhere on the camera view to begin recording", nil);
    
    alertViewController.buttonCornerRadius = 20.0f;
    alertViewController.view.tintColor = self.view.tintColor;
    
    alertViewController.titleFont = [UIFont fontWithName:@"AvenirNext-Bold" size:alertViewController.titleFont.pointSize];
    alertViewController.messageFont = [UIFont fontWithName:@"AvenirNext-Regular" size:alertViewController.messageFont.pointSize];
    alertViewController.buttonTitleFont = [UIFont fontWithName:@"AvenirNext-Medium" size:alertViewController.buttonTitleFont.pointSize];
    alertViewController.cancelButtonTitleFont = [UIFont fontWithName:@"AvenirNext-Regular" size:alertViewController.cancelButtonTitleFont.pointSize];
    
    alertViewController.alertViewBackgroundColor = [UIColor blackColor];
    alertViewController.titleColor = [UIColor redColor];
    alertViewController.messageColor = [UIColor lightGrayColor];
    alertViewController.alertViewCornerRadius = 10.0f;
    
    alertViewController.buttonColor = [UIColor redColor];
    alertViewController.buttonTitleColor = [UIColor colorWithWhite:0.19f alpha:1.0f];
    
    alertViewController.cancelButtonColor = [UIColor lightGrayColor];
    alertViewController.cancelButtonTitleColor = [UIColor colorWithWhite:0.19f alpha:1.0f];
    
    [alertViewController addAction:[NYAlertAction actionWithTitle:NSLocalizedString(@"OK", nil)
                                                            style:UIAlertActionStyleCancel
                                                          handler:^(NYAlertAction *action) {
                                                              
                                                              [_camera dismissViewControllerAnimated:YES completion:^{
                                                                  [[NSUserDefaults standardUserDefaults] setBool:YES forKey:RecordingInfoPresentedKey];
                                                              }];
                                                          }]];
    
    [_camera presentViewController:alertViewController animated:YES completion:nil];
}


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
                                                            
                                                              [_camera dismissViewControllerAnimated:YES completion:^{
                                                                  
                                                                  //***TO DO: Set up Passcode here ***
                                                                  if ([[NSUserDefaults standardUserDefaults] valueForKey:UserPasscodeKey]) {
                                                                      
                                                                      [DMPasscode showPasscodeInViewController:_camera completion:^(BOOL success, NSError *error) {
                                                                          
                                                                          if (success) {
                                                                              
                                                                              [DMPasscode setupPasscodeInViewController:_camera completion:^(BOOL success, NSError *error) {
                                                                                  
                                                                              }];
                                                                          }
                                                                          
                                                                      }];
                                                                      
                                                                  }else {
                                                                      
                                                                      [DMPasscode setupPasscodeInViewController:_camera completion:^(BOOL success, NSError *error) {
                                                                          
                                                                      }];
                                                                  }
                                                                  
                                                              }];
                                                              
                                                          }]];
    
    [alertViewController addAction:[NYAlertAction actionWithTitle:NSLocalizedString(@"Switch Google Drive Account", nil)
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(NYAlertAction *action) {
                                                              
                                                              [_camera dismissViewControllerAnimated:YES completion:^{
                                                                  
                                                                  [self signOutOfGoogleDrive];
                                                              }];
                                                          }]];
    
    [alertViewController addAction:[NYAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil)
                                                            style:UIAlertActionStyleCancel
                                                          handler:^(NYAlertAction *action) {
                                                              
                                                              [_camera dismissViewControllerAnimated:YES completion:nil];
                                                          }]];
    
    [_camera presentViewController:alertViewController animated:YES completion:nil];
}


- (void)showVideoRecordingActiveAlertView
{
    NYAlertViewController *alertViewController = [[NYAlertViewController alloc] initWithNibName:nil bundle:nil];
    alertViewController.title = NSLocalizedString(@"Video Recording Active", nil);
    alertViewController.message = NSLocalizedString(@"You must enter your passcode to stop recording", nil);
    
    alertViewController.view.tintColor = self.view.tintColor;
    alertViewController.backgroundTapDismissalGestureEnabled = NO;
    alertViewController.swipeDismissalGestureEnabled = NO;
    alertViewController.transitionStyle = NYAlertViewControllerTransitionStyleFade;
    
    alertViewController.alertViewBackgroundColor = [UIColor blackColor];
    alertViewController.titleColor = [UIColor redColor];
    alertViewController.messageColor = [UIColor lightGrayColor];
    
    alertViewController.titleFont = [UIFont fontWithName:@"AvenirNext-Bold" size:alertViewController.titleFont.pointSize];
    alertViewController.messageFont = [UIFont fontWithName:@"AvenirNext-Regular" size:alertViewController.messageFont.pointSize];
    alertViewController.buttonTitleFont = [UIFont fontWithName:@"AvenirNext-Regular" size:alertViewController.buttonTitleFont.pointSize];
    alertViewController.cancelButtonTitleFont = [UIFont fontWithName:@"AvenirNext-Medium" size:alertViewController.cancelButtonTitleFont.pointSize];
    
    alertViewController.alertViewBackgroundColor = [UIColor blackColor];
    alertViewController.titleColor = [UIColor redColor];
    alertViewController.messageColor = [UIColor whiteColor];
    
    // TODO(cspickert): Moving the completion block out of the method call will make this code much more readable.
    NYAlertAction *submitAction = [NYAlertAction actionWithTitle:NSLocalizedString(@"Submit", nil)
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(NYAlertAction *action) {
                                                             
                                                             //if passcode is correct, stop video recording session
                                                             
                                                             UITextField *passwordTextField = [alertViewController.textFields firstObject];
                                                             
                                                             if ([passwordTextField.text isEqualToString:[[NSUserDefaults standardUserDefaults] valueForKey:UserPasscodeKey]]) {
                                                                 
                                                                 [_camera dismissViewControllerAnimated:NO completion:^{
                                                                     
                                                                     self.passcodeAttempts = 0;
                                                                     _videoSessionInProgress = NO;
                                                                     
                                                                     [self stopVideoRecording];
                                                                     
                                                                     NSLog(@"session ended");
                                                                     
                                                                 }];
                                                                 
                                                             }else {
                                                                 
                                                                 self.passcodeAttempts += 1;
                                                                 
                                                                 switch (self.passcodeAttempts) {
                                                                         
                                                                     case 1:
                                                                     
                                                                     {
                                                                         alertViewController.message = NSLocalizedString(@" 2 Attempts Left", nil);
                                                                         ((UITextField *)alertViewController.textFields.lastObject).text = @"";
                                                                         break;
                                                                     }
                                                                     
                                                                     case 2:
                                                                     
                                                                     {
                                                                         alertViewController.message = NSLocalizedString(@"1 Attempt Left", nil);
                                                                         ((UITextField *)alertViewController.textFields.lastObject).text = @"";
                                                                         break;
                                                                     }
                                                                     
                                                                     case 3:
                                                                     
                                                                     {
                                                                         [_camera dismissViewControllerAnimated:NO completion:^{
                                                                             
                                                                             self.passcodeAttempts = 0;
                                                                             _passcodeFailed = YES;
                                                                             
                                                                             [self stopVideoRecording];
                                                                             
                                                                         }];
                                                                         
                                                                         break;
                                                                     }
                                                                     
                                                                     default:
                                                                     
                                                                     {
                                                                         break;
                                                                     }
                                                                 }
                                                             }
                     
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
                                                              [_camera dismissViewControllerAnimated:NO completion:^{
                                                                  self.passcodeAttempts = 0;
                                                              }];
                                                          }]];
    
    
    [alertViewController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = NSLocalizedString(@"Passcode", nil);
        textField.textAlignment = NSTextAlignmentCenter;
        textField.font = [UIFont fontWithName:@"AvenirNext-Regular" size:16.0f];
        textField.secureTextEntry = YES;
        textField.keyboardType = UIKeyboardTypeNumberPad;
    }];

    
    [_camera presentViewController:alertViewController animated:YES completion:nil];
}

@end
