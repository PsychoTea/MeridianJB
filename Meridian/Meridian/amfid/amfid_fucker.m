/* code comes from IB's triple_fetch patch_amfid.c */
/* cheers to theninjaprawn                         */

#include <dlfcn.h>
#include <stdio.h>
#include <unistd.h>
#include <sys/types.h>
#include <mach/mach.h>
#include <mach-o/loader.h>
#include <mach/error.h>
#include <errno.h>
#include <stdlib.h>
#include <sys/sysctl.h>
#include <dlfcn.h>
#include <sys/mman.h>
#include <spawn.h>
#include <sys/stat.h>
#include <pthread.h>
#include <signal.h>
#import <Foundation/Foundation.h>

kern_return_t mach_vm_allocate(vm_map_t target,
                               mach_vm_address_t *address,
                               mach_vm_size_t size,
                               int flags);

kern_return_t mach_vm_write(vm_map_t target_task,
                            mach_vm_address_t address,
                            vm_offset_t data,
                            mach_msg_type_number_t dataCnt);

kern_return_t mach_vm_deallocate(vm_map_t target,
                                 mach_vm_address_t address,
                                 mach_vm_size_t size);

kern_return_t mach_vm_read_overwrite(vm_map_t target_task,
                                     mach_vm_address_t address,
                                     mach_vm_size_t size,
                                     mach_vm_address_t data,
                                     mach_vm_size_t *outsize);

kern_return_t mach_vm_region(vm_map_t target_task,
                             mach_vm_address_t *address,
                             mach_vm_size_t *size,
                             vm_region_flavor_t flavor,
                             vm_region_info_t info,
                             mach_msg_type_number_t *infoCnt,
                             mach_port_t *object_name);

mach_port_t tfp0 = 0;
uint64_t kernprocaddr = 0;

/*uint64_t kalloc(vm_size_t size) {
	mach_vm_address_t address = 0;
	mach_vm_allocate(tfp0, (mach_vm_address_t *)&address, size, VM_FLAGS_ANYWHERE);
	return address;
}*/

size_t kread(uint64_t where, void *p, size_t size) {
	int rv;
	size_t offset = 0;
	while (offset < size) {
		mach_vm_size_t sz, chunk = 2048;
		if (chunk > size - offset) {
			chunk = size - offset;
		}
		rv = mach_vm_read_overwrite(tfp0, where + offset, chunk, (mach_vm_address_t)p + offset, &sz);
		if (rv || sz == 0) {
			printf("[fun_utils] error on kread(0x%016llx)\n", (offset + where));
			break;
		}
		offset += sz;
	}
	return offset;
}

uint32_t kread32(uint64_t where) {
	uint32_t out;
	kread(where, &out, sizeof(uint32_t));
	return out;
}

uint64_t kread64(uint64_t where) {
	uint64_t out;
	kread(where, &out, sizeof(uint64_t));
	return out;
}

size_t kwrite(uint64_t where, const void *p, size_t size) {
	int rv;
	size_t offset = 0;
	while (offset < size) {
		size_t chunk = 2048;
		if (chunk > size - offset) {
			chunk = size - offset;
		}
		rv = mach_vm_write(tfp0, where + offset, (mach_vm_offset_t)p + offset, chunk);
		if (rv) {
			printf("[fun_utils] error on kwrite(0x%016llx)\n", (offset + where));
			break;
		}
		offset += chunk;
	}
	return offset;
}

/*void kwrite32(uint64_t where, uint32_t what) {
	uint32_t _what = what;
	kwrite(where, &_what, sizeof(uint32_t));
}*/

/*void kwrite64(uint64_t where, uint64_t what) {
	uint64_t _what = what;
	kwrite(where, &_what, sizeof(uint64_t));
}*/

uint64_t remote_alloc(mach_port_t task_port, uint64_t size) {
  kern_return_t err;

  mach_vm_offset_t remote_addr = 0;
  mach_vm_size_t remote_size = (mach_vm_size_t)size;
  err = mach_vm_allocate(task_port, &remote_addr, remote_size, 1); // ANYWHERE
  if (err != KERN_SUCCESS){
    NSLog(@"unable to allocate buffer in remote process\n");
    return 0;
  }
  return (uint64_t)remote_addr;
}

