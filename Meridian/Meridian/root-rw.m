//
//  root-rw.m
//  Meridian
//
//  Created by Ben Sparkes on 16/12/2017.
//  Copyright © 2017 Ben Sparkes. All rights reserved.
//

#include "root-rw.h"
#include "kernel.h"
#include "offsets.h"
#include "patchfinder64.h"
#include "ViewController.h"
#include <stdio.h>
#include <unistd.h>
#include <sys/utsname.h>

#define MOUNT_MNT_FLAG    0x71
#define VNODE_V_UN        0xd8
#define VNODE_V_UN_OTHER  0xd0

uint64_t get_vnode_off() {
    uint64_t off = VNODE_V_UN;
    struct utsname uts;
    uname(&uts);
    if (strstr(uts.version, "16.0.0")) {
        off = VNODE_V_UN_OTHER;
    }
    return off;
}

// props to xerub for the original '/' r/w remount code
int mount_root(uint64_t kslide, int pre130) {
    uint64_t lwvm_addr = 0;
    uint64_t lwvm_orig_value = 0;
    
    uint64_t _rootnode = OFFSET_ROOTVNODE + kslide;
    
    if (pre130) {
        // _rootnode -= 0x48000;
        _rootnode = find_gPhysBase() + 0x38;
    
        // patch lwvm
        lwvm_addr = find_lwvm_mapio_patch();           // grab the patch addr
        NSLog(@"lwvm_addr = %llx", lwvm_addr);
        lwvm_orig_value = rk64(lwvm_addr);             // save the original value
        NSLog(@"lwvm_orig_value = %llx", lwvm_orig_value);
        uint64_t lwvm_value = find_lwvm_mapio_newj();  // get the value to write
        NSLog(@"lwvm_vlaue = %llx", lwvm_value);
        wk64(lwvm_addr, lwvm_value);                   // write it!
    }
    
    NSLog(@"offset = %llx", OFFSET_ROOTVNODE + kslide);
    NSLog(@"_rootnode = %llx", _rootnode);
    
    uint64_t rootfs_vnode = rk64(_rootnode);
    
    uint64_t vnode_off = get_vnode_off();
    
    // read the original flags
    uint64_t v_mount = rk64(rootfs_vnode + vnode_off);
    uint32_t v_flag = rk32(v_mount + MOUNT_MNT_FLAG);
    
    // unset rootfs flag
    wk32(v_mount + MOUNT_MNT_FLAG, v_flag & ~(MNT_ROOTFS >> 8));
    
    // remount
    char *nmz = strdup("/dev/disk0s1s1");
    kern_return_t rv = mount("hfs", "/", MNT_UPDATE, (void *)&nmz);
    NSLog(@"remounting: %d", rv);
    
    // set original flags back
    v_mount = rk64(rootfs_vnode + vnode_off);
    wk32(v_mount + MOUNT_MNT_FLAG, v_flag);
    
    if (pre130) {
        // unpatch lwvm
        wk64(lwvm_addr, lwvm_orig_value);
        NSLog(@"wrote back old value of %llx to %llx", lwvm_orig_value, lwvm_addr);
    }
    
    return rv;
}

int can_write_root() {
    return access("/", W_OK);
}
