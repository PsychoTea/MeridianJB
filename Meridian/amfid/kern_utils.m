#import <Foundation/Foundation.h>

#include <stdio.h>
#include <stdlib.h>

#include "common.h"
#include "kern_utils.h"
#include "kmem.h"
#include "offsetof.h"

mach_port_t tfp0;
uint64_t kernel_base;
uint64_t kernel_slide;
uint64_t offset_zonemap;
uint64_t offset_kernel_task;
uint64_t offset_vfs_context_current;
uint64_t offset_vnode_getfromfd;
uint64_t offset_vnode_getattr;
uint64_t offset_vnode_put;
uint64_t offset_csblob_ent_dict_set;
uint64_t offset_sha1_init;
uint64_t offset_sha1_update;
uint64_t offset_sha1_final;
uint64_t offset_add_x0_x0_0x40_ret;
uint64_t offset_osboolean_true;
uint64_t offset_osboolean_false;
uint64_t offset_osunserialize_xml;
uint64_t offset_cs_find_md;

uint64_t proc_find(int pd, int tries) {
    while (tries-- > 0) {
        uint64_t ktask = rk64(offset_kernel_task);
        uint64_t kern_proc = rk64(ktask + offsetof_bsd_info);
        uint64_t proc = rk64(kern_proc + 0x08);
        
        while (proc) {
            uint32_t proc_pid = rk32(proc + 0x10);

            if (proc_pid == pd) {
                return proc;
            }

            proc = rk64(proc + 0x08);
        }
    }

    return 0;
}

CACHED_FIND(uint64_t, our_task_addr) {
    uint64_t our_proc = proc_find(getpid(), 3);

    if (our_proc == 0) {
        NSLog(@"failed to find our_task_addr!");
        return -1;
    }

    return rk64(our_proc + offsetof_task);
}

uint64_t find_port(mach_port_name_t port) {
    uint64_t task_addr = our_task_addr();
    if (task_addr == -1) {
        return -1;
    }

    uint64_t itk_space = rk64(task_addr + offsetof_itk_space);

    uint64_t is_table = rk64(itk_space + offsetof_ipc_space_is_table);

    uint32_t port_index = port >> 8;
    const int sizeof_ipc_entry_t = 0x18;

    uint64_t port_addr = rk64(is_table + (port_index * sizeof_ipc_entry_t));
    
    return port_addr;
}
