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
#include <stdio.h>
#include <unistd.h>

// For '/' remount (not offsets)
#define KSTRUCT_OFFSET_MOUNT_MNT_FLAG   0x70
#define KSTRUCT_OFFSET_VNODE_V_UN       0xd8

// props to xerub for the original '/' r/w remount code
int mount_root(task_t tfp0, uint64_t kslide) {
    uint64_t _rootnode = OFFSET_ROOTVNODE + kslide;
    uint64_t rootfs_vnode = rk64(_rootnode);
    
    // read the original flags
    uint64_t v_mount = rk64(rootfs_vnode + KSTRUCT_OFFSET_VNODE_V_UN);
    uint32_t v_flag = rk32(v_mount + KSTRUCT_OFFSET_MOUNT_MNT_FLAG + 1);
    
    // unset rootfs flag
    wk32(v_mount + KSTRUCT_OFFSET_MOUNT_MNT_FLAG + 1, v_flag & ~(MNT_ROOTFS >> 8));
    
    // remount
    char *nmz = strdup("/dev/disk0s1s1");
    kern_return_t rv = mount("hfs", "/", MNT_UPDATE, (void *)&nmz);
    
    // set original flags back
    v_mount = rk64(rootfs_vnode + KSTRUCT_OFFSET_VNODE_V_UN);
    wk32(v_mount + KSTRUCT_OFFSET_MOUNT_MNT_FLAG + 1, v_flag);
    
    return rv;
}

int can_write_root() {
    return access("/", W_OK);
}
