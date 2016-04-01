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

static NSString *const kKeychainItemName = @"BMLP Video Archiver";
static NSString *const kClientID = @"749579524688-b1oaiu8cc4obq06aal4org55qie5lho2.apps.googleusercontent.com";
static NSString *const kClientSecret = @"0U67OQ3UNhX72tmba7ZhMSYK";

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
    BOOL auth = [((GTMOAuth2Authentication *)self.driveService.authorizer) canAuthorize];
    
    //Initialize a navController as the rootVC
    UINavigationController *navigationController = (UINavigationController *) self.window.rootViewController;
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    
    
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"HasLaunchedOnce"] && auth) {
        
        //If this is the first time the user has opened the app after installing
        //yet they are still authorized from a previous sign in through the app
        //sign them out & push the logInVC
    
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"HasLaunchedOnce"];
        
        [GTMOAuth2ViewControllerTouch removeAuthFromKeychainForName:kKeychainItemName];
        
        [navigationController pushViewController:[storyboard instantiateViewControllerWithIdentifier:@"LogInViewController"] animated:NO];
        
    }else if (!auth) {
        
        [navigationController pushViewController:[storyboard instantiateViewControllerWithIdentifier:@"LogInViewController"] animated:NO];
        
    }else {
        
        UIViewController *logInViewController = [storyboard instantiateViewControllerWithIdentifier:@"LogInViewController"];
        [navigationController addChildViewController:logInViewController];
        [navigationController pushViewController:[storyboard instantiateViewControllerWithIdentifier:@"VideoViewController"] animated:NO];
        
    }
    
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
