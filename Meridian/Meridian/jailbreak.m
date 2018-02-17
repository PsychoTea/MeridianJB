//
//  jailbreak.m
//  Meridian
//
//  Created by Ben Sparkes on 16/02/2018.
//  Copyright © 2018 Ben Sparkes. All rights reserved.
//

#include "v0rtex.h"
#include "v0rtex-old.h"
#include "kernel.h"
#include "helpers.h"
#include "root-rw.h"
#include "amfi.h"
#include "offsets.h"
#include "jailbreak.h"
#include "ViewController.h"
#include "patchfinder64.h"
#include <mach/mach_types.h>
#include <sys/stat.h>
#import <Foundation/Foundation.h>

NSFileManager *fileMgr;

task_t tfp0;
uint64_t kslide;
uint64_t kernel_base;
uint64_t kern_ucred;
uint64_t kernprocaddr;

int makeShitHappen(ViewController *view) {
    int ret;
    
    fileMgr = [NSFileManager defaultManager];

    // run v0rtex
    [view writeText:@"running v0rtex..."];
    ret = runV0rtex();
    if (ret != 0) {
        [view writeText:@"failed!"];
        return 1;
    }
    [view writeText:@"succeeded! praize siguza!"];
    
    // set up stuff
    init_kernel(tfp0);
    init_patchfinder(tfp0, kernel_base, NULL);
    init_amfi();
    
    // patch containermanager
    [view writeText:@"patching containermanager..."];
    ret = patchContainermanagerd();
    if (ret != 0) {
        [view writeText:@"failed!"];
        return 1;
    }
    [view writeText:@"done!"];
    
    // remount root fs
    [view writeText:@"remount rootfs as r/w..."];
    ret = remountRootFs();
    if (ret != 0) {
        [view writeText:@"failed!"];
        return 1;
    }
    [view writeText:@"done!"];
    
    // extract bootstrap (if not already extracted)
    if (file_exists("/meridian/.bootstrap") != 0) {
    // if (true) {
        [view writeText:@"extracting bootstrap..."];
        ret = extractBootstrap();
        
        if (ret != 0) {
            [view writeText:@"failed!"];
            
            if (ret == 1) {
                [view writeTextPlain:@"failed to extract meridian-base.tar"];
            } else if (ret == 2) {
                [view writeTextPlain:@"failed to extract system-base.tar"];
            } else if (ret == 3) {
                [view writeTextPlain:@"failed to extract installer-base.tar"];
            } else if (ret == 4) {
                [view writeTextPlain:@"failed to extract dpkgdb-base.tar"];
            } else if (ret == 5) {
                [view writeTextPlain:@"failed to extract cydia-base.tar"];
            } else if (ret == 6) {
                [view writeTextPlain:@"failed to extract optional-base.tar"];
            }
            
            return 1;
        }
        
        [view writeText:@"done!"];
    }
    
    // TEMPORARY
    unlink("/usr/lib/SBInject.dylib");
    
    // touch .cydia_no_stash
    touch_file("/.cydia_no_stash");
    
    // patch amfid
    [view writeText:@"patching amfid..."];
    ret = defecate_amfi();
    if (ret != 0) {
        [view writeText:@"failed!"];
        return 1;
    }
    [view writeText:@"done!"];
    
    // launch dropbear
    [view writeText:@"launching dropbear..."];
    ret = launchDropbear();
    if (ret != 0) {
        [view writeText:@"failed!"];
        return 1;
    }
    [view writeText:@"done!"];
    
    // link substitute stuff
    setUpSubstitute();
    
    // start jailbreakd
    [view writeText:@"starting jailbreakd..."];
    ret = startJailbreakd();
    if (ret != 0) {
        [view writeText:@"failed"];
        return 1;
    }
    [view writeText:@"done!"];
    
    // load launchdaemons
    [view writeText:@"loading launchdaemons..."];
    ret = loadLaunchDaemons();
    if (ret != 0) {
        [view writeText:@"failed!"];
        return 1;
    }
    [view writeText:@"done!"];
    
    return 0;
}

