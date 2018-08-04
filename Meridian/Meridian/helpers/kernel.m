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

size_t kread(uint64_t where, void *p, size_t size)
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

uint64_t find_gadget_candidate(char** alternatives, size_t gadget_length) {
    void* haystack_start = (void*)atoi;    // will do...
    size_t haystack_size = 100*1024*1024; // likewise...
    
    for (char* candidate = *alternatives; candidate != NULL; alternatives++) {
        void* found_at = memmem(haystack_start, haystack_size, candidate, gadget_length);
        if (found_at != NULL) {
            return (uint64_t)found_at;
        }
    }
    
    return 0;
}

uint64_t blr_x19_addr = 0;
uint64_t find_blr_x19_gadget() {
    if (blr_x19_addr != 0) {
        return blr_x19_addr;
    }
    
    char* blr_x19 = "\x60\x02\x3f\xd6";
    char* candidates[] = {blr_x19, NULL};
    blr_x19_addr = find_gadget_candidate(candidates, 4);
    return blr_x19_addr;
}

// no support for non-register args
#define MAX_REMOTE_ARGS 8

// not in iOS SDK headers:
extern void _pthread_set_self(pthread_t p);

uint64_t call_remote(mach_port_t task_port, void* fptr, int n_params, ...) {
    if (n_params > MAX_REMOTE_ARGS || n_params < 0){
        NSLog(@"unsupported number of arguments to remote function (%d)\n", n_params);
        return 0;
    }
    
    kern_return_t err;
    
    uint64_t remote_stack_base = 0;
    uint64_t remote_stack_size = 4*1024*1024;
    
    remote_stack_base = remote_alloc(task_port, remote_stack_size);
    
    uint64_t remote_stack_middle = remote_stack_base + (remote_stack_size/2);
    
    // create a new thread in the target
    // just using the mach thread API doesn't initialize the pthread thread-local-storage
    // which means that stuff which relies on that will crash
    // we can sort-of make that work by calling _pthread_set_self(NULL) in the target process
    // which will give the newly created thread the same TLS region as the main thread
    
    
    _STRUCT_ARM_THREAD_STATE64 thread_state = {0};
    mach_msg_type_number_t thread_stateCnt = sizeof(thread_state)/4;
    
    // we'll start the thread running and call _pthread_set_self first:
    thread_state.__sp = remote_stack_middle;
    thread_state.__pc = (uint64_t)_pthread_set_self;
    
    // set these up to put us into a predictable state we can monitor for:
    uint64_t loop_lr = find_blr_x19_gadget();
    thread_state.__x[19] = loop_lr;
    thread_state.__lr = loop_lr;
    
    // set the argument to NULL:
    thread_state.__x[0] = 0;
    
    mach_port_t thread_port = MACH_PORT_NULL;
    
    err = thread_create_running(task_port, ARM_THREAD_STATE64, (thread_state_t)&thread_state, thread_stateCnt, &thread_port);
    if (err != KERN_SUCCESS){
        NSLog(@"error creating thread in child: %s\n", mach_error_string(err));
        return 0;
    }
    // NSLog(@"new thread running in child: %x\n", thread_port);
    
    // wait for it to hit the loop:
    while(1){
        // monitor the thread until we see it's in the infinite loop indicating it's done:
        err = thread_get_state(thread_port, ARM_THREAD_STATE64, (thread_state_t)&thread_state, &thread_stateCnt);
        if (err != KERN_SUCCESS){
            NSLog(@"error getting thread state: %s\n", mach_error_string(err));
            return 0;
        }
        
        if (thread_state.__pc == loop_lr && thread_state.__x[19] == loop_lr){
            // thread has returned from the target function
            break;
        }
    }
    
    // the thread should now have pthread local storage
    // pause it:
    
    err = thread_suspend(thread_port);
    if (err != KERN_SUCCESS){
        NSLog(@"unable to suspend target thread\n");
        return 0;
    }
    
    /*
     err = thread_abort(thread_port);
     if (err != KERN_SUCCESS){
     NSLog(@"unable to get thread out of any traps\n");
     return 0;
     }
     */
    
    // set up for the actual target call:
    thread_state.__sp = remote_stack_middle;
    thread_state.__pc = (uint64_t)fptr;
    
    // set these up to put us into a predictable state we can monitor for:
    thread_state.__x[19] = loop_lr;
    thread_state.__lr = loop_lr;
    
    va_list ap;
    va_start(ap, n_params);
    
    arg_desc* args[MAX_REMOTE_ARGS] = {0};
    
    uint64_t remote_buffers[MAX_REMOTE_ARGS] = {0};
    //uint64_t remote_buffer_sizes[MAX_REMOTE_ARGS] = {0};
    
    for (int i = 0; i < n_params; i++){
        arg_desc* arg = va_arg(ap, arg_desc*);
        
        args[i] = arg;
        
        switch(arg->type){
                case ARG_LITERAL:
            {
                thread_state.__x[i] = arg->value;
                break;
            }
                
                case ARG_BUFFER:
                case ARG_BUFFER_PERSISTENT:
                case ARG_INOUT_BUFFER:
            {
                uint64_t remote_buffer = alloc_and_fill_remote_buffer(task_port, arg->value, arg->length);
                remote_buffers[i] = remote_buffer;
                thread_state.__x[i] = remote_buffer;
                break;
            }
                
                case ARG_OUT_BUFFER:
            {
                uint64_t remote_buffer = remote_alloc(task_port, arg->length);
                // NSLog(@"allocated a remote out buffer: %llx\n", remote_buffer);
                remote_buffers[i] = remote_buffer;
                thread_state.__x[i] = remote_buffer;
                break;
            }
                
            default:
            {
                NSLog(@"invalid argument type!\n");
            }
        }
    }
    
    va_end(ap);
    
    err = thread_set_state(thread_port, ARM_THREAD_STATE64, (thread_state_t)&thread_state, thread_stateCnt);
    if (err != KERN_SUCCESS){
        NSLog(@"error setting new thread state: %s\n", mach_error_string(err));
        return 0;
    }
    // NSLog(@"thread state updated in target: %x\n", thread_port);
    
    err = thread_resume(thread_port);
    if (err != KERN_SUCCESS){
        NSLog(@"unable to resume target thread\n");
        return 0;
    }
    
    while(1){
        // monitor the thread until we see it's in the infinite loop indicating it's done:
        err = thread_get_state(thread_port, ARM_THREAD_STATE64, (thread_state_t)&thread_state, &thread_stateCnt);
        if (err != KERN_SUCCESS){
            NSLog(@"error getting thread state: %s\n", mach_error_string(err));
            return 0;
        }
        
        if (thread_state.__pc == loop_lr/*&& thread_state.__x[19] == loop_lr*/){
            // thread has returned from the target function
            break;
        }
        
        // thread isn't in the infinite loop yet, let it continue
    }
    
    // deallocate the remote thread
    err = thread_terminate(thread_port);
    if (err != KERN_SUCCESS){
        NSLog(@"failed to terminate thread\n");
        return 0;
    }
    mach_port_deallocate(mach_task_self(), thread_port);
    
    // handle post-call argument cleanup/copying:
    for (int i = 0; i < MAX_REMOTE_ARGS; i++){
        arg_desc* arg = args[i];
        if (arg == NULL){
            break;
        }
        switch (arg->type){
                case ARG_BUFFER:
            {
                remote_free(task_port, remote_buffers[i], arg->length);
                break;
            }
                
                case ARG_INOUT_BUFFER:
                case ARG_OUT_BUFFER:
            {
                // copy the contents back:
                remote_read_overwrite(task_port, remote_buffers[i], arg->value, arg->length);
                remote_free(task_port, remote_buffers[i], arg->length);
                break;
            }
        }
    }
    
    uint64_t ret_val = thread_state.__x[0];
    
    // NSLog(@"remote function call return value: %llx\n", ret_val);
    
    // deallocate the stack in the target:
    remote_free(task_port, remote_stack_base, remote_stack_size);
    
    return ret_val;
}
