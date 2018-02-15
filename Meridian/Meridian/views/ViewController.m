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
#import "libjb.h"
#import "fucksigningservices.h"
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
@end

NSString *Version = @"Meridian: Internal Beta 7";
NSFileManager *fileMgr;
NSOperatingSystemVersion osVersion;

id thisClass;
task_t tfp0;
uint64_t kslide;
uint64_t kernel_base;
uint64_t kern_ucred;
uint64_t kernprocaddr;

bool jailbreak_has_run = false;

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    thisClass = self;
    
    fileMgr = [NSFileManager defaultManager];
    
    [self.goButton.layer setCornerRadius:5];
    [self.creditsButton.layer setCornerRadius:5];
    [self.websiteButton.layer setCornerRadius:5];
    
    [self.versionLabel setText:Version];
    
    jailbreak_has_run = check_for_jailbreak();
    
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
        [self respring];
        return;
    }
    
    // lets run dat ting
    
    [self writeTextPlain:@"running v0rtex..."];
    
    [self.goButton setEnabled:NO];
    [self.goButton setHidden:YES];
    [self.creditsButton setEnabled:NO];
    self.creditsButton.alpha = 0.5;
    [self.websiteButton setEnabled:NO];
    self.websiteButton.alpha = 0.5;
    [self.progressSpinner startAnimating];
    
    // background thread so we can update the UI
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^(void) {
        
        // run v0rtex itself
        int ret = v0rtex_old(&tfp0, &kslide, &kern_ucred, &kernprocaddr);

        if (ret != 0)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self exploitFailed];
            });
            
            return;
        }
        
        [self writeTextPlain:@"exploit succeeded! praize siguza!"];
        
        // do all the post-exploitation shit
        ret = [self makeShitHappen];
        
        if (ret != 0)
        {
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

-(int) makeShitHappen {
    int rv;
    
    kernel_base = 0xFFFFFFF007004000 + kslide;
    
    NSLog(@"tfp0: %x", tfp0);
    NSLog(@"kslide: %llx", (uint64_t)kslide);
    NSLog(@"kernel_base: %llx", (uint64_t)kernel_base);
    NSLog(@"kern_ucred: %llx", (uint64_t)kern_ucred);
    NSLog(@"kernprocaddr = %llx", (uint64_t)kernprocaddr);
    
    {
        // set up stuff
        init_kernel(tfp0);
        init_patchfinder(tfp0, kernel_base, NULL);
        init_amfi();
    }
    
    {
        // patch containermanagerd (why? who knows. fun.)
        [self writeText:@"patching containermanagerd..."];
        
        uint64_t cmgr = find_proc_by_name("containermanager");
        if (cmgr == 0) {
            NSLog(@"unable to find containermanager! \n");
        } else {
            wk64(cmgr + 0x100, kern_ucred);
            NSLog(@"patched containermanager");
        }
        
        [self writeText:@"done!"];
    }
    
    {
        // remount '/' as r/w
        [self writeText:@"remounting '/' as r/w..."];
        
        int pre130 = osVersion.minorVersion < 3 ? 1 : 0; /* further patching is required on <10.3 */
        rv = mount_root(kslide, pre130);
        if (rv != 0) {
            [self writeText:@"failed!"];
            [self writeTextPlain:[NSString stringWithFormat:@"ERROR: failed to remount '/' as r/w! (%d)", rv]];
            [self writeTextPlain:[NSString stringWithFormat:@"errno: %u strerror: %s", errno, strerror(errno)]];
            return 1;
        }
     
        // check we can write to root
        rv = can_write_root();
        if (rv != 0) {
            [self writeText:@"failed!"];
            return 1;
        }
        
        [self writeText:@"done!"];
    }
    
    {
        // extract bootstrap
        
        [fileMgr removeItemAtPath:@"/meridian/.bootstrap" error:nil];
        
        if (file_exists("/meridian/.bootstrap") != 0) {
            [self writeText:@"extracting bootstrap..."];
            
            // merk old /meridian folder
            [fileMgr removeItemAtPath:@"/meridian" error:nil];
            
            mkdir("/meridian", 0755);
            mkdir("/meridian/logs", 0755);
            
            // extract tar
            extract_bundle("tar.tar", "/meridian");
            chmod("/meridian/tar", 0755);
            inject_trust("/meridian/tar");
            
            // extract meridian-base.tar
            rv = execprog("/meridian/tar", (const char**)&(const char*[]) {
                "/meridian/tar",
                "--preserve-permissions",
                "--no-overwrite-dir",
                "-C",
                "/",
                "-xvf",
                bundled_file("meridian-base.tar"),
                NULL
            });
            if (rv != 0) {
                [self writeText:@"failed!"];
                [self writeTextPlain:[NSString stringWithFormat:@"got rv %d on meridian-base.tar", rv]];
                return 1;
            }
            
            // extract system-base.tar
            rv = execprog("/meridian/tar", (const char **)&(const char*[]) {
                "/meridian/tar",
                "--preserve-permissions",
                "--no-overwrite-dir",
                "-C",
                "/",
                "-xvf",
                bundled_file("system-base.tar"),
                NULL
            });
            if (rv != 0) {
                [self writeText:@"failed!"];
                [self writeTextPlain:[NSString stringWithFormat:@"got rv %d on system-base.tar", rv]];
                return 1;
            }
            
            // extract installer-base.tar
            rv = execprog("/meridian/tar", (const char **)&(const char*[]) {
                "/meridian/tar",
                "--preserve-permissions",
                "--no-overwrite-dir",
                "-C",
                "/",
                "-xvf",
                bundled_file("installer-base.tar"),
                NULL
            });
            if (rv != 0) {
                [self writeText:@"failed!"];
                [self writeTextPlain:[NSString stringWithFormat:@"got rv %d on installer-base.tar", rv]];
                return 1;
            }
            
            // set up dpkg database
            if (file_exists("/private/var/lib/dpkg") == 0) {
                [fileMgr moveItemAtPath:@"/private/var/lib/dpkg" toPath:@"/Library/dpkg" error:nil];
            } else {
                // extract dpkgdb-base.tar
                rv = execprog("/meridian/tar", (const char **)&(const char*[]) {
                    "/meridian/tar",
                    "--preserve-permissions",
                    "--no-overwrite-dir",
                    "-C",
                    "/",
                    "-xvf",
                    bundled_file("dpkgdb-base.tar"),
                    NULL
                });
                if (rv != 0) {
                    [self writeText:@"failed!"];
                    [self writeTextPlain:[NSString stringWithFormat:@"got rv %d on dpkgdb-base.tar", rv]];
                    return 1;
                }
            }
            symlink("/Library/dpkg", "/private/var/lib/dpkg");
            
            // extract cydia-base.tar
            rv = execprog("/meridian/tar", (const char **)&(const char*[]) {
                "/meridian/tar",
                "--preserve-permissions",
                "--no-overwrite-dir",
                "-C",
                "/",
                "-xvf",
                bundled_file("cydia-base.tar"),
                NULL
            });
            if (rv != 0) {
                [self writeText:@"failed!"];
                [self writeTextPlain:[NSString stringWithFormat:@"got rv %d on system-base.tar", rv]];
                return 1;
            }
            
            // extract optional-base.tar
            rv = execprog("/meridian/tar", (const char **)&(const char*[]) {
                "/meridian/tar",
                "--preserve-permissions",
                "--no-overwrite-dir",
                "-C",
                "/",
                "-xvf",
                bundled_file("optional-base.tar"),
                NULL
            });
            if (rv != 0) {
                [self writeText:@"failed!"];
                [self writeTextPlain:[NSString stringWithFormat:@"got rv %d on optional-base.tar", rv]];
                return 1;
            }
            
            unlink("/meridian/tar");
            
            inject_trust("/usr/bin/killall");
            [self enableHiddenApps];
            
            touch_file("/meridian/.bootstrap");
            
            [self writeText:@"done!"];
            
            // run uicache
            [self writeText:@"running uicache..."];
            
//            inject_trust("/bin/uicache");
//            rv = uicache();
//            if (rv != 0) {
//                [self writeText:@"failed!"];
//                [self writeTextPlain:[NSString stringWithFormat:@"uicache returned %d", rv]];
//                return 1;
//            }
            
            [self writeText:@"done!"];
        }
    }
    
    {
        // nostash
        touch_file("/.cydia_no_stash");
    }
    
    {
        // patch amfi ;)
        [self writeText:@"patching amfi..."];
        
        rv = defecate_amfi();
        if (rv != 0) {
            [self writeText:@"failed!"];
            [self writeTextPlain:[NSString stringWithFormat:@"got error %d for amfi patch.", rv]];
            return 1;
        }
        
        [self writeText:@"done!"];
    }
    
    {
        // Launch dropbear
        [self writeText:@"launching dropbear..."];
    
        rv = execprog("/meridian/dropbear", (const char**)&(const char*[]) {
            "/meridian/dropbear",
            "-p",
            "22",
            "-p",
            "2222",
            "-R",
            "-E",
            "-m",
            "-S",
            "/",
            NULL
        });
        if (rv != 0) {
            [self writeText:@"failed!"];
            [self writeTextPlain:[NSString stringWithFormat:@"got value %d from posix_spawn: %s", rv, strerror(rv)]];
            return 1;
        }
        
        [self writeText:@"done!"];
    }
    
    {
        // create /Library/MobileSubstrate/DynamicLibraries
        if (file_exists("/Library/MobileSubstrate/DynamicLibraries") == 0) {
            mkdir("/Library/MobileSubstrate", 0755);
            mkdir("/Library/MobileSubstrate/DynamicLibraries", 0755);
        }
        
        // link CydiaSubstrate.framework -> /usr/lib/libsubstrate.dylib
        if (file_exists("/Library/Frameworks/CydiaSubstrate.framework") == 0) {
            [fileMgr removeItemAtPath:@"/Library/Frameworks/CydiaSubstrate.framework" error:nil];
        }
        mkdir("/Library/Frameworks/CydiaSubstrate.framework", 0755);
        symlink("/usr/lib/libsubstrate.dylib", "/Library/Frameworks/CydiaSubstrate.framework/CydiaSubstrate");
    }
    
    {
        [self writeText:@"starting jailbreakd..."];
        
        inject_trust("/bin/launchctl");
        inject_trust("/meridian/pspawn_hook.dylib");
        inject_trust("/usr/lib/SBInject.dylib");
        
        unlink("/var/tmp/jailbreakd.pid");
        
        NSData *blob = [NSData dataWithContentsOfFile:@"/meridian/jailbreakd/jailbreakd.plist"];
        NSMutableDictionary *job = [NSPropertyListSerialization propertyListWithData:blob
                                                                             options:NSPropertyListMutableContainers
                                                                              format:nil
                                                                               error:nil];
        
        job[@"EnvironmentVariables"][@"KernelBase"] = [NSString stringWithFormat:@"0x%16llx", kernel_base];
        job[@"EnvironmentVariables"][@"KernProcAddr"] = [NSString stringWithFormat:@"0x%16llx", kernprocaddr];
        job[@"EnvironmentVariables"][@"ZoneMapOffset"] = [NSString stringWithFormat:@"0x%16llx", OFFSET_ZONE_MAP];
        [job writeToFile:@"/meridian/jailbreakd/jailbreakd.plist" atomically:YES];
        chmod("/meridian/jailbreakd/jailbreakd.plist", 0600);
        chown("/meridian/jailbreakd/jailbreakd.plist", 0, 0);
        
        rv = execprog("/bin/launchctl", (const char **)&(const char*[]) {
            "/bin/launchctl",
            "load",
            "-w",
            "/meridian/jailbreakd/jailbreakd.plist",
            NULL
        });
        if (rv != 0) {
            [self writeText:@"failed!"];
            [self writeTextPlain:[NSString stringWithFormat:@"failed to start jailbreakd: %d", rv]];
            return 1;
        }
        
        while (!file_exist("/var/tmp/jailbreakd.pid")) {
            printf("Waiting for jailbreakd \n");
            usleep(100000); // 100ms
        }
        
        // inject pspawn_hook.dylib to launchd
        rv = execprog("/meridian/injector", (const char**)&(const char*[]) {
            "/meridian/injector",
            itoa(1), // launchd pid
            "/meridian/pspawn_hook.dylib",
            NULL
        });
        if (rv != 0) {
            [self writeText:@"failed!"];
            [self writeTextPlain:[NSString stringWithFormat:@"failed to inject pspawn_hook: %d", rv]];
            return 1;
        }
        
        [self writeText:@"done!"];
    }
    
    {
        // load custom launch daemons
        [self writeText:@"loading daemons..."];
        
        // all launch daemons need to be owned by root
        NSArray* daemons = [fileMgr contentsOfDirectoryAtPath:@"/Library/LaunchDaemons" error:nil];
        for (NSString *file in daemons) {
            NSString *path = [NSString stringWithFormat:@"/Library/LaunchDaemons/%@", file];
            NSLog(@"found launch daemon: %@", path);
            chmod([path UTF8String], 0755);
            chown([path UTF8String], 0, 0);
        }
        
        rv = execprog("/bin/launchctl", (const char **)&(const char*[]) {
            "/bin/launchctl",
            "load",
            "-w",
            "/Library/LaunchDaemons",
            NULL
        });
        if (rv != 0) {
            [self writeText:@"failed!"];
            [self writeTextPlain:[NSString stringWithFormat:@"launchctl returned %d", rv]];
            return 1;
        }
        
        [self writeText:@"done!"];
    }
    
    return 0;
}

- (void)respring {
    pid_t springBoard = get_pid_for_name("backboardd");
    if (springBoard == 0) {
        [self writeTextPlain:@"Failed to respring."];
        return;
    }
    kill(springBoard, 9);
}

- (void)enableHiddenApps {
    // enable showing of system apps on springboard
    // this is some funky killall stuff tho
    execprog("/usr/bin/killall", (const char**)&(const char*[]) {
        "/usr/bin/killall",
        "-SIGSTOP",
        "cfprefsd",
        NULL
    });
    NSMutableDictionary* md = [[NSMutableDictionary alloc] initWithContentsOfFile:@"/var/mobile/Library/Preferences/com.apple.springboard.plist"];
    [md setObject:[NSNumber numberWithBool:YES] forKey:@"SBShowNonDefaultSystemApps"];
    [md writeToFile:@"/var/mobile/Library/Preferences/com.apple.springboard.plist" atomically:YES];
    execprog("/usr/bin/killall", (const char**)&(const char*[]) {
        "/usr/bin/killall",
        "-9",
        "cfprefsd",
        NULL
    });
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

bool check_for_jailbreak() {
    int csops(pid_t pid, unsigned int ops, void *useraddr, size_t usersize);
    
    uint32_t flags;
    csops(getpid(), 0, &flags, 0);
    
    return flags & CS_PLATFORM_BINARY;
}

// kinda dumb, kinda lazy, ¯\_(ツ)_/¯
void log_message(NSString *message) {
    [thisClass writeTextPlain:message];
}

@end
