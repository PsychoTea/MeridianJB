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
@end

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
    
    _goButton.layer.cornerRadius = 5;
    _creditsButton.layer.cornerRadius = 5;
    _websiteButton.layer.cornerRadius = 5;
    _sourceButton.layer.cornerRadius = 5;
    
    // Log current device and version info
    NSOperatingSystemVersion ver = [[NSProcessInfo processInfo] operatingSystemVersion];
    NSString *verString = [[NSProcessInfo processInfo] operatingSystemVersionString];
    struct utsname u;
    uname(&u);
    
    [self writeTextPlain:[NSString stringWithFormat:@"> found %s on iOS %@", u.machine, verString]];
    
    if (ver.majorVersion != 10) {
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
    
    if (ver.minorVersion < 3) {
        [self writeTextPlain:@"WARNING: Meridian is UNTESTED on versions lower than iOS 10.3. It should work (in theory), but may bootloop your device. Proceeed at your own risk."];
    }
    
    [self writeTextPlain:@"> ready."];
    
    printf("App bundle directory: %s \n", bundle_path());
}

- (IBAction)goButtonPressed:(UIButton *)sender {
    
    if (jailbreak_has_run) {
        [self presentPopupSheet];
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
    // [self.sourceButton setEnabled:NO];
    // self.sourceButton.alpha = 0.5;
    [self.progressSpinner startAnimating];
    
    // background thread so we can update the UI
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^(void) {
        
        // run v0rtex itself
        int ret = v0rtex(&v0rtex_callback, NULL);

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

kern_return_t v0rtex_callback(task_t task_for_port0,
                              kptr_t kbase,
                              kptr_t kernucred,
                              kptr_t kernproc_addr) {
    host_t host = mach_host_self();
    mach_port_t name = MACH_PORT_NULL;
    kern_return_t ret = processor_set_default(host, &name);
    LOG("processor_set_default: %s", mach_error_string(ret));
    if(ret == KERN_SUCCESS)
    {
        mach_port_t priv = MACH_PORT_NULL;
        ret = host_processor_set_priv(host, name, &priv);
        LOG("host_processor_set_priv: %s", mach_error_string(ret));
        if(ret == KERN_SUCCESS)
        {
            task_array_t tasks;
            mach_msg_type_number_t num;
            ret = processor_set_tasks(priv, &tasks, &num);
            LOG("processor_set_tasks: %u, %s", num, mach_error_string(ret));
        }
    }
    
    tfp0 = task_for_port0;
    kernel_base = kbase;
    kern_ucred = kernucred;
    kernprocaddr = kernproc_addr;
    
    return KERN_SUCCESS;
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
    
    kslide = kernel_base - 0xFFFFFFF007004000;
    
    printf("tfp0: %x \n", tfp0);
    printf("kslide: %llx \n", kslide);
    printf("kernel_base: %llx \n", kernel_base);
    printf("kern_ucred: %llx \n", kern_ucred);
    printf("kernprocaddr = %llx \n", kernprocaddr);
    
    {
        // set up stuff
        init_patchfinder(tfp0, kernel_base, NULL);
        init_amfi(tfp0);
        init_kernel(tfp0);
    }
    
    {
        // remount '/' as r/w
        [self writeText:@"remounting '/' as r/w..."];
        rv = mount_root(tfp0, kslide);
        LOG("remount: %d", rv);
        if (rv != 0) {
            [self writeText:@"failed!"];
            [self writeTextPlain:[NSString stringWithFormat:@"ERROR: failed to remount '/' as r/w! (%d)", rv]];
            return 1;
        }
     
        // check we can write to root
        if (can_write_root() != 0) {
            [self writeTextPlain:@"failed!"];
            [self writeTextPlain:@"note, this is currently not working on <10.3."];
            return 1;
        }
        
        [self writeText:@"done!"];
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
        
        rv = patch_amfi();
        if (rv != 0) {
            [self writeText:@"failed!"];
            [self writeTextPlain:[NSString stringWithFormat:@"got error %d for amfi patch.", rv]];
            return 1;
        }
        
        [self writeText:@"done!"];
    }
    
    // init filemanager
    NSFileManager *fileMgr = [NSFileManager defaultManager];
    
    {
        // uncomment if we wanna replace shit
//        [self writeText:@"removing old files..."];
//        [fileMgr removeItemAtPath:@"/meridian/bins" error:nil];
        [fileMgr removeItemAtPath:@"/meridian/cydia.tar" error:nil];
//        [fileMgr removeItemAtPath:@"/meridian/bootstrap.tar" error:nil];
//        [fileMgr removeItemAtPath:@"/meridian/dropbear" error:nil];
        [fileMgr removeItemAtPath:@"/meridian/dpkg.tar" error:nil];
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
        fclose(fopen("/var/log/lastlog", "ab+"));
        [self writeText:@"done!"];
    }
    
    {
        // nostash
        touch_file("/.cydia_no_stash", 0644);
        
        // install Cydia
        if (file_exists("/meridian/.cydia_installed") != 0 &&
            file_exists("/Applications/Cydia.app") != 0)
        {
            [self installCydia];
        }
    }
    
    {
        // create .profile files
        
        [self writeText:@"creating .profile files..."];
        
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
        // trust dropbear & sh (idk why we still need to do this, *shrug*)
        [self writeText:@"trusting files..."];
        inject_trust("/meridian/bins/dropbear");
        inject_trust("/bin/sh");
        [self writeText:@"done!"];
    }
    
    {
        // Launch dropbear
        [self writeText:@"launching dropbear..."];
        
        rv = execprog(kern_ucred, "/meridian/bins/dropbear", (const char**)&(const char*[]) {
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

-(void) presentPopupSheet {
    UIAlertController *actionSheet = [UIAlertController alertControllerWithTitle:@"Custom Options"
                                                                         message:nil
                                                                  preferredStyle:UIAlertControllerStyleActionSheet];
    
    [actionSheet addAction:[UIAlertAction actionWithTitle:@"Force Reinstall Cydia" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^(void) {
            [self installCydia];
        });
        
        [self dismissViewControllerAnimated:YES completion:nil];
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
    
    [actionSheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
        [self dismissViewControllerAnimated:YES completion:nil];
    }]];
    
    [actionSheet.popoverPresentationController setPermittedArrowDirections:0];
    
    CGRect rect = self.view.frame;
    rect.origin.x = self.view.frame.size.width / 20;
    rect.origin.y = self.view.frame.size.height / 20;
    actionSheet.popoverPresentationController.sourceView = self.view;
    actionSheet.popoverPresentationController.sourceRect = rect;
    
    [self presentViewController:actionSheet animated:YES completion:nil];
}

- (void)installCydia {
    [self writeText:@"installing cydia..."];
    
    int rv;
    NSFileManager *fileMgr = [NSFileManager defaultManager];
    
    // delete old cydia
    if ([fileMgr fileExistsAtPath:@"/Applications/Cydia.app"] == YES)
    {
        [fileMgr removeItemAtPath:@"/Applications/Cydia.app" error:nil];
        
        rv = execprog(0, "/meridian/bins/uicache", NULL);
        if (rv != 0) {
            [self writeText:@"failed!"];
            [self writeTextPlain:[NSString stringWithFormat:@"got value %d from uicache (1)", rv]];
            return;
        }
    }
    
    // copy the tar out
    cp(bundled_file("cydia.tar"), "/meridian/cydia.tar");
    
    // extract to /Applications
    chdir("/Applications");
    untar(fopen("/meridian/cydia.tar", "r+"), "cydia");
    
    // write the .cydia_installed file
    touch_file("/meridian/.cydia_installed", 0644);
    
    [self writeText:@"done!"];
    
    // run uicache
    [self writeText:@"running uicache..."];
    rv = execprog(0, "/meridian/bins/uicache", NULL);
    if (rv != 0) {
        [self writeText:@"failed!"];
        [self writeTextPlain:[NSString stringWithFormat:@"got value %d from uicache (2)", rv]];
        return;
    }
    [self writeText:@"done!"];
}

- (void)extractDpkg {
    [self writeText:@"extracting dpkg..."];
    
    // copy the tar out
    cp(bundled_file("dpkg.tar"), "/meridian/dpkg.tar");
    
    // extract
    chdir("/");
    untar(fopen("/meridian/dpkg.tar", "r+"), "dpkg");
    
    [self writeText:@"done!"];
}

- (void)extractBootstrap {
    [self writeText:@"extracting bootstrap..."];
    
    unlink("/meridian/bins");
    
    mkdir("/meridian/bins", 0777);
    chdir("/meridian/");
    untar(fopen(bundled_file("bootstrap.tar"), "r+"), "bootstrap");
    
    [self writeText:@"done!"];
}

- (void)exploitSucceeded {
    jailbreak_has_run = true;
    
    [self writeTextPlain:@"\n> your device has been freed!\n"];
    
    [self.progressSpinner stopAnimating];
    
    [self.goButton setEnabled:YES];
    [self.goButton setHidden:NO];
    [self.goButton setTitle:@"done" forState:UIControlStateNormal];
    
    [self.creditsButton setEnabled:YES];
    self.creditsButton.alpha = 1;
    [self.websiteButton setEnabled:YES];
    self.websiteButton.alpha = 1;
    // [self.sourceButton setEnabled:YES];
    // self.sourceButton.alpha = 1;
}

- (void)exploitFailed {
    [self writeTextPlain:@"exploit failed. please try again. \n"];
    
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

- (void)noOffsets {
    [self.goButton setEnabled:NO];
    self.goButton.alpha = 0.5;
    [self.goButton setTitle:@"no offsets" forState:UIControlStateNormal];
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
    });
}

// kinda dumb, kinda lazy, ¯\_(ツ)_/¯
void log_message(NSString *message) {
    [thisClass writeTextPlain:message];
}

@end
