//
//  VideoViewController.m
//  BMLPVideoArchiver
//
//  Created by Justine Kay on 10/26/15.
//  Copyright © 2015 Justine Kay. All rights reserved.

#import <MobileCoreServices/MobileCoreServices.h>
#import "VideoViewController.h"
#import "LogInViewController.h"
#import "GTMOAuth2ViewControllerTouch.h"
#import "GTLDrive.h"

static NSString *const kKeychainItemName = @"BMLP Video Archiver";
static NSString *const kClientID = @"749579524688-b1oaiu8cc4obq06aal4org55qie5lho2.apps.googleusercontent.com";
static NSString *const kClientSecret = @"0U67OQ3UNhX72tmba7ZhMSYK";

@interface VideoViewController ()

- (void)setUpCamera;
- (void)startVideoRecording;
- (void)stopVideoRecording;

- (void)video:(NSString *)videoPath didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo;

@property (nonatomic, retain) GTLServiceDrive *driveService;
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
    //hasEnteredBackground = NO;
    
    mainFolderCreated = [[NSUserDefaults standardUserDefaults] boolForKey:@"mainfolderCreated"];
    
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
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if (![self isAuthorized]) {
        
        // Not yet authorized, request authorization and push the login UI onto the navigation stack.
        UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:[self createAuthController]];
        navigationController.navigationBarHidden = YES;
        [self presentViewController:navigationController animated:YES completion:nil];

        //[self presentViewController:[self createAuthController] animated:YES completion:nil];
        
    }else {
        
        [self presentViewController:camera animated:animated completion:nil];
    }
}

- (void)appDidBecomeActive
{
    NSLog(@"App did become active.");
}

- (void)appWillResignActive
{
    [self stopVideoRecording];
    NSLog(@"App will resign active.");
}

- (void)appDidEnterBackground{
    
    inBackground = YES;
    //hasEnteredBackground = YES;
    
    if (!audioRecorder.recording && [self isAuthorized]) {
        
        AVAudioSession *audioSession = [AVAudioSession sharedInstance];
        [audioSession setActive:YES error:nil];
        
        [self startAudioRecording];
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
    
    sessionInProgress = NO;
    self.customCameraOverlayView.stopRecordingView.alpha = 0.0;
    
    NSLog(@"audio session ended");
    
    if (self.backgroundTask != UIBackgroundTaskInvalid)
    {
        [[UIApplication sharedApplication] endBackgroundTask:self.backgroundTask];
        self.backgroundTask = UIBackgroundTaskInvalid;
    }
    
    [self showCameraControls];
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
    
    //save audio file to google drive (and on device?)
    
    //Load recording path from preferences
    NSUserDefaults *paths = [NSUserDefaults standardUserDefaults];
    NSURL *audioFileUrl = [paths URLForKey:@"filePath"];
    NSString *audiofilePath = [audioFileUrl path];
    
    //upload to google drive
    [self uploadAudio:audiofilePath];
    
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


#pragma mark - camera and customCameraoOverlay set up

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
    NSTimer *timer = [NSTimer timerWithTimeInterval:1.0 target:self selector:@selector(fireTimer:) userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
    NSDate *timerTimeStamp = [NSDate date];
    [[NSUserDefaults standardUserDefaults] setValue:timerTimeStamp forKey:@"lastTimeStamp"];
    self.timer = timer;
    
}

-(void)fireTimer: (NSTimer *) timer
{
    NSDate *lastTime = [[NSUserDefaults standardUserDefaults] valueForKey:@"lastTimeStamp"];
    NSTimeInterval stopTimeInterval = 30.0;
    NSTimeInterval currentTimeInterval = [[NSDate date] timeIntervalSinceDate:lastTime];
    
    //For debugging only
    self.timeInSeconds += 1;
    
    if (currentTimeInterval >= stopTimeInterval) {
    
        [self stopVideoRecording];
        [self stopAudioRecording];
        
    }
    
    //Not being checked when re-entering foreground
//    if (!inBackground && hasEnteredBackground) {
//        
//        [self resetTimer];
//        hasEnteredBackground = NO;
//    }
    
    NSLog(@"Timer Fired, time in seconds: %ld", (long)self.timeInSeconds);
}

-(void)resetTimer
{
    if (self.timer){
        
        [self.timer invalidate];
        
        self.timeInSeconds = 0;
        
        NSLog(@"Timer reset");
    }
}


#pragma Mark - CustomCameraOverlayDelegate methods

-(void)didStopRecordingVideo
{
    sessionInProgress = NO;
    
    [self stopVideoRecording];
    
    NSLog(@"session ended");
}

-(void)didSignOut
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
        
        sessionInProgress = YES;
        
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
        self.customCameraOverlayView.stopRecordingView.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.25];
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
        
        if (!sessionInProgress) {
            
            self.customCameraOverlayView.stopRecordingView.alpha = 0.0;
        }
        
        NSLog(@"Video recording: %hhd", videoRecording);
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
            __block GTLDriveFile *folder;
            __block NSString *parentId;
            
            [self searchForMainBMLPFolder:^(BOOL finished) {
                
                if (finished) {
                    
                    if (!mainFolderCreated) {
                        
                        folder = [self createMainBMLPfolder];
                    }
                    
                    //**************
                    //To be completed when folder.identifier can be found
                    //check date of session folder
                    //create new if date is not equal
                    //assign parentId to (session)folder.title
                    //***************
                    
                    
                    //Trying to get the folder.identifier ...
                    //*************
                    GTLQueryDrive *queryFilesList = [GTLQueryDrive queryForChildrenListWithFolderId:@"root"];
                    queryFilesList.q = @"mimeType='application/vnd.google-apps.folder' and 'root' in parents and trashed=false";
                    [self.driveService executeQuery:queryFilesList completionHandler:^(GTLServiceTicket *ticket, GTLDriveFile *file, NSError *error) {
                        
                        NSLog(@"%@", file);
                        
                        parentId = folder.identifier;//Reading nil although folder is not nil...
                        
                        [self uploadVideo:videoPath WithParentId:parentId];
                    }];
                    
//                    GTLDriveParentReference *parentRef = [GTLDriveParentReference object];
//                    parentRef.identifier = folderIdentifier; // identifier property of the folder
//                    driveFile.parents = @[ parentRef ];
                    //**************
                    
                    
                    
                }
            }];
            
            //save to photo album
            UISaveVideoAtPathToSavedPhotosAlbum(videoPath, self, @selector(video:didFinishSavingWithError:contextInfo:), NULL);
            
        } else {
            
            [self video:videoPath didFinishSavingWithError:nil contextInfo:NULL];
        }
    
    }
    
    //CREATE separate videoSessionInProgress and audioSessionInProgress
    if (sessionInProgress && !inBackground) {
        
        videoRecording = YES;
        [camera startVideoCapture];
        [self startRecordingTimer];
        
        NSLog(@"recording continued...");
    }
}

