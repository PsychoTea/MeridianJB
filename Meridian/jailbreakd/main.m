#import <Foundation/Foundation.h>
#include <stdio.h>
#include <mach/mach.h>
#include <mach/error.h>
#include <string.h>
#include <unistd.h>
#include "helpers/patchfinder64.h"
#include "kern_utils.h"
#include "helpers/kmem.h"
#include "helpers/kexecute.h"
#include "mach/jailbreak_daemonServer.h"

#define PROC_PIDPATHINFO_MAXSIZE  (4 * MAXPATHLEN)
int proc_pidpath(pid_t pid, void *buffer, uint32_t buffersize);

#define MEMORYSTATUS_CMD_SET_JETSAM_TASK_LIMIT 6
int memorystatus_control(uint32_t command, int32_t pid, uint32_t flags, void *buffer, size_t buffersize);

#define JAILBREAKD_COMMAND_ENTITLE 1
#define JAILBREAKD_COMMAND_ENTITLE_AND_SIGCONT 2
#define JAILBREAKD_COMMAND_ENTITLE_AND_SIGCONT_FROM_XPCPROXY 3
#define JAILBREAKD_COMMAND_FIXUP_SETUID 4

typedef boolean_t (*dispatch_mig_callback_t)(mach_msg_header_t *message, mach_msg_header_t *reply);
mach_msg_return_t dispatch_mig_server(dispatch_source_t ds, size_t maxmsgsz, dispatch_mig_callback_t callback);
kern_return_t bootstrap_check_in(mach_port_t bootstrap_port, const char *service, mach_port_t *server_port);

int remove_memory_limit() {
    return memorystatus_control(MEMORYSTATUS_CMD_SET_JETSAM_TASK_LIMIT, getpid(), 0, NULL, 0);
}

int is_valid_command(uint8_t command) {
    return (command == JAILBREAKD_COMMAND_ENTITLE ||
            command == JAILBREAKD_COMMAND_ENTITLE_AND_SIGCONT ||
            command == JAILBREAKD_COMMAND_ENTITLE_AND_SIGCONT_FROM_XPCPROXY ||
            command == JAILBREAKD_COMMAND_FIXUP_SETUID);
}

int handle_command(uint8_t command, uint32_t pid) {
    int ret = 0;
    
    if (!is_valid_command(command)) {
        NSLog(@"Invalid command recieved.");
        return 1;
    }
    
    char *name = proc_name(pid);
    
    if (command == JAILBREAKD_COMMAND_ENTITLE) {
        NSLog(@"JAILBREAKD_COMMAND_ENTITLE PID: %d NAME: %s", pid, name);
        platformize(pid);
    }
    
    if (command == JAILBREAKD_COMMAND_ENTITLE_AND_SIGCONT) {
        NSLog(@"JAILBREAKD_COMMAND_ENTITLE_AND_SIGCONT PID: %d NAME: %s", pid, name);
        platformize(pid);
        kill(pid, SIGCONT);
    }
    
    if (command == JAILBREAKD_COMMAND_ENTITLE_AND_SIGCONT_FROM_XPCPROXY) {
        NSLog(@"JAILBREAKD_COMMAND_ENTITLE_AND_SIGCONT_FROM_XPCPROXY PID: %d NAME: %s", pid, name);
        
        __block int blk_pid = pid;
        
        dispatch_queue_t queue = dispatch_queue_create("jailbreakd.queue", NULL);
        dispatch_async(queue, ^{
            char pathbuf[PROC_PIDPATHINFO_MAXSIZE];
            bzero(pathbuf, PROC_PIDPATHINFO_MAXSIZE);
            
            int err = 0, tries = 0;
            
            do {
                err = proc_pidpath(blk_pid, pathbuf, PROC_PIDPATHINFO_MAXSIZE);
                if (err <= 0) {
                    NSLog(@"failed to get pidpath for %d", blk_pid);
                    kill(blk_pid, SIGCONT); // just in case
                    return;
                }
                
                tries++;
                // gives (50,000 * 100 microseconds) 5 seconds of total wait time
                if (tries >= 50000) {
                    NSLog(@"failed to get pidpath for %d (%d tries)", blk_pid, tries);
                    kill(pid, SIGCONT); // just in case
                    return;
                }
                
                usleep(100);
                
                if (tries % 5000 == 0) {
                    NSLog(@"pathbuf: %s", pathbuf);
                }
            } while (strcmp(pathbuf, "/usr/libexec/xpcproxy") == 0);
            
            NSLog(@"xpcproxy morphed into process: %s", pathbuf);
            
            platformize(blk_pid);
            kill(blk_pid, SIGCONT);
        });
        dispatch_release(queue);
        
        goto out;
    }
    
    if (command == JAILBREAKD_COMMAND_FIXUP_SETUID) {
        NSLog(@"JAILBREAKD_FIXUP_SETUID PID: %d NAME: %s (ignored)", pid, name);
    }
    
out:
    free(name);
    
    return ret;
}

kern_return_t jbd_call(mach_port_t server_port, uint8_t command, uint32_t pid) {
    return (handle_command(command, pid) == 0) ? KERN_SUCCESS : KERN_FAILURE;
}

int main(int argc, char **argv, char **envp) {
    kern_return_t err;
    
    NSLog(@"the fun and games shall begin! (applying lube...)");
    unlink("/var/tmp/jailbreakd.pid");
    
    // Parse offsets from env var's
    kernel_base         = strtoull(getenv("KernelBase"),    NULL, 16);
    kernel_slide        = kernel_base - 0xFFFFFFF007004000;
    NSLog(@"kern base: %llx, slide: %llx", kernel_base, kernel_slide);
    
    kernprocaddr        = strtoull(getenv("KernProcAddr"),  NULL, 16);
    offset_zonemap      = strtoull(getenv("ZoneMapOffset"), NULL, 16);
    offset_proc_find    = strtoull(getenv("ProcFind"),      NULL, 16) + kernel_slide;
    offset_proc_name    = strtoull(getenv("ProcName"),      NULL, 16) + kernel_slide;
    offset_proc_rele    = strtoull(getenv("ProcRele"),      NULL, 16) + kernel_slide;
    NSLog(@"kernproc: 0x%016llx", kernprocaddr);
    NSLog(@"zonemap: 0x%016llx", offset_zonemap);
    NSLog(@"proc_find: 0x%016llx", offset_proc_find);
    NSLog(@"proc_name: 0x%016llx", offset_proc_name);
    NSLog(@"proc_rele: 0x%016llx", offset_proc_rele);
    
    // tfp0, patchfinder, kexecute
    err = host_get_special_port(mach_host_self(), HOST_LOCAL_NODE, 4, &tfp0);
    if (err != KERN_SUCCESS) {
        NSLog(@"host_get_special_port 4: %s", mach_error_string(err));
        return -1;
    }
    NSLog(@"tfp0: %x", tfp0);
    
    // required for patchfinder64 as it needs to read the entire kernel image
    remove_memory_limit();
    
    err = init_kernel(kernel_base, NULL);
    if (err != 0) {
        NSLog(@"failed to initialize patchfinder64!");
        return -1;
    }
    
    init_kexecute();
    
    // Set up mach stuff
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
    NSLog(@"mach server now running!");
    
    FILE *f = fopen("/var/tmp/jailbreakd.pid", "w");
    fprintf(f, "%d\n", getpid());
    fclose(f);
    
    // Start accepting connections
    // This will block exec
    dispatch_main();
    
    term_kexecute();
    
    return 0;
}
