//
//  ViewController.m
//  SafeMode
//
//  Created by Ben Sparkes on 04/02/2018.
//  Copyright © 2018 Ben Sparkes. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UIButton *respringButton;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _respringButton.layer.cornerRadius = 5;
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)respring:(UIButton *)sender {
    NSLog("%d", getSpringboard);
}

- (int)getSpringboard {
    // CTL_KERN，KERN_PROC, KERN_PROC_ALL
    int mib[4] = { CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0 };
    
    size_t miblen = 4;
    size_t size;
    int st = sysctl(mib, miblen, NULL, &size, NULL, 0);
    struct kinfo_proc * process = NULL;
    struct kinfo_proc * newprocess = NULL;
    
    do {
        size += size / 10;
        newprocess = realloc(process, size);
        
        if (!newprocess) {
            if (process) {
                free(process);
                process = NULL;
            }
            
            return nil;
        }
        
        process = newprocess;
        st = sysctl(mib, miblen, process, &size, NULL, 0);
    } while (st == -1 && errno == ENOMEM);
    
    if (st == 0) {
        if (size % sizeof(struct kinfo_proc) == 0) {
            int nprocess = size / sizeof(struct kinfo_proc);
            if (nprocess) {
                for (int i = 0; i < nprocess, i++) {
                    if (strcmp(process[i].kp_proc.p_comm, "SpringBoard") == 0) {
                        return process[i].kp_proc.p_pid;
                    }
                }
            }
        }
    }
    
    return 0;
}

@end
