//
//  LogInViewController.m
//  BMLPVideoArchiver
//
//  Created by Justine Gartner on 1/2/16.
//  Copyright © 2016 Justine Kay. All rights reserved.
//

#import "LogInViewController.h"
#import "VideoViewController.h"

@interface LogInViewController ()
@property (weak, nonatomic) IBOutlet UIButton *logInButton;

@end

@implementation LogInViewController

-(void)viewDidLoad
{
    [super viewDidLoad];
    
    self.logInButton.layer.borderWidth = 1.5;
    self.logInButton.layer.borderColor = [UIColor redColor].CGColor;
    self.logInButton.layer.cornerRadius = 10.0;
    
    self.logInButton.titleLabel.textColor = [UIColor redColor];
    
}

- (IBAction)logInButtonTapped:(UIButton *)sender
{
    
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    
    VideoViewController *videoVC = [storyboard instantiateViewControllerWithIdentifier:@"VideoViewController"];
    
    
    [self presentViewController:videoVC animated:YES completion:nil];

}


@end