void remote_free(mach_port_t task_port, uint64_t base, uint64_t size) {
  kern_return_t err;

  err = mach_vm_deallocate(task_port, (mach_vm_address_t)base, (mach_vm_size_t)size);
  if (err !=  KERN_SUCCESS){
    NSLog(@"unabble to deallocate remote buffer\n");
    return;
  }
  return;
}

uint64_t alloc_and_fill_remote_buffer(mach_port_t task_port,
                                      uint64_t local_address,
                                      uint64_t length) {
  kern_return_t err;

  uint64_t remote_address = remote_alloc(task_port, length);

  err = mach_vm_write(task_port, remote_address, (mach_vm_offset_t)local_address, (mach_msg_type_number_t)length);
  if (err != KERN_SUCCESS){
    NSLog(@"unable to write to remote memory\n");
    return 0;
  }

  return remote_address;
}

void remote_read_overwrite(mach_port_t task_port,
                           uint64_t remote_address,
                           uint64_t local_address,
                           uint64_t length) {
  kern_return_t err;

  mach_vm_size_t outsize = 0;
  err = mach_vm_read_overwrite(task_port, (mach_vm_address_t)remote_address, (mach_vm_size_t)length, (mach_vm_address_t)local_address, &outsize);
  if (err != KERN_SUCCESS){
    NSLog(@"remote read failed\n");
    return;
  }

  if (outsize != length){
    NSLog(@"remote read was short (expected %llx, got %llx\n", length, outsize);
    return;
  }
}

/*void remote_write(mach_port_t remote_task_port,
                  uint64_t remote_address,
                  uint64_t local_address,
                  uint64_t length) {
  kern_return_t err = mach_vm_write(remote_task_port,
                                    (mach_vm_address_t)remote_address,
                                    (vm_offset_t)local_address,
                                    (mach_msg_type_number_t)length);
  if (err != KERN_SUCCESS) {
    NSLog(@"remote write failed: %s %x\n", mach_error_string(err), err);
    return;
  }
}*/

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

#define REMOTE_LITERAL(val) &(arg_desc){ARG_LITERAL, (uint64_t)val, (uint64_t)0}
#define REMOTE_BUFFER(ptr, size) &(arg_desc){ARG_BUFFER, (uint64_t)ptr, (uint64_t)size}
#define REMOTE_CSTRING(str) &(arg_desc){ARG_BUFFER, (uint64_t)str, (uint64_t)(strlen(str)+1)}

uint64_t find_proc_by_name(char* name) {
    uint64_t proc = kread64(kernprocaddr + 0x08);
    
    while (proc) {
        char proc_name[40] = { 0 };
        
        kread(proc + 0x26c, proc_name, 40);
        
        if (!strcmp(proc_name, name)) {
            return proc;
        }
        
        proc = kread64(proc + 0x08);
    }
    
    return 0;
}

uint32_t get_pid_for_name(char* name) {
    uint64_t proc = find_proc_by_name(name);
    if (proc == 0) {
        return 0;
    }
    
    return kread32(proc + 0x10);
}

// credits to Jonathan Levin (Morpheus) for this awesome workaround
// http://newosxbook.com/articles/PST2.html
// not really necessary to use, but i'm lazy to change it
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
        mach_error("host_processor_set_priv", kr);
        exit(1);
    }
    
    kr = processor_set_tasks(psDefault_control, &tasks, &numTasks);
    if (kr != KERN_SUCCESS) {
        fprintf(stderr, "processor_set_tasks failed with error %x\n", kr);
        exit(1);
    }
    
    for (int i = 0; i < numTasks; i++) {
        int t_pid;
        pid_for_task(tasks[i], &t_pid);
        if (pid == t_pid) {
            return tasks[i];
        }
    }
    
    return MACH_PORT_NULL;
}

