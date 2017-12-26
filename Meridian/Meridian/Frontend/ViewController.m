//
//  ViewController.m
//  Meridian
//
//  Created by Ben Sparkes on 22/12/2017.
//  Copyright © 2017 Ben Sparkes. All rights reserved.
//

#import "ViewController.h"
#import "v0rtex.h"
#import <sys/utsname.h>
#import <Foundation/Foundation.h>

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UIButton *goButton;
@property (weak, nonatomic) IBOutlet UIButton *creditsButton;
@property (weak, nonatomic) IBOutlet UIButton *websiteButton;
@property (weak, nonatomic) IBOutlet UIButton *sourceButton;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *progressSpinner;
@property (weak, nonatomic) IBOutlet UITextView *textArea;
@end

task_t tfp0;
kptr_t kslide;
kptr_t kernel_base;
kptr_t kernucred;
kptr_t selfproc;

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _goButton.layer.cornerRadius = 5;
    _creditsButton.layer.cornerRadius = 5;
    _websiteButton.layer.cornerRadius = 5;
    _sourceButton.layer.cornerRadius = 5;

    // Log current device and version info
    NSOperatingSystemVersion ver = [[NSProcessInfo processInfo] operatingSystemVersion];
    NSString *verString = [[NSProcessInfo processInfo] operatingSystemVersionString];
    struct utsname u;
    uname(&u);
    
    [self writeText:[NSString stringWithFormat:@"> found %s on iOS %@", u.machine, verString]];
    
    if (ver.majorVersion != 10) {
        [self writeText:@"> Meridian does not work on versions of iOS other than iOS 10."];
        [self.goButton setHidden:YES];
        return;
    }
    
    if (ver.minorVersion < 3) {
        [self writeText:@"WARNING: Meridian is UNTESTED on versions lower than iOS 10.3. It should work (in theory), but may bootloop your device. Proceeed at your own risk."];
    }
    
    [self writeText:@"> ready."];
}

- (IBAction)goButtonPressed:(UIButton *)sender {
    
    // lets run dat ting
    
    [self writeText:@"running..."];
    [self.goButton setEnabled:NO];
    [self.goButton setHidden:YES];
    [self.creditsButton setEnabled:NO];
    self.creditsButton.alpha = 0.5;
    [self.websiteButton setEnabled:NO];
    self.websiteButton.alpha = 0.5;
    // [self.sourceButton setEnabled:NO];
    // self.sourceButton.alpha = 0.5;
    [self.progressSpinner startAnimating];
    
    /*
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void) {
        [self exploitFailed];
    });
     */
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^(void) {
        
        int ret = v0rtex(&tfp0, &kslide, &kernucred, &selfproc);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (ret == 0) {
                [self writeText:@"exploit succeeded!"];
                // run d next ting
            } else {
                [self writeText:@"exploit failed. please try again."];
                [self exploitFailed];
            }
        });
    });
}

- (IBAction)websiteButtonPressed:(UIButton *)sender {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://meridian.sparkes.zone"]
                                       options:@{}
                             completionHandler:nil];
}

- (IBAction)sourceButtonPressed:(UIButton *)sender {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://github.com/PsychoTea/MeridianJB"]
                                       options:@{}
                             completionHandler:nil];
}

- (void)exploitFailed {
    [self writeText:@"exploit failed. please try again. \n"];
    
    [self.goButton setEnabled:YES];
    [self.goButton setHidden:NO];
    [self.creditsButton setEnabled:YES];
    self.creditsButton.alpha = 1;
    [self.websiteButton setEnabled:YES];
    self.websiteButton.alpha = 1;
    // [self.sourceButton setEnabled:YES];
    // self.sourceButton.alpha = 1;
    [self.progressSpinner stopAnimating];
}

- (void)writeText:(NSString *)message {
    _textArea.text = [_textArea.text stringByAppendingString:[NSString stringWithFormat:@"%@\n", message]];
    
    NSRange bottom = NSMakeRange(_textArea.text.length - 1, 1);
    [self.textArea scrollRangeToVisible:bottom];
}

@end