- (void)video:(NSString *)videoPath didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo
{
   if (!sessionInProgress) {
        
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

//Check if a main BMLP folder has been created
typedef void(^myCompletion)(BOOL);
- (void)searchForMainBMLPFolder:(myCompletion) compblock
{
    NSString *parentId = @"root";
    
    GTLQueryDrive *query = [GTLQueryDrive queryForFilesList];
    query.q = [NSString stringWithFormat:@"'%@' in parents", parentId];
    [self.driveService executeQuery:query completionHandler:^(GTLServiceTicket *ticket,
                                                              GTLDriveFileList *fileList,
                                                              NSError *error) {
        if (error == nil) {
            NSLog(@"Have results");
            
            // Iterate over fileList.items array
            
            [[NSUserDefaults standardUserDefaults] setBool:[self mainFolderFoundInFileList:fileList.items] forKey:@"mainFolderCreated"];
            
        } else {
            
            NSLog(@"An error occurred: %@", error);
        }
        
        compblock(YES);
    }];
}


- (BOOL)mainFolderFoundInFileList: (NSArray *)items
{
    BOOL found = NO;
    NSString *mainFolder = @"BMLP Video Archiver Files";
    
    for (GTLDriveFile *item in items) {
        //NSLog(@"%@", item.title);
        if ([item.title isEqualToString:mainFolder]) {
            
            found = YES;
        }
    }

    return found;
}

//Create main folder in Google Drive for BMLP files
- (GTLDriveFile *)createMainBMLPfolder
{
    GTLDriveFile *folder = [GTLDriveFile object];
    folder.title = @"BMLP Video Archiver Files";
    folder.mimeType = @"application/vnd.google-apps.folder";
    
    GTLQueryDrive *query = [GTLQueryDrive queryForFilesInsertWithObject:folder uploadParameters:nil];
    [self.driveService executeQuery:query completionHandler:^(GTLServiceTicket *ticket,
                                                  GTLDriveFile *updatedFile,
                                                  NSError *error) {
        if (error == nil) {
            NSLog(@"Created main BMLP files folder");
            [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"mainFolderCreated"];
            
        } else {
            NSLog(@"An error occurred: %@", error);
        }
    }];
    
    return folder;
}

//Create a new folder for each session
- (GTLDriveFile *)createNewSessionFolder
{
    NSString *parentId = @"BMLP Video Archiver Files";
    
    NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
    [dateFormat setDateFormat:@"BMLP Video Archiver Session Folder ('EEEE MMMM d, YYYY h:mm a, zzz')"];
    
    GTLDriveFile *folder = [GTLDriveFile object];
    folder.title = [dateFormat stringFromDate:[NSDate date]];
    folder.mimeType = @"application/vnd.google-apps.folder";
    folder.parents = @[parentId];
    
    GTLQueryDrive *query = [GTLQueryDrive queryForFilesInsertWithObject:folder uploadParameters:nil];
    [self.driveService executeQuery:query completionHandler:^(GTLServiceTicket *ticket,
                                                  GTLDriveFile *updatedFile,
                                                  NSError *error) {
        if (error == nil) {
            NSLog(@"Created new session folder");
        } else {
            NSLog(@"An error occurred: %@", error);
        }
    }];
    
    return folder;
}

// Upload audio to Google Drive
- (void)uploadAudio:(NSString *)audioURLPath
{
    NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
    [dateFormat setDateFormat:@"BMLP Video Archiver Audio File ('EEEE MMMM d, YYYY h:mm a, zzz')"];
    
    GTLDriveFile *file = [GTLDriveFile object];
    file.title = [dateFormat stringFromDate:[NSDate date]];
    file.descriptionProperty = @"Uploaded from BMLP Video Archiver";
    //file.mimeType = @"audio/mp4";
    
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
- (void)uploadVideo:(NSString *)videoURLPath WithParentId: (NSString *)parentId
{
    NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
    [dateFormat setDateFormat:@"BMLP Video Archiver Video File ('EEEE MMMM d, YYYY h:mm a, zzz')"];
    
    GTLDriveFile *file = [GTLDriveFile object];
    file.title = [dateFormat stringFromDate:[NSDate date]];
    file.descriptionProperty = @"Uploaded from BMLP Video Archiver";
    file.mimeType = @"video/quicktime";
    file.parents = @[parentId];
    
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


@end
