//
//  LogInViewController.m
//  BMLPVideoArchiver
//
//  Created by Justine Kay on 1/2/16.
//  Copyright © 2016 Justine Kay. All rights reserved.
//

#import "LogInViewController.h"
#import "VideoViewController.h"
#import "Connectivity.h"
#import "ConnectivityViewController.h"

@interface LogInViewController ()
@property (weak, nonatomic) IBOutlet UIButton *logInButton;
@property (weak, nonatomic) IBOutlet UILabel *infoLabel;

@end

@implementation LogInViewController

-(void)viewDidLoad
{
    [super viewDidLoad];
    
    self.navigationController.navigationBarHidden = YES;

    self.logInButton.layer.borderWidth = 1.5;
    self.logInButton.layer.borderColor = [UIColor redColor].CGColor;
    self.logInButton.layer.cornerRadius = 10.0;
    
    self.logInButton.titleLabel.textColor = [UIColor redColor];
    
    self.infoLabel.text = @"In order to use\nBMLP Video Archiver\nyou must sign in to your\nGoogle Drive account";
    
}

-(void)viewWillAppear:(BOOL)animated
{
    if ([[Connectivity reachabilityForInternetConnection]currentReachabilityStatus] == NotReachable){
        
        ConnectivityViewController *connectivityVC = [[UIStoryboard storyboardWithName:@"Main" bundle:nil] instantiateViewControllerWithIdentifier:@"ConnectivityViewController"];
        
        [self presentViewController:connectivityVC animated:YES completion:nil];
        
    }
}

- (IBAction)logInButtonTapped:(UIButton *)sender
{
    
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
  
    [self.navigationController pushViewController:[storyboard instantiateViewControllerWithIdentifier:@"VideoViewController"]animated:NO];


}


@end
