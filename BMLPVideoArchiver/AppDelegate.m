//
//  AppDelegate.m
//  BMLPVideoArchiver
//
//  Created by Justine Kay on 10/26/15.
//  Copyright © 2015 Justine Kay. All rights reserved.
//

#import "AppDelegate.h"
#import "VideoViewController.h"
#import "LogInViewController.h"
#import "GTLDrive.h"
#import "GTMOAuth2ViewControllerTouch.h"
#import "BMLPConstants.h"

@interface AppDelegate ()

@property (nonatomic) GTLServiceDrive *driveService;

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    // Initialize the drive service & load existing credentials from the keychain if available
    self.driveService = [[GTLServiceDrive alloc] init];
    self.driveService.authorizer = [GTMOAuth2ViewControllerTouch authForGoogleFromKeychainForName:kKeychainItemName
                                                                                         clientID:kClientID
                                                                                     clientSecret:kClientSecret];
    //Check to see if user is already authorized
    BOOL auth = [(self.driveService.authorizer) canAuthorize];
    
    //Initialize a navController as the rootVC
    UINavigationController *navigationController = (UINavigationController *) self.window.rootViewController;
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    
    if (![[NSUserDefaults standardUserDefaults] boolForKey:HasLaunchedKey] && auth) {
        
        //If this is the first time the user has opened the app after installing
        //yet they are still authorized from a previous sign in through the app
        //sign them out & push the logInVC
    
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:HasLaunchedKey];
        
        [GTMOAuth2ViewControllerTouch removeAuthFromKeychainForName:kKeychainItemName];
        
        [navigationController pushViewController:[storyboard instantiateViewControllerWithIdentifier:@"LogInViewController"] animated:NO];
        
    }else if (!auth) {
        
        [navigationController pushViewController:[storyboard instantiateViewControllerWithIdentifier:@"LogInViewController"] animated:NO];
        
    }else {
        
        UIViewController *logInViewController = [storyboard instantiateViewControllerWithIdentifier:@"LogInViewController"];
        // TODO(cspickert): It'd be better to present the login view controller modally instead of adding it as a child of the navigation controller (the nav controller should manage its own child controllers).
        [navigationController addChildViewController:logInViewController];
        [navigationController pushViewController:[storyboard instantiateViewControllerWithIdentifier:@"VideoViewController"] animated:NO];
        
    }
    
    return YES;
}

@end
