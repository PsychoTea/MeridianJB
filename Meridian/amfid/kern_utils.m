#include <stdio.h>
#include <stdlib.h>
#include <Foundation/Foundation.h>
#include "kmem.h"
#include "offsetof.h"
#include "patchfinder64.h"

uint64_t proc_find(int pd, int tries) {
    NSLog(@"proc_find: %d, %d", pd, tries);
    while (tries-- > 0) {
        NSLog(@"about to read....");
        uint64_t task = find_kernel_task();
        NSLog(@"kern_task = %llx", task);
        uint64_t ktask = rk64(task);
        NSLog(@"ktask = %llx", ktask);
        NSLog(@"bsdinfo = %llx", rk64(ktask + offsetof_bsd_info));
        uint64_t proc = rk64(find_kern_proc() + 0x08);
        NSLog(@"found kern proc: %llx", proc);
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
    NSLog(@"finding proc...");
    uint64_t our_proc = proc_find(getpid(), 3);
    NSLog(@"got our proc: %llx", our_proc);

    if (our_proc == 0) {
        fprintf(stderr, "failed to find our_task_addr!\n");
        exit(EXIT_FAILURE);
    }

    return rk64(our_proc + offsetof_task);
}

uint64_t find_port(mach_port_name_t port) {
    NSLog(@"find_port: %llx", port);
    uint64_t task_addr = our_task_addr();
    NSLog(@"our task addr: %llx", task_addr);

    uint64_t itk_space = rk64(task_addr + offsetof_itk_space);

    uint64_t is_table = rk64(itk_space + offsetof_ipc_space_is_table);

    uint32_t port_index = port >> 8;
    const int sizeof_ipc_entry_t = 0x18;

    uint64_t port_addr = rk64(is_table + (port_index * sizeof_ipc_entry_t));
    
    NSLog(@"PORt_addr: %llx", port_addr);
    return port_addr;
}
