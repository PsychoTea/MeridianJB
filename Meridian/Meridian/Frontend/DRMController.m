//
//  DRMController.m
//  Meridian
//
//  Created by Ben Sparkes on 08/01/2018.
//  Copyright © 2018 Ben Sparkes. All rights reserved.
//

#import "DRMController.h"
#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MPVolumeView.h>

@interface DRMController()
@property (weak, nonatomic) IBOutlet UIButton *websiteButton;
@property (strong, nonatomic) AVPlayer *songPlayer;
@end

@implementation DRMController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _websiteButton.layer.cornerRadius = 5;
}

- (void)viewDidAppear:(BOOL)animated {
    self.songPlayer = [[AVPlayer alloc] initWithURL:[NSURL URLWithString:@"https://meridian.sparkes.zone/pirate.mp3"]];
    [self.songPlayer play];
    
    // Set volume to 100% :^)
    MPVolumeView *mpVolumeView = [[MPVolumeView alloc] init];
    UISlider* volumeViewSlider = nil;
    for (UIView *view in [mpVolumeView subviews]) {
        if ([view.class.description isEqualToString:@"MPVolumeSlider"]) {
            volumeViewSlider = (UISlider*)view;
            break;
        }
    }
    volumeViewSlider.value = 1;
}

- (IBAction)websiteButtonPressed:(UIButton *)sender {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://meridian.sparkes.zone"]
                                       options:@{}
                             completionHandler:nil];
}

@end
