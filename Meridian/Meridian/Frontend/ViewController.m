//
//  ViewController.m
//  Meridian
//
//  Created by Ben Sparkes on 22/12/2017.
//  Copyright © 2017 Ben Sparkes. All rights reserved.
//

#import "ViewController.h"
#import "v0rtex.h"
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
    NSString *verString = [[NSProcessInfo processInfo] operatingSystemVersionString];
    // wish there was a better way of doing this (hopefully there is)
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"14[A-Za-z0-9]{3,5}"
                                                                           options:0
                                                                             error:nil];
    NSRange range = [regex rangeOfFirstMatchInString:verString options:0 range:NSMakeRange(0, [verString length])];
    NSString *buildString = [verString substringWithRange:range];
    
    struct utsname u;
    uname(&u);
    
    [self writeTextPlain:[NSString stringWithFormat:@"> %@", Version]];
    
    [self writeTextPlain:[NSString stringWithFormat:@"> %s on iOS %ld.%ld.%ld (Build %@)",
                          u.machine,
                          (long)osVersion.majorVersion,
                          (long)osVersion.minorVersion,
                          (long)osVersion.patchVersion,
                          buildString]];
    
    if (osVersion.majorVersion != 10) {
        [self writeTextPlain:@"> Meridian does not work on versions of iOS other than iOS 10."];
        [self.goButton setHidden:YES];
        return;
    }
    
    // Load offsets
    if (load_offsets() != 0) {
        [self writeTextPlain:@"> Your device is not supported; no offsets were found."];
        [self writeTextPlain:@"> You will need to find your own offsets."];
        [self writeTextPlain:@"> Once found, send them to @iBSparkes on Twitter."];
        [self noOffsets];
        return;
    }
    
    if (!jailbreak_has_run) {
        [self writeTextPlain:@"> ready."];
    } else {
        [self writeTextPlain:@"> already jailbroken."];
        
        // set done button
        [self.goButton setTitle:@"done" forState:UIControlStateNormal];
    
        // aaaaand grey it out
        [self.goButton setEnabled:NO];
        self.goButton.alpha = 0.5;
    }
    
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
    
    if (jailbreak_has_run) {
        [self presentPopupSheet: sender];
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
        int ret = v0rtex(&tfp0, &kslide, &kern_ucred, &kernprocaddr);

        if (ret != 0)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self exploitFailed];
            });
            
            return;
        }
        
        [self writeTextPlain:@"exploit succeeded! praize siguza!"];
        
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
        int pre130 = osVersion.minorVersion < 3 ? 1 : 0;
        int mount_rt = mount_root(kslide, pre130);
        if (mount_rt != 0) {
            [self writeText:@"failed!"];
            [self writeTextPlain:[NSString stringWithFormat:@"ERROR: failed to remount '/' as r/w! (%d)", mount_rt]];
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
        // create dir's and files for dropbear
        if (file_exists("/meridian") != 0 ||
            file_exists("/etc/dropbear") != 0 ||
            file_exists("/var/log/lastlog") != 0 ||
            file_exists("/var/root/.profile") != 0) {
            [self writeText:@"setting up the envrionment..."];
            
            mkdir("/meridian", 0777);
            mkdir("/meridian/logs", 0777);
            
            mkdir("/etc", 0777);
            mkdir("/etc/dropbear", 0777);
            mkdir("/var", 0777);
            mkdir("/var/log", 0777);
            touch_file("/var/log/lastlog");
            
            if (![fileMgr fileExistsAtPath:@"/var/mobile/.profile"]) {
                [fileMgr createFileAtPath:@"/var/mobile/.profile"
                                 contents:[[NSString stringWithFormat:@"export PATH=/meridian/bins:$PATH"]
                                           dataUsingEncoding:NSASCIIStringEncoding]
                               attributes:nil];
            }
            
            if (![fileMgr fileExistsAtPath:@"/var/root/.profile"]) {
                [fileMgr createFileAtPath:@"/var/root/.profile"
                                 contents:[[NSString stringWithFormat:@"export PATH=/meridian/bins:$PATH"]
                                           dataUsingEncoding:NSASCIIStringEncoding]
                               attributes:nil];
            }
            
            [self writeText:@"done!"];
        }
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
        // nostash
        touch_file("/.cydia_no_stash");
        
        // install Cydia
        if (file_exists("/meridian/.cydia_installed") != 0 &&
            file_exists("/Applications/Cydia.app") != 0) {
            [self installCydia];
        }
    }
    
    {
        // Launch dropbear
        [self writeText:@"launching dropbear..."];
    
        rv = execprog("/meridian/bins/dropbear", (const char**)&(const char*[]) {
            "/meridian/bins/dropbear",
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
        // Injecting substitute and shit
        // this will all get replaced soon
        
        // Delete all the old shit 
        unlink("/meridian/injector");
        unlink("/meridian/pspawn_hook.dylib");
        unlink("/meridian/jailbreakd");
        unlink("/meridian/jailbreakd.plist");
        unlink("/meridian/SBInject.dylib");
        unlink("/usr/lib/SBInject.dylib");
        unlink("/usr/lib/libsubstitute.0.dylib");
        unlink("/usr/lib/libsubstitute.dylib");
        unlink("/usr/lib/libsubstrate.dylib");
        
        // Extract all the shit
        extract_bundle("injector.tar", "/meridian");
        extract_bundle("pspawn_hook.tar", "/meridian");
        extract_bundle("jailbreakd.tar", "/meridian");
        extract_bundle("SBInject.tar", "/usr/lib");
        extract_bundle("substitute.tar", "/usr/lib");
    
        // symlink a bunch of shit
        mkdir("/usr/lib/SBInject", 0755);
        mkdir("/Library/MobileSubstrate", 0755);
        symlink("/usr/lib/SBInject", "/Library/MobileSubstrate/DynamicLibraries");
        
        [fileMgr removeItemAtPath:@"/Library/Frameworks/CydiaSubstrate.framework" error:nil];
        mkdir("/Library/Frameworks/CydiaSubstrate.framework", 0755);
        symlink("/usr/lib/libsubstrate.dylib", "/Library/Frameworks/CydiaSubstrate.framework/CydiaSubstrate");
    }
    
    {
        // chuck our lib in trust cache so we don't have to
        // worry about team validation and shit
        inject_trust("/meridian/pspawn_hook.dylib");
        inject_trust("/meridian/bins/launchctl");
        inject_trust("/usr/lib/SBInject.dylib");
    }
    
    {
        [self writeText:@"starting jailbreakd..."];
        
        unlink("/var/tmp/jailbreakd.pid");
        
        NSData *blob = [NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"jailbreakd" ofType:@"plist"]];
        NSMutableDictionary *job = [NSPropertyListSerialization propertyListWithData:blob options:NSPropertyListMutableContainers format:nil error:nil];
        
        job[@"EnvironmentVariables"][@"KernelBase"] = [NSString stringWithFormat:@"0x%16llx", kernel_base];
        job[@"EnvironmentVariables"][@"KernProcAddr"] = [NSString stringWithFormat:@"0x%16llx", kernprocaddr];
        job[@"EnvironmentVariables"][@"ZoneMapOffset"] = [NSString stringWithFormat:@"0x%16llx", OFFSET_ZONE_MAP];
        [job writeToFile:@"/meridian/jailbreakd.plist" atomically:YES];
        chmod("/meridian/jailbreakd.plist", 0600);
        chown("/meridian/jailbreakd.plist", 0, 0);
        
        rv = execprog("/meridian/bins/launchctl", (const char **)&(const char*[]) {
            "/meridian/bins/launchctl",
            "load",
            "-w",
            "/meridian/jailbreakd.plist",
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
        
        int rv = execprog("/meridian/bins/launchctl", (const char **)&(const char*[]) {
            "/meridian/bins/launchctl",
            "load",
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

-(void) presentPopupSheet:(UIButton *)sender {
    UIAlertController *actionSheet = [UIAlertController alertControllerWithTitle:@"Advanced Options"
                                                                         message:@"Only run these if you specifically need to. "
                                                                                  "Only the 'Respring' option needs to be run after jailbreaking."
                                                                  preferredStyle:UIAlertControllerStyleActionSheet];
    
    [actionSheet addAction:[UIAlertAction actionWithTitle:@"Respring" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        pid_t springBoard = get_pid_for_name("backboardd");
        if (springBoard == 0) {
            [self writeText:@"Failed to respring."];
            return;
        }
        kill(springBoard, 9);
    }]];
    
    [actionSheet addAction:[UIAlertAction actionWithTitle:@"Force Re-install Cydia" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^(void) {
            [self installCydia];
        });
        
        [self dismissViewControllerAnimated:YES completion:nil];
    }]];
    
    [actionSheet addAction:[UIAlertAction actionWithTitle:@"Delete Cydia" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            [self uninstallCydia];
        });
    }]];
    
    [actionSheet addAction:[UIAlertAction actionWithTitle:@"Extract Dpkg" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^(void) {
            [self extractDpkg];
        });
        
        [self dismissViewControllerAnimated:YES completion:nil];
    }]];
    
    [actionSheet addAction:[UIAlertAction actionWithTitle:@"Re-extract Bootstrap" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^(void) {
            [self extractBootstrap];
        });
        
        [self dismissViewControllerAnimated:YES completion:nil];
    }]];
    
    [actionSheet addAction:[UIAlertAction actionWithTitle:@"Uninstall Meridian" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            [self uninstallMeridian];
        });
        
        [self dismissViewControllerAnimated:YES completion:nil];
    }]];
    
    [actionSheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
        [self dismissViewControllerAnimated:YES completion:nil];
    }]];
    
    [actionSheet.popoverPresentationController setPermittedArrowDirections:UIPopoverArrowDirectionAny];
    
    UIPopoverPresentationController *popPresender = [actionSheet popoverPresentationController];
    popPresender.sourceView = sender;
    popPresender.sourceRect = sender.bounds;
    
    [self presentViewController:actionSheet animated:YES completion:nil];
}

