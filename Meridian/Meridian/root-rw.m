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
#include "helpers.h"
#include "ViewController.h"
#include <stdio.h>
#include <unistd.h>
#include <sys/utsname.h>

#define MOUNT_MNT_FLAG    0x71
#define VNODE_V_UN        0xd8
#define VNODE_V_UN_OTHER  0xd0


const unsigned OFF_LWVM__PARTITIONS = 0x1a0;
const unsigned OFF_LWVMPART__ISWP = 0x28;
const unsigned OFF_PROC__TASK = 0x18;
const unsigned OFF_IPC_PORT__IP_KOBJECT = 0x68;
const unsigned OFF_IPC_SPACE__IS_TABLE = 0x20;
const unsigned SIZ_IPC_ENTRY_T = 0x18;
const unsigned OFF_TASK__ITK_SPACE = 0x300;

#define rkbuffer(w, p, s) tfp0_kread(w, p, s);
#define wkbuffer(w, p, s) kwrite(w, p, s);

typedef mach_port_t io_service_t;
typedef mach_port_t io_connect_t;
extern const mach_port_t kIOMasterPortDefault;
CFMutableDictionaryRef IOServiceMatching(const char *name) CF_RETURNS_RETAINED;
io_service_t IOServiceGetMatchingService(mach_port_t masterPort, CFDictionaryRef matching CF_RELEASES_ARGUMENT);
kern_return_t IOServiceOpen(io_service_t service, task_port_t owningTask, uint32_t type, io_connect_t *connect);

uint64_t ktask_self_addr(void) {
    uint64_t cached = 0;

    if (cached == 0) {
        uint64_t self_proc = find_proc_by_pid(getpid());
        cached = rk64(self_proc + OFF_PROC__TASKMeridian/Meridian/amfid.tar);
    }

    return cached;
}

// from Ian Beer's find_port.c
uint64_t find_port_address(mach_port_name_t port) {
    uint64_t task_addr = ktask_self_addr();
    uint64_t itk_space = rk64(task_addr + OFF_TASK__ITK_SPACE);
    uint64_t is_table = rk64(itk_space + OFF_IPC_SPACE__IS_TABLE);

    uint32_t port_index = port >> 8;
    uint64_t port_addr = rk64(is_table + (port_index * SIZ_IPC_ENTRY_T));
    return port_addr;
}

bool fix_root_iswriteprotected(void) {
    io_service_t service = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("LightweightVolumeManager"));
    if (!MACH_PORT_VALID(service)) return false;

    uint64_t inkernel = find_port_address(service);

    uint64_t lwvm_kaddr = rk64(inkernel + OFF_IPC_PORT__IP_KOBJECT);
    uint64_t rootp_kaddr = rk64(lwvm_kaddr + OFF_LWVM__PARTITIONS);
    uint64_t rootp_iswp_addr = rootp_kaddr + OFF_LWVMPART__ISWP;
    // assert(rk64(rootp_iswp_addr) == 1)
    wk64(rootp_iswp_addr, 0);
    return true;
}

bool fake_rootedramdisk(void) {
    unsigned cmdline_offset;
    uint64_t pestate_bootargs = find_boot_args(&cmdline_offset);

    if (pestate_bootargs == 0) {
        return false;
    }

    uint64_t struct_boot_args = rk64(pestate_bootargs);
    uint64_t boot_args_cmdline = struct_boot_args + cmdline_offset;

    // max size is 256 on arm
    char buf_bootargs[256];

    rkbuffer(boot_args_cmdline, buf_bootargs, sizeof(buf_bootargs));
    strcat(buf_bootargs, " rd=md0 ");
    wkbuffer(boot_args_cmdline, buf_bootargs, sizeof(buf_bootargs));
    return true;
}

// props to xerub for the original '/' r/w remount code
int remount_root(task_t tfp0, uint64_t kslide) {
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


int mount_root(task_t tfp0, uint64_t kslide) {
    (fix_root_iswriteprotected() && fake_rootedramdisk());

    return remount_root(tfp0, kslide);
}

int can_write_root() {
    return access("/", W_OK);
}
