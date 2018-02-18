//
//  ViewController.m
//  Meridian
//
//  Created by Ben Sparkes on 22/12/2017.
//  Copyright © 2017 Ben Sparkes. All rights reserved.
//

#import "ViewController.h"
#import "v0rtex.h"
#import "v0rtex-old.h"
#import "patchfinder64.h"
#import "kernel.h"
#import "amfi.h"
#import "root-rw.h"
#import "offsets.h"
#import "helpers.h"
#import "fucksigningservices.h"
#import "jailbreak.h"
#import "DRMController.h"
#import <sys/utsname.h>
#import <sys/stat.h>
#import <sys/spawn.h>
#import <Foundation/Foundation.h>

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UIButton *goButton;
@property (weak, nonatomic) IBOutlet UIButton *creditsButton;
@property (weak, nonatomic) IBOutlet UIButton *websiteButton;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *progressSpinner;
@property (weak, nonatomic) IBOutlet UITextView *textArea;
@property (weak, nonatomic) IBOutlet UILabel *versionLabel;
@property (nonatomic, readwrite) IBOutlet UISwitch *v0rtexSwitch;
@end

NSString *Version = @"Meridian: Internal Beta 7";
NSOperatingSystemVersion osVersion;

id thisClass;

bool jailbreak_has_run = false;

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    thisClass = self;
    
    [self.goButton.layer setCornerRadius:5];
    [self.creditsButton.layer setCornerRadius:5];
    [self.websiteButton.layer setCornerRadius:5];
    
    [self.versionLabel setText:Version];
    
    jailbreak_has_run = check_for_jailbreak();
    
    [self doUpdateCheck];
    
    // Log current device and version info
    osVersion = [[NSProcessInfo processInfo] operatingSystemVersion];
    
    [self writeTextPlain:[NSString stringWithFormat:@"> %@", Version]];
    
    if (osVersion.majorVersion != 10) {
        [self writeTextPlain:@"> Meridian does not work on versions of iOS other than iOS 10."];
        [self writeTextPlain:[NSString stringWithFormat:@"> found iOS version %@", [self getVersionString]]];
        [self.goButton setHidden:YES];
        return;
    }
    
    [self writeTextPlain:[NSString stringWithFormat:@"> %s on iOS %@ (Build %@)",
                          [self getDeviceIdentifier],
                          [self getVersionString],
                          [self getBuildString]]];
    
    // Load offsets
    if (load_offsets() != 0) {
        [self writeTextPlain:@"> Your device is not supported; no offsets were found."];
        [self writeTextPlain:@"> You will need to find your own offsets."];
        [self writeTextPlain:@"> Once found, send them to @iBSparkes on Twitter."];
        [self noOffsets];
        return;
    }
    
    if (jailbreak_has_run) {
        [self writeTextPlain:@"> already jailbroken."];
        
        // set done button
        [self.goButton setTitle:@"done" forState:UIControlStateNormal];
        
        // aaaaand grey it out
        [self.goButton setEnabled:NO];
        self.goButton.alpha = 0.5;
    
        return;
    }
    
    [self writeTextPlain:@"> ready."];
    
    NSLog(@"App bundle directory: %s", bundle_path());
}

- (void)viewDidAppear:(BOOL)animated {
    if ([fucksigningservices appIsPirated:[NSString stringWithUTF8String:bundled_file("embedded.mobileprovision")]]) {
        // app is pirated, fuckers
        DRMController *drmController = [self.storyboard instantiateViewControllerWithIdentifier:@"DRMController"];
        [self presentViewController:drmController animated:YES completion:nil];
        return;
    }
}

- (IBAction)goButtonPressed:(UIButton *)sender {
    if ([fucksigningservices appIsPirated:[NSString stringWithUTF8String:bundled_file("embedded.mobileprovision")]]) {
        // app is pirated, fuckers
        DRMController *drmController = [self.storyboard instantiateViewControllerWithIdentifier:@"DRMController"];
        [self presentViewController:drmController animated:YES completion:nil];
        return;
    }
    
    // when jailbreak runs, 'go' button is
    // turned to 'respring'
    if (jailbreak_has_run) {
        int rv = respring();
        if (rv != 0) {
            [self writeTextPlain:@"failed to respring."];
        }
        return;
    }
    
    // set up the UI to 'running' state
    [self.goButton setEnabled:NO];
    [self.goButton setHidden:YES];
    [self.creditsButton setEnabled:NO];
    self.creditsButton.alpha = 0.5;
    [self.websiteButton setEnabled:NO];
    self.websiteButton.alpha = 0.5;
    [self.progressSpinner startAnimating];
    
    // background thread so we can update the UI
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^(void) {
        int ret = makeShitHappen(self);
        
        if (ret != 0) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self exploitFailed];
            });
            
            return;
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            [self exploitSucceeded];
        });
    });
}