int runV0rtex() {
    int ret = v0rtex(&tfp0, &kslide, &kern_ucred, &kernprocaddr);

    kernel_base = 0xFFFFFFF007004000 + kslide;
    
    if (ret == 0) {
        NSLog(@"tfp0: 0x%x", tfp0);
        NSLog(@"kernel_base: 0x%llx", kernel_base);
        NSLog(@"kslide: 0x%llx", kslide);
        NSLog(@"kern_ucred: 0x%llx", kern_ucred);
        NSLog(@"kernprocaddr: 0x%llx", kernprocaddr);
    }
    
    return ret;
}

int patchContainermanagerd() {
    uint64_t cmgr = find_proc_by_name("containermanager");
    if (cmgr == 0) {
        NSLog(@"unable to find containermanager!");
        return 1;
    }
    
    wk64(cmgr + 0x100, kern_ucred);
    return 0;
}

int remountRootFs() {
    NSOperatingSystemVersion osVersion = [[NSProcessInfo processInfo] operatingSystemVersion];
    int pre130 = osVersion.minorVersion < 3 ? 1 : 0;
    
    int rv = mount_root(kslide, pre130);
    if (rv != 0) {
        return 1;
    }
    
    rv = can_write_root();
    if (rv != 0) {
        return 1;
    }
    
    return 0;
}

int extractBootstrap() {
    int rv;
    
    // merk old /meridian folder
    [fileMgr removeItemAtPath:@"/meridian" error:nil];
    
    mkdir("/meridian", 0755);
    mkdir("/meridian/logs", 0755);
    
    // extract tar
    extract_bundle("tar.tar", "/meridian");
    chmod("/meridian/tar", 0755);
    inject_trust("/meridian/tar");
    
    // extract meridian-base.tar
    rv = extract_bundle_tar("meridian-base.tar");
    if (rv != 0) return 1;
    
    // extract system-base.tar
    rv = extract_bundle_tar("system-base.tar");
    if (rv != 0) return 2;
    
    // extract installer-base.tar
    rv = extract_bundle_tar("installer-base.tar");
    if (rv != 0) return 3;
    
    // set up dpkg database
    // if dpkg is already installed (previously jailbroken), we want to move the database
    // over to the new location, rather than replacing it. this allows users to retain
    // tweaks and installed package information
    struct stat file;
    lstat("/private/var/lib/dpkg", &file);
    if (!S_ISLNK(file.st_mode)) {
        [fileMgr removeItemAtPath:@"/Library/dpkg" error:nil];
        [fileMgr moveItemAtPath:@"/private/var/lib/dpkg" toPath:@"/Library/dpkg" error:nil];
    } else {
        // extract dpkgdb-base.tar
        rv = extract_bundle_tar("dpkgdb-base.tar");
        if (rv != 0) return 4;
    }
    symlink("/Library/dpkg", "/private/var/lib/dpkg");
    
    // extract cydia-base.tar
    rv = extract_bundle_tar("cydia-base.tar");
    if (rv != 0) return 5;
    
    // extract optional-base.tar
    rv = extract_bundle_tar("optional-base.tar");
    if (rv != 0) return 6;
    
    unlink("/meridian/tar");
    
    inject_trust("/usr/bin/killall");
    enableHiddenApps();
    
    touch_file("/meridian/.bootstrap");
    
    //            inject_trust("/bin/uicache");
    //            rv = uicache();
    //            if (rv != 0) {
    //                [self writeText:@"failed!"];
    //                [self writeTextPlain:[NSString stringWithFormat:@"uicache returned %d", rv]];
    //                return 1;
    //            }
    
    return 0;
}

