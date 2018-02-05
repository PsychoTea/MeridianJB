//
//  kernel.m
//  v0rtex
//
//  Created by Ben Sparkes on 16/12/2017.
//  Copyright © 2017 Ben Sparkes. All rights reserved.
//

#include "kernel.h"
#include "common.h"
#include "helpers.h"
#include <mach/mach.h>

task_t tfp0;

void init_kernel(task_t task_for_port0) {
    tfp0 = task_for_port0;
}

size_t tfp0_kread(uint64_t where, void *p, size_t size)
{
    int rv;
    size_t offset = 0;
    while (offset < size) {
        mach_vm_size_t sz, chunk = 2048;
        if (chunk > size - offset) {
            chunk = size - offset;
        }
        rv = mach_vm_read_overwrite(tfp0, where + offset, chunk, (mach_vm_address_t)p + offset, &sz);
        
        if (rv || sz == 0) {
            break;
        }
        
        offset += sz;
    }
    return offset;
}

uint64_t rk64(uint64_t kaddr) {
    uint64_t lower = rk32(kaddr);
    uint64_t higher = rk32(kaddr + 4);
    return ((higher << 32) | lower);
}

uint32_t rk32(uint64_t kaddr) {
    kern_return_t err;
    uint32_t val = 0;
    mach_vm_size_t outsize = 0;
    
    kern_return_t mach_vm_write(vm_map_t target_task,
                                mach_vm_address_t address,
                                vm_offset_t data,
                                mach_msg_type_number_t dataCnt);

    err = mach_vm_read_overwrite(tfp0,
                                 (mach_vm_address_t)kaddr,
                                 (mach_vm_size_t)sizeof(uint32_t),
                                 (mach_vm_address_t)&val,
                                 &outsize);
    
    if (err != KERN_SUCCESS) {
        return 0;
    }
    
    if (outsize != sizeof(uint32_t)) {
        return 0;
    }
    
    return val;
}

void wk64(uint64_t kaddr, uint64_t val) {
    uint32_t lower = (uint32_t)(val & 0xffffffff);
    uint32_t higher = (uint32_t)(val >> 32);
    wk32(kaddr, lower);
    wk32(kaddr + 4, higher);
}

void wk32(uint64_t kaddr, uint32_t val) {
    if (tfp0 == MACH_PORT_NULL) {
        return;
    }
    
    kern_return_t err;
    err = mach_vm_write(tfp0,
                        (mach_vm_address_t)kaddr,
                        (vm_offset_t)&val,
                        (mach_msg_type_number_t)sizeof(uint32_t));
    
    if (err != KERN_SUCCESS) {
        return;
    }
}

size_t kwrite(uint64_t where, const void *p, size_t size) {
    int rv;
    size_t offset = 0;
    while (offset < size) {
        size_t chunk = 2048;
        if (chunk > size - offset) {
            chunk = size - offset;
        }
        rv = mach_vm_write(tfp0,
                           where + offset,
                           (mach_vm_offset_t)p + offset,
                           (mach_msg_type_number_t)chunk);
        
        if (rv) {
            printf("[kernel] error copying buffer into region: @%p \n", (void *)(offset + where));
            break;
        }
        
        offset +=chunk;
    }
    
    return offset;
}

size_t kwrite_uint64(uint64_t where, uint64_t value) {
    return kwrite(where, &value, sizeof(value));
}

uint64_t remote_alloc(mach_port_t task_port, uint64_t size) {
    kern_return_t err;
    
    mach_vm_offset_t remote_addr = 0;
    mach_vm_size_t remote_size = (mach_vm_size_t)size;
    err = mach_vm_allocate(task_port, &remote_addr, remote_size, VM_FLAGS_ANYWHERE);
    if (err != KERN_SUCCESS){
        printf("unable to allocate buffer in remote process\n");
        return 0;
    }
    
    return (uint64_t)remote_addr;
}

