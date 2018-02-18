//
//  ViewController.h
//  Meridian
//
//  Created by Ben Sparkes on 22/12/2017.
//  Copyright © 2017 Ben Sparkes. All rights reserved.
//

#import "v0rtex.h"
#import <UIKit/UIKit.h>

@interface ViewController : UIViewController
- (void)writeText:(NSString *)message;
- (void)writeTextPlain:(NSString *)message;
@property (nonatomic, readonly) IBOutlet UISwitch *v0rtexSwitch;
@end

task_t tfp0;
uint64_t kslide;
uint64_t kernel_base;
uint64_t kern_ucred;
uint64_t kernprocaddr;

id thisClass;

void log_message(NSString *message);
