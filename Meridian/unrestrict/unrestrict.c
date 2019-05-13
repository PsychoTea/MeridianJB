#import <sys/param.h>
#import <mach/mach.h>
#import <sys/stat.h>
#import <os/log.h>
#import <dirent.h>
#import "kern_utils.h"
#import "common.h"

FILE *log_file = NULL;

#define CS_OPS_STATUS           0       /* return status */
int csops(pid_t pid, unsigned int  ops, void * useraddr, size_t usersize);

bool MSunrestrict0(mach_port_t task) {
    if (!initialized) return true;

    char pathbuf[PROC_PIDPATHINFO_MAXSIZE];
    bzero(pathbuf, sizeof(pathbuf));

    pid_t pid;
    if ( (pid_for_task(task, &pid) != 0) || pid <= 1) {
        return true;
    }
    proc_pidpath(pid, pathbuf, sizeof(pathbuf));
    
    if (strcmp(pathbuf, "/usr/libexec/xpcproxy") == 0) {
        return true;
    }

    DEBUGLOG("%s: (%d) fixing up", pathbuf, pid);
    fixup(pid);
    
    return true;
}

bool MSrevalidate0(mach_port_t task) {
    if (!initialized) return true;

    char pathbuf[PROC_PIDPATHINFO_MAXSIZE];
    bzero(pathbuf, sizeof(pathbuf));

    pid_t pid;
    if ( (pid_for_task(task, &pid) != 0) || pid <= 1) {
        return true;
    }
    proc_pidpath(pid, pathbuf, sizeof(pathbuf));

    if (strcmp(pathbuf, "/usr/libexec/xpcproxy") == 0) {
        return true;
    }

    uint32_t status;
    if (csops(pid, CS_OPS_STATUS, &status, sizeof(status)) < 0)
        return true;

    if ((status & CS_VALID) == 0) {
        uint64_t proc = proc_find(pid);
        if (proc == 0) {
            DEBUGLOG("failed to find proc for pid %d!", pid);
            return true;
        }
        
        fixup_cs_valid(proc);
    }

    return true;
}