uint64_t alloc_and_fill_remote_buffer(mach_port_t task_port,
                                      uint64_t local_address,
                                      uint64_t length) {
    kern_return_t err;
    
    uint64_t remote_address = remote_alloc(task_port, length);
    
    err = mach_vm_write(task_port, remote_address, (mach_vm_offset_t)local_address, (mach_msg_type_number_t)length);
    if (err != KERN_SUCCESS){
        printf("unable to write to remote memory \n");
        return 0;
    }
    
    return remote_address;
}

void remote_free(mach_port_t task_port, uint64_t base, uint64_t size) {
    kern_return_t err;
    
    err = mach_vm_deallocate(task_port, (mach_vm_address_t)base, (mach_vm_size_t)size);
    if (err !=  KERN_SUCCESS){
        printf("unabble to deallocate remote buffer\n");
        return;
    }
}

void remote_read_overwrite(mach_port_t task_port,
                           uint64_t remote_address,
                           uint64_t local_address,
                           uint64_t length) {
    kern_return_t err;
    
    mach_vm_size_t outsize = 0;
    err = mach_vm_read_overwrite(task_port, (mach_vm_address_t)remote_address, (mach_vm_size_t)length, (mach_vm_address_t)local_address, &outsize);
    if (err != KERN_SUCCESS){
        printf("remote read failed\n");
        return;
    }
    
    if (outsize != length){
        printf("remote read was short (expected %llx, got %llx\n", length, outsize);
        return;
    }
}

uint64_t binary_load_address(mach_port_t tp) {
    kern_return_t err;
    mach_msg_type_number_t region_count = VM_REGION_BASIC_INFO_COUNT_64;
    memory_object_name_t object_name = MACH_PORT_NULL;
    mach_vm_size_t target_first_size = 0x1000;
    mach_vm_address_t target_first_addr = 0x0;
    struct vm_region_basic_info_64 region = {0};
    err = mach_vm_region(tp,
                         &target_first_addr,
                         &target_first_size,
                         VM_REGION_BASIC_INFO_64,
                         (vm_region_info_t)&region,
                         &region_count,
                         &object_name);
    
    if (err != KERN_SUCCESS) {
        printf("failed to get the region\n");
        return -1;
    }
    
    return target_first_addr;
}

uint64_t ktask_self_addr() {
    uint64_t self_proc = find_proc_by_pid(getpid());
    return rk64(self_proc + 0x18);
}

// credits to Jonathan Levin (Morpheus) for this awesome workaround
// http://newosxbook.com/articles/PST2.html
mach_port_t task_for_pid_workaround(int pid) {
    host_t myhost = mach_host_self();
    mach_port_t psDefault;
    mach_port_t psDefault_control;
    
    task_array_t tasks;
    mach_msg_type_number_t numTasks;
    
    kern_return_t kr;
    
    kr = processor_set_default(myhost, &psDefault);
    
    kr = host_processor_set_priv(myhost, psDefault, &psDefault_control);
    if (kr != KERN_SUCCESS) {
        fprintf(stderr, "host_processor_set_priv failed with error %x\n", kr);
        mach_error("host_processor_set_priv",kr);
        exit(1);
    }
    
    kr = processor_set_tasks(psDefault_control, &tasks, &numTasks);
    if (kr != KERN_SUCCESS) {
        fprintf(stderr,"processor_set_tasks failed with error %x\n",kr);
        exit(1);
    }
    
    for (int i = 0; i < numTasks; i++) {
        int t_pid;
        pid_for_task(tasks[i], &t_pid);
        if (pid == t_pid) return (tasks[i]);
    }
    
    return MACH_PORT_NULL;
}

// from Ian Beer's find_port.c
uint64_t find_port_address(mach_port_name_t port) {
    uint64_t task_addr = ktask_self_addr();
    uint64_t itk_space = rk64(task_addr + 0x300);
    uint64_t is_table = rk64(itk_space + 0x20);
    
    uint32_t port_index = port >> 8;
    uint64_t port_addr = rk64(is_table + (port_index * 0x18));
    return port_addr;
}
