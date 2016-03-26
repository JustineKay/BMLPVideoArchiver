//
//  InterfaceOrientationNavigationController.m
//  BMLPVideoArchiver
//
//  Created by Justine Gartner on 3/25/16.
//  Copyright © 2016 Justine Kay. All rights reserved.
//

#import "InterfaceOrientationNavigationController.h"

@interface InterfaceOrientationNavigationController ()

@end

@implementation InterfaceOrientationNavigationController

- (BOOL)shouldAutorotate
{
    //returns true if want to allow orientation change
    return [self.topViewController shouldAutorotate];
}
- (NSUInteger)supportedInterfaceOrientations
{
    return [self.topViewController supportedInterfaceOrientations];
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation
{
    return [self.topViewController preferredInterfaceOrientationForPresentation];
}

@end
