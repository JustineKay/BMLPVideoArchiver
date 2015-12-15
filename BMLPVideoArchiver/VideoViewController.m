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

@interface VideoViewController ()<UINavigationControllerDelegate, UIImagePickerControllerDelegate>

{
    BOOL isAuthorized;
}

@property (nonatomic) LLSimpleCamera *camera;
@property (nonatomic, retain) GTLServiceDrive *driveService;

@end

@implementation VideoViewController

@synthesize driveService;

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Initialize the drive service & load existing credentials from the keychain if available
    self.driveService = [[GTLServiceDrive alloc] init];
    self.driveService.authorizer = [GTMOAuth2ViewControllerTouch authForGoogleFromKeychainForName:kKeychainItemName
                                                                                         clientID:kClientID
                                                                                     clientSecret:kClientSecret];
}

- (void)viewDidAppear:(BOOL)animated
{
    // Always display the camera UI.
    [self showCamera];
}

- (void)showCamera
{
    UIImagePickerController *cameraUI = [[UIImagePickerController alloc] init];
    if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera])
    {
        cameraUI.sourceType = UIImagePickerControllerSourceTypeCamera;
    }
    else
    {
        // In case we're running the iPhone simulator, fall back on the photo library instead.
        cameraUI.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
        {
            [self showAlert:@"Error" message:@"Sorry, iPad Simulator not supported!"];
            return;
        }
    };
    cameraUI.mediaTypes = [[NSArray alloc] initWithObjects:(NSString *)kUTTypeMovie, nil];
    cameraUI.allowsEditing = YES;
    cameraUI.delegate = self;
    [self presentViewController:cameraUI animated:YES completion:nil];
    
    if (![self isAuthorized])
    {
        // Not yet authorized, request authorization and push the login UI onto the navigation stack.
        [cameraUI pushViewController:[self createAuthController] animated:YES];
    }
}

// Handle selection of an image
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
//    UIImage *image = [info valueForKey:UIImagePickerControllerOriginalImage];
//    [self dismissViewControllerAnimated:YES completion:nil];
    
    NSString *mediaType = [info objectForKey: UIImagePickerControllerMediaType];
    
    if (CFStringCompare ((__bridge CFStringRef) mediaType, kUTTypeMovie, 0) == kCFCompareEqualTo) {
        NSURL *videoUrl=(NSURL*)[info objectForKey:UIImagePickerControllerMediaURL];
        NSString *moviePath = [videoUrl path];
        
        if (UIVideoAtPathIsCompatibleWithSavedPhotosAlbum (moviePath)) {
            [self uploadVideo:moviePath];
        }
    }
    
    [self dismissViewControllerAnimated:YES completion:nil];
    
//    // 1 - Get video
//    NSString *videoURL = [info objectForKey: UIImagePickerControllerMediaURL];
//    
//    // 2 - Dismiss image picker
//    [self dismissViewControllerAnimated:NO completion:nil];
//    
//    // Handle a movie capture
//    if (CFStringCompare ((__bridge_retained CFStringRef)videoURL, kUTTypeMovie, 0) == kCFCompareEqualTo) {
//        
//        // 3 - Play the video
//        //MPMoviePlayerViewController *theMovie = [[MPMoviePlayerViewController alloc]
//                                                 //initWithContentURL:[info objectForKey:UIImagePickerControllerMediaURL]];
//    [self uploadVideo:videoURL];
//    }
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

