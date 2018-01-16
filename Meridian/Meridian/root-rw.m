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

// props to xerub for the original '/' r/w remount code
int mount_root(task_t tfp0, uint64_t kslide) {
    uint64_t _rootnode = OFFSET_ROOTVNODE + kslide;
    
    NSLog(@"offset = %llx", OFFSET_ROOTVNODE);
    NSLog(@"_rootnode = %llx", _rootnode);
    
    // uint64_t _rootnode = OFFSET_ROOTVNODE + kslide;
    uint64_t rootfs_vnode = rk64(_rootnode);
    
    uint64_t off = VNODE_V_UN;
    struct utsname uts;
    uname(&uts);
    if (strstr(uts.version, "16.0.0")) {
        off = VNODE_V_UN_OTHER;
    }
    
    // read the original flags
    uint64_t v_mount = rk64(rootfs_vnode + off);
    uint32_t v_flag = rk32(v_mount + MOUNT_MNT_FLAG);
    
    // unset rootfs flag
    wk32(v_mount + MOUNT_MNT_FLAG, v_flag & ~(MNT_ROOTFS >> 8));
    
    // remount
    char *nmz = strdup("/dev/disk0s1s1");
    kern_return_t rv = mount("hfs", "/", MNT_UPDATE, (void *)&nmz);
    NSLog(@"remounting: %d", rv);
    
    // set original flags back
    v_mount = rk64(rootfs_vnode + off);
    wk32(v_mount + MOUNT_MNT_FLAG, v_flag);
    
    return rv;
}

int can_write_root() {
    return access("/", W_OK);
}