- (void)installCydia {
    [self writeText:@"installing cydia..."];
    
    int rv;
    
    // delete old Cydia.app
    if ([fileMgr fileExistsAtPath:@"/Applications/Cydia.app"] == YES)
    {
        [fileMgr removeItemAtPath:@"/Applications/Cydia.app" error:nil];
        
        rv = uicache();
        if (rv != 0) {
            [self writeText:@"failed!"];
            [self writeTextPlain:[NSString stringWithFormat:@"got value %d from uicache (1)", rv]];
            return;
        }
    }
    
    // delete our .tar if it already exists
    unlink("/meridian/cydia.tar");
    
    // copy the tar out
    cp(bundled_file("cydia.tar"), "/meridian/cydia.tar");
    
    // extract to /Applications
    chdir("/Applications");
    untar(fopen("/meridian/cydia.tar", "r+"), "cydia");
    
    // write the .cydia_installed file
    touch_file("/meridian/.cydia_installed");
    
    [self writeText:@"done!"];
    
    // run uicache
    [self writeText:@"running uicache..."];
    rv = uicache();
    if (rv != 0) {
        [self writeText:@"failed!"];
        [self writeTextPlain:[NSString stringWithFormat:@"got value %d from uicache (2)", rv]];
        return;
    }
    [self writeText:@"done!"];
    
    // enable showing of system apps on springboard
    // this is some funky killall stuff tho
    execprog("/meridian/bins/killall", (const char**)&(const char*[]) {
        "/meridian/bins/killall",
        "-SIGSTOP",
        "cfprefsd",
        NULL
    });
    NSMutableDictionary* md = [[NSMutableDictionary alloc] initWithContentsOfFile:@"/var/mobile/Library/Preferences/com.apple.springboard.plist"];
    [md setObject:[NSNumber numberWithBool:YES] forKey:@"SBShowNonDefaultSystemApps"];
    [md writeToFile:@"/var/mobile/Library/Preferences/com.apple.springboard.plist" atomically:YES];
    execprog("/meridian/bins/killall", (const char**)&(const char*[]) {
        "/meridian/bins/killall",
        "-9",
        "cfprefsd",
        NULL
    });
}

