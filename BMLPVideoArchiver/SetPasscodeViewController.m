//
//  SetPasscodeViewController.m
//  BMLPVideoArchiver
//
//  Created by Justine Kay on 4/16/16.
//  Copyright © 2016 Justine Kay. All rights reserved.
//

#import "SetPasscodeViewController.h"
#import <DMPasscode/DMPasscode.h>

@interface SetPasscodeViewController ()
@property (weak, nonatomic) IBOutlet UIButton *okButton;

@end

@implementation SetPasscodeViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.okButton.layer.borderWidth = 1.5;
    self.okButton.layer.borderColor = [UIColor redColor].CGColor;
    self.okButton.layer.cornerRadius = 10.0;
    
}
- (IBAction)okButtonTapped:(UIButton *)sender {
    
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"setPasscodeAlertPresented"];
    [DMPasscode setupPasscodeInViewController:self completion:^(BOOL success, NSError *error) {
        [self dismissViewControllerAnimated:YES completion:nil];
    }];
    
}

@end
