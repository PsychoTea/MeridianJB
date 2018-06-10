//
//  CreditsController.m
//  Meridian
//
//  Created by Sticktron on 2018-06-02.
//  Copyright © 2018 Ben Sparkes. All rights reserved.
//

#import "CreditsController.h"

@interface CreditsController ()

@end

@implementation CreditsController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)openLink:(NSString *)url {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:url] options:@{} completionHandler:nil];
}

- (IBAction)buttonPressed:(UIButton *)sender {
    NSString *url = [NSString stringWithFormat:@"http://www.twitter.com/%@", sender.titleLabel.text];
    [self openLink:url];
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
