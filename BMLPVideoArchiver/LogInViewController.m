//
//  LogInViewController.m
//  BMLPVideoArchiver
//
//  Created by Justine Kay on 1/2/16.
//  Copyright © 2016 Justine Kay. All rights reserved.
//

#import "LogInViewController.h"
#import "VideoViewController.h"

@interface LogInViewController ()
@property (weak, nonatomic) IBOutlet UIButton *logInButton;

@end

@implementation LogInViewController

-(BOOL)shouldAutorotate
{
    return YES;
}

-(UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    
    return UIInterfaceOrientationMaskPortrait;
}

-(UIInterfaceOrientation)preferredInterfaceOrientationForPresentation
{
    
    return UIInterfaceOrientationPortrait;
}


-(void)viewDidLoad
{
    [super viewDidLoad];
    
    self.navigationController.navigationBarHidden = YES;

    self.logInButton.layer.borderWidth = 1.5;
    self.logInButton.layer.borderColor = [UIColor redColor].CGColor;
    self.logInButton.layer.cornerRadius = 10.0;
    
    self.logInButton.titleLabel.textColor = [UIColor redColor];
    
}

- (IBAction)logInButtonTapped:(UIButton *)sender
{
    
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
  
    [self.navigationController pushViewController:[storyboard instantiateViewControllerWithIdentifier:@"VideoViewController"]animated:NO];


}


@end