- (IBAction)websiteButtonPressed:(UIButton *)sender {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://meridian.sparkes.zone"]
                                       options:@{}
                             completionHandler:nil];
}

- (char *)getDeviceIdentifier {
    static struct utsname u;
    uname(&u);
    return u.machine;
}

- (NSString *)getVersionString {
    return [NSString stringWithFormat:@"%ld.%ld.%ld",
            (long)osVersion.majorVersion,
            (long)osVersion.minorVersion,
            (long)osVersion.patchVersion];
}

- (NSString *)getBuildString {
    NSString *verString = [[NSProcessInfo processInfo] operatingSystemVersionString];
    // wish there was a better way of doing this (hopefully there is)
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"14[A-Za-z0-9]{3,5}"
                                                                           options:0
                                                                             error:nil];
    
    NSRange range = [regex rangeOfFirstMatchInString:verString options:0 range:NSMakeRange(0, [verString length])];
    
    return [verString substringWithRange:range];
}

- (void)exploitSucceeded {
    jailbreak_has_run = true;
    
    [self writeTextPlain:@"\n> your device has been freed! \n"];
    
    [self writeTextPlain:@"note: please click 'respring' to get this party started :) \n"];
    
    [self.progressSpinner stopAnimating];
    
    [self.goButton setEnabled:YES];
    [self.goButton setHidden:NO];
    [self.goButton setTitle:@"respring" forState:UIControlStateNormal];
    
    [self.creditsButton setEnabled:YES];
    self.creditsButton.alpha = 1;
    [self.websiteButton setEnabled:YES];
    self.websiteButton.alpha = 1;
}

- (void)exploitFailed {
    [self writeTextPlain:@"exploit failed. please try again. \n"];
    
    [self.goButton setEnabled:YES];
    [self.goButton setHidden:NO];
    [self.creditsButton setEnabled:YES];
    self.creditsButton.alpha = 1;
    [self.websiteButton setEnabled:YES];
    self.websiteButton.alpha = 1;
    [self.progressSpinner stopAnimating];
}

- (void)noOffsets {
    [self.goButton setTitle:@"no offsets" forState:UIControlStateNormal];
    [self.goButton setEnabled:NO];
    self.goButton.alpha = 0.5;
}

- (void)doUpdateCheck {
    // skip the version check if we're running an internal build
    if ([Version containsString:@"Internal"]) {
        return;
    }
    
    NSURL *url = [NSURL URLWithString:@"https://meridian.sparkes.zone/latest"];
    
    NSURLSessionDataTask *downloadTask = [[NSURLSession sharedSession]
                                          dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *header, NSError *error) {
                                              if (error != nil) {
                                                  NSLog(@"failed to get information from the update server.");
                                                  return;
                                              }
                                              
                                              NSString *response = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                                              if (response != Version) {
                                                  [self doUpdatePopup:response];
                                              }
                                          }];
    
    [downloadTask resume];
}

- (void)doUpdatePopup:(NSString *)update {
    NSString *message = [NSString stringWithFormat:@"An update is available for Meridian: %@It can be downloaded from the website.", update];
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Meridian Update"
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *websiteAction = [UIAlertAction actionWithTitle:@"Website" style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction * action) {
                                                              [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://meridian.sparkes.zone"]
                                                                                                 options:@{}
                                                                                       completionHandler:nil];
                                                          }];
    
    UIAlertAction *closeAction = [UIAlertAction actionWithTitle:@"Close"
                                                          style:UIAlertActionStyleCancel
                                                        handler:nil];
    
    [alert addAction:websiteAction];
    [alert addAction:closeAction];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)writeText:(NSString *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (![message  isEqual: @"done!"] && ![message isEqual:@"failed!"]) {
            NSLog(@"%@", message);
            _textArea.text = [_textArea.text stringByAppendingString:[NSString stringWithFormat:@"%@ ", message]];
        } else {
            _textArea.text = [_textArea.text stringByAppendingString:[NSString stringWithFormat:@"%@\n", message]];
        }
        
        NSRange bottom = NSMakeRange(_textArea.text.length - 1, 1);
        [self.textArea scrollRangeToVisible:bottom];
    });
}

- (void)writeTextPlain:(NSString *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        _textArea.text = [_textArea.text stringByAppendingString:[NSString stringWithFormat:@"%@\n", message]];
        NSRange bottom = NSMakeRange(_textArea.text.length - 1, 1);
        [self.textArea scrollRangeToVisible:bottom];
        
        NSLog(@"%@", message);
    });
}

// kinda dumb, kinda lazy, ¯\_(ツ)_/¯
void log_message(NSString *message) {
    [thisClass writeTextPlain:message];
}

@end
