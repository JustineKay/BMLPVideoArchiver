//
//  DMPasscodeConfig.m
//  Pods
//
//  Created by Dylan Marriott on 06.12.14.
//
//

#import "DMPasscodeConfig.h"

@implementation DMPasscodeConfig

- (instancetype)init {
    if (self = [super init]) {
        self.animationsEnabled = YES;
        self.backgroundColor = [UIColor blackColor];
        self.navigationBarBackgroundColor = [UIColor blackColor];
        self.navigationBarForegroundColor = [UIColor blackColor];
        self.statusBarStyle = UIStatusBarStyleDefault;
        self.fieldColor = [UIColor lightGrayColor];
        self.emptyFieldColor = [UIColor lightGrayColor];
        self.errorBackgroundColor = [UIColor redColor];
        self.errorForegroundColor = [UIColor whiteColor];
        self.descriptionColor = [UIColor lightGrayColor];
        self.inputKeyboardAppearance = UIKeyboardAppearanceDefault;
        self.errorFont = [UIFont fontWithName:@"AvenirNext-Regular" size:14.0f];
        self.instructionsFont = [UIFont fontWithName:@"AvenirNext-Regular" size:16.0f];
        self.navigationBarTitle = @"";
        self.navigationBarFont = [UIFont fontWithName:@"AvenirNext-Regular" size:16.0f];
        self.navigationBarTitleColor = [UIColor darkTextColor];
    }
    return self;
}

@end
