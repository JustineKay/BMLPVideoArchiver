//
//  ConnectivityViewController.m
//  BMLPVideoArchiver
//
//  Created by Justine Kay on 4/10/16.
//  Copyright © 2016 Justine Kay. All rights reserved.
//

#import "ConnectivityViewController.h"

@interface ConnectivityViewController ()
@property (weak, nonatomic) IBOutlet UIButton *okButton;

@end

@implementation ConnectivityViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.navigationController.navigationBarHidden = YES;
    
    self.okButton.layer.borderWidth = 1.5;
    self.okButton.layer.borderColor = [UIColor redColor].CGColor;
    self.okButton.layer.cornerRadius = 10.0;
}

- (IBAction)okButtonTapped:(UIButton *)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}
@end
