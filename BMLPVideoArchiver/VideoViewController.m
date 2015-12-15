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


static NSString *const kKeychainItemName = @"BMLP Video Archiver";
static NSString *const kClientID = @"749579524688-b1oaiu8cc4obq06aal4org55qie5lho2.apps.googleusercontent.com";
static NSString *const kClientSecret = @"0U67OQ3UNhX72tmba7ZhMSYK";

@interface VideoViewController ()
{
    BOOL isAuthorized;
}

@property (nonatomic) LLSimpleCamera *camera;


@end

@implementation VideoViewController

@synthesize service = _service;
@synthesize output = _output;

// When the view loads, create necessary subviews, and initialize the Drive API service.
- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Create a UITextView to display output.
    self.output = [[UITextView alloc] initWithFrame:self.view.bounds];
    self.output.editable = false;
    self.output.contentInset = UIEdgeInsetsMake(20.0, 0.0, 20.0, 0.0);
    self.output.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:self.output];
    
    // Initialize the Drive API service & load existing credentials from the keychain if available.
    self.service = [[GTLServiceDrive alloc] init];
    self.service.authorizer =
    [GTMOAuth2ViewControllerTouch authForGoogleFromKeychainForName:kKeychainItemName
                                                          clientID:kClientID
                                                      clientSecret:kClientSecret];
}

// When the view appears, ensure that the Drive API service is authorized, and perform API calls.
- (void)viewDidAppear:(BOOL)animated {
    if (!self.service.authorizer.canAuthorize) {
        // Not yet authorized, request authorization by pushing the login UI onto the UI stack.
        [self presentViewController:[self createAuthController] animated:YES completion:nil];
        
    } else {
        [self fetchFiles];
    }
}

// Construct a query to get names and IDs of 10 files using the Google Drive API.
- (void)fetchFiles {
    self.output.text = @"Getting files...";
    GTLQueryDrive *query =
    [GTLQueryDrive queryForFilesList];
    query.maxResults = 10;
    [self.service executeQuery:query
                      delegate:self
             didFinishSelector:@selector(displayResultWithTicket:finishedWithObject:error:)];
}

// Process the response and display output.
- (void)displayResultWithTicket:(GTLServiceTicket *)ticket
             finishedWithObject:(GTLDriveFileList *)files
                          error:(NSError *)error {
    if (error == nil) {
        NSMutableString *filesString = [[NSMutableString alloc] init];
        if (files.items.count > 0) {
            [filesString appendString:@"Files:\n"];
            for (GTLDriveFile *file in files) {
                [filesString appendFormat:@"%@ (%@)\n", file.title, file.identifier];
            }
        } else {
            [filesString appendString:@"No files found."];
        }
        self.output.text = filesString;
    } else {
        [self showAlert:@"Error" message:error.localizedDescription];
    }
}


// Creates the auth controller for authorizing access to Drive API.
- (GTMOAuth2ViewControllerTouch *)createAuthController {
    GTMOAuth2ViewControllerTouch *authController;
    NSArray *scopes = [NSArray arrayWithObjects:kGTLAuthScopeDriveMetadataReadonly, nil];
    authController = [[GTMOAuth2ViewControllerTouch alloc]
                      initWithScope:[scopes componentsJoinedByString:@" "]
                      clientID:kClientID
                      clientSecret:kClientSecret
                      keychainItemName:kKeychainItemName
                      delegate:self
                      finishedSelector:@selector(viewController:finishedWithAuth:error:)];
    return authController;
}

// Handle completion of the authorization process, and update the Drive API
// with the new credentials.
- (void)viewController:(GTMOAuth2ViewControllerTouch *)viewController
      finishedWithAuth:(GTMOAuth2Authentication *)authResult
                 error:(NSError *)error {
    if (error != nil) {
        [self showAlert:@"Authentication Error" message:error.localizedDescription];
        self.service.authorizer = nil;
    }
    else {
        self.service.authorizer = authResult;
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

// Helper for showing an alert
- (void)showAlert:(NSString *)title message:(NSString *)message {
    UIAlertView *alert;
    alert = [[UIAlertView alloc] initWithTitle:title
                                       message:message
                                      delegate:nil
                             cancelButtonTitle:@"OK"
                             otherButtonTitles:nil];
    [alert show];
}

@end
