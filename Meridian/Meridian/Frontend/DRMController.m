//
//  DRMController.m
//  Meridian
//
//  Created by Ben Sparkes on 08/01/2018.
//  Copyright © 2018 Ben Sparkes. All rights reserved.
//

#import "DRMController.h"
#import <Foundation/Foundation.h>

@interface DRMController()
@property (weak, nonatomic) IBOutlet UIButton *websiteButton;
@end

@implementation DRMController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _websiteButton.layer.cornerRadius = 5;
}

- (IBAction)websiteButtonPressed:(UIButton *)sender {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://meridian.sparkes.zone"]
                                       options:@{}
                             completionHandler:nil];
}

@end
