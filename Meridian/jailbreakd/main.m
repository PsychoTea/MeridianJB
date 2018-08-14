#import <Foundation/Foundation.h>

#include <stdio.h>
#include <string.h>
#include <unistd.h>

#include <mach/mach.h>
#include <mach/error.h>

#include "common.h"
#include "jailbreak_daemonServer.h"
#include "kern_utils.h"
#include "kexecute.h"
#include "kmem.h"

#define PROC_PIDPATHINFO_MAXSIZE (4 * MAXPATHLEN)
int proc_pidpath(pid_t pid, void *buffer, uint32_t buffersize);

#define JAILBREAKD_COMMAND_ENTITLE                              1
#define JAILBREAKD_COMMAND_ENTITLE_AND_SIGCONT                  2
#define JAILBREAKD_COMMAND_ENTITLE_AND_SIGCONT_FROM_XPCPROXY    3
#define JAILBREAKD_COMMAND_FIXUP_SETUID                         4

typedef boolean_t (*dispatch_mig_callback_t)(mach_msg_header_t *message, mach_msg_header_t *reply);
mach_msg_return_t dispatch_mig_server(dispatch_source_t ds, size_t maxmsgsz, dispatch_mig_callback_t callback);
kern_return_t bootstrap_check_in(mach_port_t bootstrap_port, const char *service, mach_port_t *server_port);

dispatch_queue_t queue = NULL;

int is_valid_command(uint8_t command) {
    return (command == JAILBREAKD_COMMAND_ENTITLE ||
            command == JAILBREAKD_COMMAND_ENTITLE_AND_SIGCONT ||
            command == JAILBREAKD_COMMAND_ENTITLE_AND_SIGCONT_FROM_XPCPROXY ||
            command == JAILBREAKD_COMMAND_FIXUP_SETUID);
}

int handle_command(uint8_t command, uint32_t pid) {
    if (!is_valid_command(command)) {
        DEBUGLOG(true, "Invalid command recieved.");
        return 1;
    }
    
    if (command == JAILBREAKD_COMMAND_ENTITLE) {
        DEBUGLOG(true, "JAILBREAKD_COMMAND_ENTITLE PID: %d", pid);
        platformize(pid);
    }
    
    if (command == JAILBREAKD_COMMAND_ENTITLE_AND_SIGCONT) {
        DEBUGLOG(true, "JAILBREAKD_COMMAND_ENTITLE_AND_SIGCONT PID: %d", pid);
        platformize(pid);
        kill(pid, SIGCONT);
    }
    
    if (command == JAILBREAKD_COMMAND_ENTITLE_AND_SIGCONT_FROM_XPCPROXY) {
        DEBUGLOG(true, "JAILBREAKD_COMMAND_ENTITLE_AND_SIGCONT_FROM_XPCPROXY PID: %d", pid);
        
        dispatch_async(queue, ^{
            char pathbuf[PROC_PIDPATHINFO_MAXSIZE];
            bzero(pathbuf, PROC_PIDPATHINFO_MAXSIZE);

            int err = 0, tries = 0;
            
            do {
                err = proc_pidpath(pid, pathbuf, PROC_PIDPATHINFO_MAXSIZE);
                if (err <= 0) {
                    DEBUGLOG(true, "failed to get pidpath for %d", pid);
                    kill(pid, SIGCONT); // just in case
                    return;
                }
                
                tries++;
                // gives (1,000 * 1,000 microseconds) 1 seconds of total wait time
                if (tries >= 1000) {
                    DEBUGLOG(true, "failed to get pidpath for %d (%d tries)", pid, tries);
                    kill(pid, SIGCONT); // just in case
                    return;
                }
                
                usleep(1000);
            } while (strcmp(pathbuf, "/usr/libexec/xpcproxy") == 0);
            
            DEBUGLOG(true, "xpcproxy has morphed to: %s", pathbuf);
            platformize(pid);
            kill(pid, SIGCONT);
        });
    }
    
    if (command == JAILBREAKD_COMMAND_FIXUP_SETUID) {
        DEBUGLOG(true, "JAILBREAKD_FIXUP_SETUID PID: %d (ignored)", pid);
    }
    
    return 0;
}

kern_return_t jbd_call(mach_port_t server_port, uint8_t command, uint32_t pid) {
    DEBUGLOG(false, "jbd_call: %x, %x, %d", server_port, command, pid);
    return (handle_command(command, pid) == 0) ? KERN_SUCCESS : KERN_FAILURE;
}

int main(int argc, char **argv, char **envp) {
    kern_return_t err;
    
    DEBUGLOG(true, "the fun and games shall begin! (applying lube...)");
    unlink("/var/tmp/jailbreakd.pid");
    
    // Parse offsets from env var's
    kernel_base             = strtoull(getenv("KernelBase"),        NULL, 16);
    kernel_slide            = kernel_base - 0xFFFFFFF007004000;
    DEBUGLOG(true, "kern base: %llx, slide: %llx", kernel_base, kernel_slide);
    
    kernprocaddr            = strtoull(getenv("KernProcAddr"),      NULL, 16);
    offset_zonemap          = strtoull(getenv("ZoneMapOffset"),     NULL, 16);
    
    offset_add_ret_gadget   = strtoull(getenv("AddRetGadget"),      NULL, 16);
    offset_osboolean_true   = strtoull(getenv("OSBooleanTrue"),     NULL, 16);
    offset_osboolean_false  = strtoull(getenv("OSBooleanFalse"),    NULL, 16);
    offset_osunserializexml = strtoull(getenv("OSUnserializeXML"),  NULL, 16);
    offset_smalloc          = strtoull(getenv("Smalloc"),           NULL, 16);
    
    // tfp0, patchfinder, kexecute
    err = host_get_special_port(mach_host_self(), HOST_LOCAL_NODE, 4, &tfp0);
    if (err != KERN_SUCCESS) {
        DEBUGLOG(true, "host_get_special_port 4: %s", mach_error_string(err));
        return -1;
    }
    DEBUGLOG(true, "tfp0: %x", tfp0);
    
    init_kexecute();
    
    queue = dispatch_queue_create("jailbreakd.queue", NULL);
    
    // Set up mach stuff
    mach_port_t server_port;
    if ((err = bootstrap_check_in(bootstrap_port, "zone.sparkes.jailbreakd", &server_port))) {
        DEBUGLOG(true, "Failed to check in: %s", mach_error_string(err));
        return -1;
    }
    
    dispatch_source_t server = dispatch_source_create(DISPATCH_SOURCE_TYPE_MACH_RECV, server_port, 0, dispatch_get_main_queue());
    dispatch_source_set_event_handler(server, ^{
        dispatch_mig_server(server, jbd_jailbreak_daemon_subsystem.maxsize, jailbreak_daemon_server);
    });
    dispatch_resume(server);
    
    // Now ready for connections!
    DEBUGLOG(true, "mach server now running!");
    
    FILE *fd = fopen("/var/tmp/jailbreakd.pid", "w");
    fprintf(fd, "%d\n", getpid());
    fclose(fd);
    
    // Start accepting connections
    // This will block exec
    dispatch_main();
    
    return 0;
}
