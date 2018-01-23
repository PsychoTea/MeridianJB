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
@property (weak, nonatomic) IBOutlet UIButton *sourceButton;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *progressSpinner;
@property (weak, nonatomic) IBOutlet UITextView *textArea;
@property (weak, nonatomic) IBOutlet UILabel *versionLabel;
@end

NSString *Version = @"Meridian: Internal Beta 6";
NSFileManager *fileMgr;
NSOperatingSystemVersion osVersion;

id thisClass;
task_t tfp0;
kptr_t kslide;
kptr_t kernel_base;
kptr_t kern_ucred;
kptr_t kernprocaddr;

bool jailbreak_has_run = false;

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    thisClass = self;
    
    fileMgr = [NSFileManager defaultManager];
    
    _goButton.layer.cornerRadius = 5;
    _creditsButton.layer.cornerRadius = 5;
    _websiteButton.layer.cornerRadius = 5;
    _sourceButton.layer.cornerRadius = 5;
    
    [_versionLabel setText:Version];
    
    // Log current device and version info
    osVersion = [[NSProcessInfo processInfo] operatingSystemVersion];
    NSString *verString = [[NSProcessInfo processInfo] operatingSystemVersionString];
    struct utsname u;
    uname(&u);
    
    [self writeTextPlain:[NSString stringWithFormat:@"> %@", Version]];
    
    [self writeTextPlain:[NSString stringWithFormat:@"> found %s on iOS %@", u.machine, verString]];
    
    if (osVersion.majorVersion != 10) {
        [self writeTextPlain:@"> Meridian does not work on versions of iOS other than iOS 10."];
        [self.goButton setHidden:YES];
        return;
    }
    
    // Load offsets
    if (load_offsets() != 0) {
        [self writeTextPlain:@"> Your device is not supported; no offsets were found."];
        [self writeTextPlain:@"> Please report this to @iBSparkes on Twitter."];
        [self writeTextPlain:@"> Make sure to include a screenshot of this page."];
        [self noOffsets];
        return;
    }
    
    if (osVersion.minorVersion < 3) {
        [self writeTextPlain:@"WARNING: Meridian is currently broken on versions below iOS 10.3. Stay tuned for updates."];
    }
    
    [self writeTextPlain:@"> ready."];
    
    NSLog(@"App bundle directory: %s \n", bundle_path());
}

- (void)viewDidAppear:(BOOL)animated {
    if ([fucksigningservices appIsPirated:[NSString stringWithUTF8String:bundled_file("embedded.mobileprovision")]]) {
        // app is pirated, fuckers
        DRMController *drmController = [self.storyboard instantiateViewControllerWithIdentifier:@"DRMController"];
        [self presentViewController:drmController animated:YES completion:nil];
        return;
    }
}

