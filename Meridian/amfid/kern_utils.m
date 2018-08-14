#include <stdio.h>
#include <stdlib.h>
#include <Foundation/Foundation.h>
#include "kmem.h"
#include "offsetof.h"
#include "patchfinder64.h"
#include "kern_utils.h"

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
