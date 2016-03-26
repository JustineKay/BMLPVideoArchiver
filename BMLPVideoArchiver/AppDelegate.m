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
#import "InterfaceOrientationNavigationController.h"
#import "LandscapeImagePickerController.h"

@interface AppDelegate ()

@property (nonatomic, strong) IBOutlet UINavigationController *navigationController;

@end

@implementation AppDelegate

- (UIInterfaceOrientationMask)application:(UIApplication *)application supportedInterfaceOrientationsForWindow:(UIWindow *)window {
//    if (([window.rootViewController.presentedViewController isKindOfClass:[LandscapeImagePickerController class]])) {
//        return UIInterfaceOrientationMaskLandscape;
//    }
    
    if (self.isCameraPresented){
        
        NSLog(@"isPresented %d", self.isCameraPresented);
        return UIInterfaceOrientationMaskLandscape;
    }
    
    return UIInterfaceOrientationMaskAll;
}
//-(UIInterfaceOrientationMask)application:(UIApplication *)application supportedInterfaceOrientationsForWindow:(UIWindow *)window
//{
//    
//    NSLog(@"isPresented %d", self.isCameraPresented);
//    
//    return self.isCameraPresented?UIInterfaceOrientationMaskAll: UIInterfaceOrientationMaskLandscapeLeft;
//}


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    self.isCameraPresented = NO;
    
    InterfaceOrientationNavigationController *navigationController = (InterfaceOrientationNavigationController *) self.window.rootViewController;
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    
    
    if (![[NSUserDefaults standardUserDefaults] boolForKey:SignedInKey]) {
        
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