// Uploads a photo to Google Drive
- (void)uploadVideo:(NSString *)videoURLPath
{
    NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
    [dateFormat setDateFormat:@"'Quickstart Uploaded File ('EEEE MMMM d, YYYY h:mm a, zzz')"];
    
    GTLDriveFile *file = [GTLDriveFile object];
    file.title = [dateFormat stringFromDate:[NSDate date]];
    file.descriptionProperty = @"Uploaded from the Google Drive iOS Quickstart";
    file.mimeType = @"video/quicktime";
    
    //NSString *filePath = [[NSBundle mainBundle] pathForResource:@"Test" ofType:@"Mov"];
    
    NSError *error = nil;
    
    NSData *data = [NSData dataWithContentsOfFile:videoURLPath options:NSDataReadingMappedIfSafe error:&error];
    //NSData *data = UIImagePNGRepresentation((UIImage *)image);
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

//@synthesize service = _service;
//@synthesize output = _output;
//
//// When the view loads, create necessary subviews, and initialize the Drive API service.
//- (void)viewDidLoad {
//    [super viewDidLoad];
//    
//    // Create a UITextView to display output.
//    self.output = [[UITextView alloc] initWithFrame:self.view.bounds];
//    self.output.editable = false;
//    self.output.contentInset = UIEdgeInsetsMake(20.0, 0.0, 20.0, 0.0);
//    self.output.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
//    [self.view addSubview:self.output];
//    
//    // Initialize the Drive API service & load existing credentials from the keychain if available.
//    self.service = [[GTLServiceDrive alloc] init];
//    self.service.authorizer =
//    [GTMOAuth2ViewControllerTouch authForGoogleFromKeychainForName:kKeychainItemName
//                                                          clientID:kClientID
//                                                      clientSecret:kClientSecret];
//}
//
//// When the view appears, ensure that the Drive API service is authorized, and perform API calls.
//- (void)viewDidAppear:(BOOL)animated {
//    if (!self.service.authorizer.canAuthorize) {
//        // Not yet authorized, request authorization by pushing the login UI onto the UI stack.
//        [self presentViewController:[self createAuthController] animated:YES completion:nil];
//        
//    } else {
//        [self fetchFiles];
//    }
//}
//
//// Construct a query to get names and IDs of 10 files using the Google Drive API.
//- (void)fetchFiles {
//    self.output.text = @"Getting files...";
//    GTLQueryDrive *query =
//    [GTLQueryDrive queryForFilesList];
//    query.maxResults = 10;
//    [self.service executeQuery:query
//                      delegate:self
//             didFinishSelector:@selector(displayResultWithTicket:finishedWithObject:error:)];
//}
//
//// Process the response and display output.
//- (void)displayResultWithTicket:(GTLServiceTicket *)ticket
//             finishedWithObject:(GTLDriveFileList *)files
//                          error:(NSError *)error {
//    if (error == nil) {
//        NSMutableString *filesString = [[NSMutableString alloc] init];
//        if (files.items.count > 0) {
//            [filesString appendString:@"Files:\n"];
//            for (GTLDriveFile *file in files) {
//                [filesString appendFormat:@"%@ (%@)\n", file.title, file.identifier];
//            }
//        } else {
//            [filesString appendString:@"No files found."];
//        }
//        self.output.text = filesString;
//    } else {
//        [self showAlert:@"Error" message:error.localizedDescription];
//    }
//}
//
//
//// Creates the auth controller for authorizing access to Drive API.
//- (GTMOAuth2ViewControllerTouch *)createAuthController {
//    GTMOAuth2ViewControllerTouch *authController;
//    NSArray *scopes = [NSArray arrayWithObjects:kGTLAuthScopeDriveMetadataReadonly, nil];
//    authController = [[GTMOAuth2ViewControllerTouch alloc]
//                      initWithScope:[scopes componentsJoinedByString:@" "]
//                      clientID:kClientID
//                      clientSecret:kClientSecret
//                      keychainItemName:kKeychainItemName
//                      delegate:self
//                      finishedSelector:@selector(viewController:finishedWithAuth:error:)];
//    return authController;
//}
//
//// Handle completion of the authorization process, and update the Drive API
//// with the new credentials.
//- (void)viewController:(GTMOAuth2ViewControllerTouch *)viewController
//      finishedWithAuth:(GTMOAuth2Authentication *)authResult
//                 error:(NSError *)error {
//    if (error != nil) {
//        [self showAlert:@"Authentication Error" message:error.localizedDescription];
//        self.service.authorizer = nil;
//    }
//    else {
//        self.service.authorizer = authResult;
//        [self dismissViewControllerAnimated:YES completion:nil];
//    }
//}
//
//// Helper for showing an alert
//- (void)showAlert:(NSString *)title message:(NSString *)message {
//    UIAlertView *alert;
//    alert = [[UIAlertView alloc] initWithTitle:title
//                                       message:message
//                                      delegate:nil
//                             cancelButtonTitle:@"OK"
//                             otherButtonTitles:nil];
//    [alert show];
//}

@end