kern_return_t cb(task_t tfp0, kptr_t kbase, void *data) {
    kernel_base = kbase;
    NSLog(@"Got v0rtex_callback!");
    return KERN_SUCCESS;
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
//    [self.sourceButton setEnabled:NO];
//    self.sourceButton.alpha = 0.5;
    [self.progressSpinner startAnimating];
    
    // background thread so we can update the UI
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^(void) {
        
        // run v0rtex itself
        int ret = v0rtex(&tfp0, &kslide, &kern_ucred, &kernprocaddr);
        // int ret = v0rtex(&cb, NULL, &tfp0, &kslide, &kern_ucred);
        
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

- (IBAction)sourceButtonPressed:(UIButton *)sender {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://github.com/PsychoTea/MeridianJB"]
                                       options:@{}
                             completionHandler:nil];
}

-(int) makeShitHappen {
    int rv;
    
    //               kernel base     + aslr kern offset
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
        // patch containermanagerd
        
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
        if (pre130) {
            [self writeTextPlain:@"is pre-130"];
        }
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
            [self writeTextPlain:@"note, this is currently not working on <10.3."];
            return 1;
        }
        
        [self writeText:@"done!"];
        [self writeTextPlain:[NSString stringWithFormat:@"root remount returned %d & %d", mount_rt, rv]];
    }
    
    {
        // create dirs for meridian
        if (file_exists("/meridian") != 0) {
            [self writeText:@"creating /meridian directory..."];
            mkdir("/meridian", 0777);
            mkdir("/meridian/logs", 0777);
            [self writeText:@"done!"];
        }
    }
    
    {
        // patch amfi
        
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
        // uncomment if we wanna replace shit
//        [self writeText:@"removing old files..."];
//        [fileMgr removeItemAtPath:@"/meridian/bins" error:nil];
//        [fileMgr removeItemAtPath:@"/meridian/cydia.tar" error:nil];
//        [fileMgr removeItemAtPath:@"/meridian/bootstrap.tar" error:nil];
//        [fileMgr removeItemAtPath:@"/meridian/dropbear" error:nil];
//        [fileMgr removeItemAtPath:@"/meridian/dpkg.tar" error:nil];
//        [fileMgr removeItemAtPath:@"/meridian/tar" error:nil];
//        [fileMgr removeItemAtPath:@"/bin/sh" error:nil];
//        [self writeText:@"done!"];
    }
    
    {
        // copy in our bins and shit
        [self writeText:@"copying bins..."];
        
        if ([fileMgr fileExistsAtPath:@"/meridian/bins"] == NO)
        {
            [self extractBootstrap];
        }
        
        // unpack bash (dropbear requires it be called 'sh', so)
        if ([fileMgr fileExistsAtPath:@"/bin/sh"] == NO)
        {
            [fileMgr copyItemAtPath:@"/meridian/bins/bash"
                             toPath:@"/bin/sh"
                              error:nil];
        }
        
        [self writeText:@"done!"];
    }
    
    {
        // create dir's and files for dropbear
        [self writeText:@"setting up the envrionment..."];
        
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
    
    {
        // nostash
        touch_file("/.cydia_no_stash");
        
        // install Cydia
        if (file_exists("/meridian/.cydia_installed") != 0 &&
            file_exists("/Applications/Cydia.app") != 0)
        {
            [self installCydia];
        }
    }
    
    {
        // amfid patch takes a moment to come into effect, and
        // i cba to wait, so we'll just trust these manually
        [self writeText:@"trusting files..."];
        inject_trust("/meridian/bins/dropbear");
        inject_trust("/bin/sh");
        [self writeText:@"done!"];
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
            [self writeTextPlain:[NSString stringWithFormat:@"got value %d from posix_spawn", rv]];
            return 1;
        }
        
        [self writeText:@"done!"];
    }
    
    return 0;
}

-(void) presentPopupSheet:(UIButton *)sender {
    // set up alert sheet
    UIAlertController *actionSheet = [UIAlertController alertControllerWithTitle:@"Advanced Options"
                                                                         message:@"Only run these if you specifically need to. These do NOT need to be run after jailbreaking."
                                                                  preferredStyle:UIAlertControllerStyleActionSheet];
    
    // add some actions and tings
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
    
    // set that arrow and direction ← → ↑ ↓
    [actionSheet.popoverPresentationController setPermittedArrowDirections:UIPopoverArrowDirectionAny];
    
    // set the position of the sheet so it doesn't die on iPad (lol thx appl)
    UIPopoverPresentationController *popPresender = [actionSheet popoverPresentationController];
    popPresender.sourceView = sender;
    popPresender.sourceRect = sender.bounds;
    
    // pop that sheet
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
    
    [self writeTextPlain:@"note: please click 'done' and click 'extract dpkg' if you wish to fix Cydia not opening. \n"];
    
    [self.progressSpinner stopAnimating];
    
    [self.goButton setEnabled:YES];
    [self.goButton setHidden:NO];
    [self.goButton setTitle:@"done" forState:UIControlStateNormal];
    
    [self.creditsButton setEnabled:YES];
    self.creditsButton.alpha = 1;
    [self.websiteButton setEnabled:YES];
    self.websiteButton.alpha = 1;
//    [self.sourceButton setEnabled:YES];
//    self.sourceButton.alpha = 1;
}

- (void)exploitFailed {
    [self writeTextPlain:@"exploit failed. please try again. \n"];
    
    [self.goButton setEnabled:YES];
    [self.goButton setHidden:NO];
    [self.creditsButton setEnabled:YES];
    self.creditsButton.alpha = 1;
    [self.websiteButton setEnabled:YES];
    self.websiteButton.alpha = 1;
//    [self.sourceButton setEnabled:YES];
//    self.sourceButton.alpha = 1;
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

// this is lazy af,
// i suck at (Obj)C
void log_message(NSString *message) {
    [thisClass writeTextPlain:message];
}

@end