int launchDropbear() {
    inject_trust("/bin/launchctl");
    
    return start_launchdaemon("/meridian/dropbear/dropbear.plist");
}

void setUpSubstitute() {
    // create /Library/MobileSubstrate/DynamicLibraries
    if (file_exists("/Library/MobileSubstrate/DynamicLibraries") == 0) {
        mkdir("/Library/MobileSubstrate", 0755);
        mkdir("/Library/MobileSubstrate/DynamicLibraries", 0755);
    }
    
    // link CydiaSubstrate.framework -> /usr/lib/libsubstrate.dylib
    if (file_exists("/Library/Frameworks/CydiaSubstrate.framework") == 0) {
        [fileMgr removeItemAtPath:@"/Library/Frameworks/CydiaSubstrate.framework" error:nil];
    }
    mkdir("/Library/Frameworks", 0755);
    mkdir("/Library/Frameworks/CydiaSubstrate.framework", 0755);
    symlink("/usr/lib/libsubstrate.dylib", "/Library/Frameworks/CydiaSubstrate.framework/CydiaSubstrate");
}

int startJailbreakd() {
    inject_trust("/meridian/pspawn_hook.dylib");
    inject_trust("/usr/lib/TweakLoader.dylib");
    
    unlink("/var/tmp/jailbreakd.pid");
    
    NSData *blob = [NSData dataWithContentsOfFile:@"/meridian/jailbreakd/jailbreakd.plist"];
    NSMutableDictionary *job = [NSPropertyListSerialization propertyListWithData:blob options:NSPropertyListMutableContainers format:nil error:nil];
    
    job[@"EnvironmentVariables"][@"KernelBase"] = [NSString stringWithFormat:@"0x%16llx", kernel_base];
    job[@"EnvironmentVariables"][@"KernProcAddr"] = [NSString stringWithFormat:@"0x%16llx", kernprocaddr];
    job[@"EnvironmentVariables"][@"ZoneMapOffset"] = [NSString stringWithFormat:@"0x%16llx", OFFSET_ZONE_MAP];
    [job writeToFile:@"/meridian/jailbreakd/jailbreakd.plist" atomically:YES];
    chmod("/meridian/jailbreakd/jailbreakd.plist", 0600);
    chown("/meridian/jailbreakd/jailbreakd.plist", 0, 0);
    
    int rv = start_launchdaemon("/meridian/jailbreakd/jailbreakd.plist");
    if (rv != 0) return 1;
    
    while (!file_exist("/var/tmp/jailbreakd.pid")) {
        printf("Waiting for jailbreakd \n");
        usleep(300000); // 300ms
    }
    
    // inject pspawn_hook.dylib to launchd
    rv = inject_library(1, "/meridian/pspawn_hook.dylib");
    if (rv != 0) return 2;
    
    return 0;
}

int loadLaunchDaemons() {
    NSArray *daemons = [fileMgr contentsOfDirectoryAtPath:@"/Library/LaunchDaemons" error:nil];
    for (NSString *file in daemons) {
        NSString *path = [NSString stringWithFormat:@"/Library/LaunchDaemons/%@", file];
        NSLog(@"found launchdaemon: %@", path);
        chmod([path UTF8String], 0755);
        chown([path UTF8String], 0, 0);
    }
    
    return start_launchdaemon("/Library/LaunchDaemons");
}

void enableHiddenApps() {
    // enable showing of system apps on springboard
    // this is some funky killall stuff tho
    killall("cfprefsd", "-SIGSTOP");
    NSMutableDictionary* md = [[NSMutableDictionary alloc] initWithContentsOfFile:@"/var/mobile/Library/Preferences/com.apple.springboard.plist"];
    [md setObject:[NSNumber numberWithBool:YES] forKey:@"SBShowNonDefaultSystemApps"];
    [md writeToFile:@"/var/mobile/Library/Preferences/com.apple.springboard.plist" atomically:YES];
    killall("cfprefsd", "-9");
}
