//
//  ViewController.m
//  Meridian
//
//  Created by Ben Sparkes on 22/12/2017.
//  Copyright © 2017 Ben Sparkes. All rights reserved.
//

#import "ViewController.h"

#include "helpers.h"
#include "jailbreak.h"

#include <sys/utsname.h>
#include <sys/stat.h>

#import <Foundation/Foundation.h>

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UIButton *goButton;
@property (weak, nonatomic) IBOutlet UIButton *creditsButton;
@property (weak, nonatomic) IBOutlet UIButton *websiteButton;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *progressSpinner;
@property (weak, nonatomic) IBOutlet UITextView *textArea;
@property (weak, nonatomic) IBOutlet UILabel *versionLabel;
@end

NSString *Version = @"Meridian: v0.9-003 Pre-Release";
NSOperatingSystemVersion osVersion;

id thisClass;

bool has_run_once = false;
bool jailbreak_has_run = false;

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    thisClass = self;
    
    [self.goButton.layer setCornerRadius:5];
    [self.creditsButton.layer setCornerRadius:5];
    [self.websiteButton.layer setCornerRadius:5];
    
    if ([Version containsString:@"Internal"]) {
        NSString *buildDate = [NSString stringWithContentsOfFile:[NSString stringWithFormat:@"%s", bundled_file("build_time")]
                                                        encoding:NSUTF8StringEncoding
                                                           error:nil];
        [self.versionLabel setText:[NSString stringWithFormat:@"%@: %@", Version, buildDate]];
    } else {
        [self.versionLabel setText:[NSString stringWithFormat:@"%@", Version]];
    }
    
    jailbreak_has_run = check_for_jailbreak();
    
//    [self doUpdateCheck];
    
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
    
    if (jailbreak_has_run) {
        [self writeTextPlain:@"> already jailbroken."];
        
        // set done button
        [self.goButton setTitle:@"done" forState:UIControlStateNormal];
        
        // aaaaand grey it out
        [self.goButton setEnabled:NO];
        [self.goButton setAlpha:0.5];
        
        return;
    }
    
    // Device is already jailbroken, but not with Meridian
    if (file_exists("/private/var/lib/dpkg/status") == 0 &&
        file_exists("/.meridian_installed")) {
        [self writeTextPlain:@"this device has already been jailbroken with another tool. please run Cydia Eraser to wipe this device to ensure you encounter no issues with Meridian"];
        [self writeTextPlain:@"if you have jailbroken with a Meridian Public Beta, please install the latest Public Beta and use the 'uninstall' option"];
        
        [self.goButton setTitle:@"please erase" forState:UIControlStateNormal];
        [self.goButton setEnabled:NO];
        [self.goButton setAlpha:0.5];

        return;
    }
    
    // Credits to tihm on waiting
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^(void) {
        int waitTime;
        while ((waitTime = 90 - uptime()) > 0) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.goButton setTitle:[NSString stringWithFormat:@"wait: %d", waitTime] forState:UIControlStateNormal];
                [self.goButton setEnabled:false];
                [self.goButton setAlpha:0.6];
            });
            
            sleep(1);
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.goButton setTitle:@"go" forState:UIControlStateNormal];
            [self.goButton setEnabled:true];
            [self.goButton setAlpha:1];
            
            [self writeTextPlain:@"> ready."];
        });
    });
    
    NSLog(@"App bundle directory: %s", bundle_path());
}

- (IBAction)goButtonPressed:(UIButton *)sender {
    // when jailbreak runs, 'go' button is
    // turned to 'respring'
    if (jailbreak_has_run) {
        chown("/meridian/ldrestart", 0, 0);
        chmod("/meridian/ldrestart", 0755);
        
        // ldrestart restarts all launch daemons,
        // allowing shit to be injected into 'em
        int rv = execprog("/bin/bash", (const char **)&(const char*[]) {
            "/bin/bash",
            "-c",
            "/usr/bin/nohup /meridian/ldrestart 2>&1 >/dev/null &",
            NULL
        });
        if (rv != 0) {
            [self writeTextPlain:@"failed to run ldrestart."];
            return;
        }
        
        [self.goButton setHidden:YES];
        return;
    }
    
    // if we've run once, just reboot
    if (has_run_once) {
        [self.goButton setHidden:YES];
        restart_device();
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
    
    has_run_once = true;
    
    // background thread so we can update the UI
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^(void) {
        int ret = makeShitHappen(self);
        
        if (ret != 0) {
            NSLog(@"MERIDIAN HAS FAILED TO RUN :(");
            
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
    [self writeTextPlain:@"exploit failed. please reboot & try again."];
    
    [self.goButton setEnabled:YES];
    [self.goButton setHidden:NO];
    [self.goButton setTitle:@"reboot" forState:UIControlStateNormal];
    
    [self.creditsButton setEnabled:YES];
    [self.creditsButton setAlpha:1];
    
    [self.websiteButton setEnabled:YES];
    [self.websiteButton setAlpha:1];
    
    [self.progressSpinner stopAnimating];
}

- (void)doUpdateCheck {
    // skip the version check if we're running an internal build
    if ([Version containsString:@"Internal"]) {
        NSLog(@"internal build detected, skipping");
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
                                              NSLog(@"got response '%@', Version '%@'", response, Version);
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
            [self.textArea setText:[self.textArea.text stringByAppendingString:[NSString stringWithFormat:@"%@ ", message]]];
        } else {
            [self.textArea setText:[self.textArea.text stringByAppendingString:[NSString stringWithFormat:@"%@\n", message]]];
        }
        
        NSRange bottom = NSMakeRange(self.textArea.text.length - 1, 1);
        [self.textArea scrollRangeToVisible:bottom];
    });
}

- (void)writeTextPlain:(NSString *)message, ... {
    va_list args;
    va_start(args, message);
    message = [[NSString alloc] initWithFormat:[message stringByAppendingString:@"\n"] arguments:args];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.textArea setText:[self.textArea.text stringByAppendingString:message]];
        NSRange bottom = NSMakeRange(self.textArea.text.length - 1, 1);
        [self.textArea scrollRangeToVisible:bottom];
        NSLog(@"%@", message);
    });
    va_end(args);
}

// kinda dumb, kinda lazy, ¯\_(ツ)_/¯
void log_message(NSString *message) {
    [thisClass writeTextPlain:message];
}

@end