- (void)uninstallCydia {
    // delete Cydia.app
    [self writeText:@"deleting Cydia..."];
    [fileMgr removeItemAtPath:@"/Applications/Cydia.app" error:nil];
    [self writeText:@"done!"];
    
    // run uicache
    [self writeText:@"running uicache..."];
    int rv = uicache();
    if (rv != 0) {
        [self writeText:@"failed!"];
        [self writeTextPlain:[NSString stringWithFormat:@"got value %d from uicache", rv]];
        return;
    }
    [self writeText:@"done!"];
}

- (void)extractDpkg {
    [self writeText:@"extracting dpkg..."];
    
    // delete the tar if it already exists
    unlink("/meridian/dpkg.tar");
    
    // copy the tar out
    cp(bundled_file("dpkg.tar"), "/meridian/dpkg.tar");
    
    // extract dpkg.tar to '/'
    chdir("/");
    untar(fopen("/meridian/dpkg.tar", "r+"), "dpkg");
    
    [self writeText:@"done!"];
}

- (void)extractBootstrap {
    [self writeText:@"extracting bootstrap..."];
    
    // delete the bins dir
    [fileMgr removeItemAtPath:@"/meridian/bins" error:nil];
    
    // create the bins dir and extract the bootstrap.tar to /meridian(/bins)
    mkdir("/meridian/bins", 0777);
    chdir("/meridian/");
    untar(fopen(bundled_file("bootstrap.tar"), "r+"), "bootstrap");
    
    [self writeText:@"done!"];
}

- (void)uninstallMeridian {
    
    [self uninstallCydia];
    
    [self writeText:@"uninstalling Meridian..."];
    
    // delete '/meridian' dir
    [fileMgr removeItemAtPath:@"/meridian" error:nil];
    
    [self writeText:@"done!"];
    [self writeTextPlain:@"please delete the Meridian app and reboot to finish uninstallation."];
    [self writeTextPlain:@"goodbye!"];
}

- (void)exploitSucceeded {
    jailbreak_has_run = true;
    
    [self writeTextPlain:@"\n> your device has been freed! \n"];
    
    [self writeTextPlain:@"note: please click 'done' and click 'respring' to get this party started \n"];
    
    [self.progressSpinner stopAnimating];
    
    [self.goButton setEnabled:YES];
    [self.goButton setHidden:NO];
    [self.goButton setTitle:@"done" forState:UIControlStateNormal];
    
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
    uint32_t flags;
    int csops(pid_t pid, unsigned int  ops, void * useraddr, size_t usersize);
    csops(getpid(), 0, &flags, 0);
    
    return flags & CS_PLATFORM_BINARY;
}

// kinda dumb, kinda lazy, ¯\_(ツ)_/¯
void log_message(NSString *message) {
    [thisClass writeTextPlain:message];
}

@end
