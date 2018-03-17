#import <Foundation/Foundation.h>
#include <stdio.h>
#include <mach/mach.h>
#include <mach/error.h>
#include <string.h>
#include <unistd.h>
#include "patchfinder64.h"
#include "kern_utils.h"
#include "kmem.h"
#include "kexecute.h"
#include "mach/jailbreak_daemonServer.h"

#define PROC_PIDPATHINFO_MAXSIZE  (4 * MAXPATHLEN)
int proc_pidpath(pid_t pid, void *buffer, uint32_t buffersize);

typedef boolean_t (*dispatch_mig_callback_t)(mach_msg_header_t *message, mach_msg_header_t *reply);
mach_msg_return_t dispatch_mig_server(dispatch_source_t ds, size_t maxmsgsz, dispatch_mig_callback_t callback);
kern_return_t bootstrap_check_in(mach_port_t bootstrap_port, const char *service, mach_port_t *server_port);

#define JAILBREAKD_COMMAND_ENTITLE 1
#define JAILBREAKD_COMMAND_ENTITLE_AND_SIGCONT 2
#define JAILBREAKD_COMMAND_ENTITLE_AND_SIGCONT_FROM_XPCPROXY 3
#define JAILBREAKD_COMMAND_FIXUP_SETUID 4

mach_port_t tfpzero;
uint64_t kernel_base;
uint64_t kernel_slide;

#define MEMORYSTATUS_CMD_SET_JETSAM_TASK_LIMIT 6
int memorystatus_control(uint32_t command, int32_t pid, uint32_t flags, void *buffer, size_t buffersize);

int remove_memory_limit(void) {
    return memorystatus_control(MEMORYSTATUS_CMD_SET_JETSAM_TASK_LIMIT, getpid(), 0, NULL, 0);
}

int is_valid_command(uint8_t command) {
    return (command == JAILBREAKD_COMMAND_ENTITLE ||
            command == JAILBREAKD_COMMAND_ENTITLE_AND_SIGCONT ||
            command == JAILBREAKD_COMMAND_ENTITLE_AND_SIGCONT_FROM_XPCPROXY ||
            command == JAILBREAKD_COMMAND_FIXUP_SETUID);
}

int handle_command(uint8_t command, uint32_t pid) {
    if (!is_valid_command(command)) {
        NSLog(@"Invalid command recieved.");
        return 1;
    }
    
    // char *name = proc_name(pid);
    
    if (command == JAILBREAKD_COMMAND_ENTITLE) {
        //NSLog(@"JAILBREAKD_COMMAND_ENTITLE PID: %d NAME: %s", pid, name);
        setcsflagsandplatformize(pid);
    }
    
    if (command == JAILBREAKD_COMMAND_ENTITLE_AND_SIGCONT) {
        //NSLog(@"JAILBREAKD_COMMAND_ENTITLE_AND_SIGCONT PID: %d NAME: %s", pid, name);
        setcsflagsandplatformize(pid);
        kill(pid, SIGCONT);
    }
    
    if (command == JAILBREAKD_COMMAND_ENTITLE_AND_SIGCONT_FROM_XPCPROXY) {
        //NSLog(@"JAILBREAKD_COMMAND_ENTITLE_AND_SIGCONT_FROM_XPCPROXY PID: %d NAME: %s", pid, name);
        __block int PID = pid;
        
        dispatch_queue_t queue = dispatch_queue_create("org.coolstar.jailbreakd.delayqueue", NULL);
        dispatch_async(queue, ^{
            char pathbuf[PROC_PIDPATHINFO_MAXSIZE];
            bzero(pathbuf, sizeof(pathbuf));
            
            int ret = proc_pidpath(PID, pathbuf, sizeof(pathbuf));
            while (ret > 0 && strcmp(pathbuf, "/usr/libexec/xpcproxy") == 0){
                proc_pidpath(PID, pathbuf, sizeof(pathbuf));
                usleep(100);
            }
            
            setcsflagsandplatformize(PID);
            kill(PID, SIGCONT);
        });
        dispatch_release(queue);
    }
    
    if (command == JAILBREAKD_COMMAND_FIXUP_SETUID) {
        //NSLog(@"JAILBREAKD_FIXUP_SETUID PID: %d NAME: %s", pid, name);
        fixupsetuid(pid);
    }
    
    // free(name);
    
    return 0;
}

kern_return_t jbd_call(mach_port_t server_port, uint8_t command, uint32_t pid) {
    // NSLog(@"[Mach] New call from %x: command %x, pid %d", server_port, command, pid);
    return (handle_command(command, pid) == 0) ? KERN_SUCCESS : KERN_FAILURE;
}

int main(int argc, char **argv, char **envp) {
    kern_return_t err;
    
    NSLog(@"[jailbreakd] Start");
    unlink("/var/tmp/jailbreakd.pid");
    
    kernel_base = strtoull(getenv("KernelBase"), NULL, 16);
    kernprocaddr = strtoull(getenv("KernProcAddr"), NULL, 16);
    offset_zonemap = strtoull(getenv("ZoneMapOffset"), NULL, 16);
    
    remove_memory_limit();
    
    err = host_get_special_port(mach_host_self(), HOST_LOCAL_NODE, 4, &tfpzero);
    if (err != KERN_SUCCESS) {
        NSLog(@"host_get_special_port 4: %s", mach_error_string(err));
        return -1;
    }
    
    init_kernel(kernel_base, NULL);
    kernel_slide = kernel_base - 0xFFFFFFF007004000;
    NSLog(@"[jailbreakd] tfp: 0x%016llx", (uint64_t)tfpzero);
    NSLog(@"[jailbreakd] slide: 0x%016llx", kernel_slide);
    NSLog(@"[jailbreakd] kernproc: 0x%016llx", kernprocaddr);
    NSLog(@"[jailbreakd] zonemap: 0x%016llx", offset_zonemap);
    
    // set up mach stuff
    mach_port_t server_port;
    
    if ((err = bootstrap_check_in(bootstrap_port, "zone.sparkes.jailbreakd", &server_port))) {
        NSLog(@"Failed to check in: %s", mach_error_string(err));
        return -1;
    }
    
    dispatch_source_t server = dispatch_source_create(DISPATCH_SOURCE_TYPE_MACH_RECV, server_port, 0, dispatch_get_main_queue());
    dispatch_source_set_event_handler(server, ^{
        dispatch_mig_server(server, jbd_jailbreak_daemon_subsystem.maxsize, jailbreak_daemon_server);
    });
    dispatch_resume(server);
    
    // Now ready for connections!
    NSLog(@"Mach server now running!");
    FILE *f = fopen("/var/tmp/jailbreakd.pid", "w");
    fprintf(f, "%d\n", getpid());
    fclose(f);
    
    dispatch_main();
    
    return 0;
}