// creds to Jonathan Levin (@Morpheus)
int get_kqueue_for_pid(pid_t pid) {
    struct kevent ke;
    int kq = kqueue();
    if (kq == -1) {
        NSLog(@"[inject] unable to create queue: %s", strerror(errno));
        return -1;
    }
    
    // Set process fork/exec notifications
    EV_SET(&ke, pid, EVFILT_PROC, EV_ADD, NOTE_EXIT_DETAIL, 0, NULL);
    // Register event
    int rc = kevent(kq, &ke, 1, NULL, 0, NULL);
    
    if (rc < 0) {
        NSLog(@"[inject] unable to get kevent %s", strerror(errno));
        return -2;
    }
    
    return kq;
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

pid_t amfid_pid;

mach_port_t get_amfid_task() {
    pid_t new_amfid_pid = get_pid_for_name("amfid");
    while (!new_amfid_pid) {
        sleep(1);
        new_amfid_pid = get_pid_for_name("amfid");
    }
    NSLog(@"[amfid_fucker] got amfid pid %d", new_amfid_pid);
    amfid_pid = new_amfid_pid;
    
    mach_port_t amfid_task = task_for_pid_workaround(amfid_pid);
    NSLog(@"[amfid_fucker] got amfid task %llx", amfid_task);
    
    return amfid_task;
}

int patch_amfid(mach_port_t amfi_port) {
    call_remote(amfi_port, setuid, 1, REMOTE_LITERAL(0));
    
    NSLog(@"[amfid_fucker] amfid uid is now 0 - injecting our dylib");
    
    call_remote(amfi_port, dlopen, 2, REMOTE_CSTRING("/meridian/amfid_payload.dylib"), REMOTE_LITERAL(RTLD_NOW));
    uint64_t error = call_remote(amfi_port, dlerror, 0);
    if (error == 0) {
        NSLog(@"[amfid_fucker] No error occured! Payload injected successfully!");
    } else {
        uint64_t len = call_remote(amfi_port, strlen, 1, REMOTE_LITERAL(error));
        char* local_cstring = malloc(len +  1);
        remote_read_overwrite(amfi_port, error, (uint64_t)local_cstring, len+1);
        
        NSLog(@"[amfid_fucker] Error: %s", local_cstring);
        return 3;
    }
    
    NSLog(@"[amfid_fucker] get fucked ya silyl little cunT ;) \n");
    return 0;
}

int main(int argc, char* argv[]) {
    NSLog(@"[amfid_fucker] Hey there :^)");
    
    // Sleep for csflags
    sleep(1);
    
    // get tfp0 via hgsp4 (I finally found our waht this means!)
    kern_return_t kr_tfp = host_get_special_port(mach_host_self(), HOST_LOCAL_NODE, 4, &tfp0);
    NSLog(@"[amfid_fucker] got tfp0 = %llx (%s)", tfp0, mach_error_string(kr_tfp));
    
    char *endptr;
    kernprocaddr = strtoull(argv[1], &endptr, 10);
    NSLog(@"[amfid_fucker] got value 0x%llx for kernprocaddr", kernprocaddr);
    
    mach_port_t amfid_task = get_amfid_task();
    patch_amfid(amfid_task);
    NSLog(@"[amfid_fucker] Inital amfid patch complete");
    
    // Not sleeping before hopping into the loop
    // would cause werid shit to happen, so this'll do
    sleep(3);
    
    // s/o to Jonathan Levin (@Morpheus) for the example on using kqueue/kevent
    // http://newosxbook.com/QiLin/qilin.pdf (pg 21)
    
    while (true) {
        int kq = get_kqueue_for_pid(amfid_pid);
        NSLog(@"[amfid_fucker] got kq for amfi: %d", kq);
        
        struct kevent ke;
        memset(&ke, '\0', sizeof(struct kevent));
        int rc = kevent(kq, NULL, 0, &ke, 1, NULL);
        NSLog(@"[amfid_fucker] got kevent rc for amfid: %d", rc);
        
        if (rc >= 0) {
            close(kq);
            NSLog(@"[amfid_fucker] amfid is dead!");
            
            mach_port_t amfid_task = get_amfid_task();
            patch_amfid(amfid_task);
            
            NSLog(@"[amfid_fucker] fuck you amfid, PATCHED!");
        }
        
        sleep(1);
    }
    
    return 69;
}
