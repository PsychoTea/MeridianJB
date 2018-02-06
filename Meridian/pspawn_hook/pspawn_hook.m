#include <dlfcn.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <spawn.h>
#include <sys/types.h>
#include <errno.h>
#include <stdlib.h>
#include <sys/sysctl.h>
#include <dlfcn.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netdb.h>
#include <pthread.h>
#include <Foundation/Foundation.h>
#include "fishhook.h"
#include "common.h"

#define LAUNCHD_LOG_PATH "/tmp/pspawn_hook_launchd.log"
#define XPCPROXY_LOG_PATH "/tmp/pspawn_hook_xpcproxy.log"
FILE *log_file;
#define DEBUGLOG(fmt, args...)                                      \
do {                                                                \
    if (log_file == NULL) {                                         \
        log_file = fopen((current_process == PROCESS_LAUNCHD) ?     \
                            LAUNCHD_LOG_PATH :                      \
                            XPCPROXY_LOG_PATH, "a");                \
        if (log_file == NULL) break;                                \
    }                                                               \
    fprintf(log_file, fmt "\n", ##args);                            \
    fflush(log_file);                                               \
} while(0);

enum CurrentProcess {
    PROCESS_LAUNCHD,
    PROCESS_XPCPROXY
};

int current_process = PROCESS_XPCPROXY;

#define PSPAWN_HOOK_DYLIB       "/meridian/pspawn_hook.dylib"
#define SBINJECT_PAYLOAD_DYLIB  "/usr/lib/SBInject.dylib"

const char* xpcproxy_blacklist[] = {
    "com.apple.diagnosticd",  // syslog
    "com.apple.ReportCrash",  // crash reporting
    "MTLCompilerService",     // ?_?
    "OTAPKIAssetTool",        // h_h
    "cfprefsd",               // o_o
    "jailbreakd",             // don't inject into jbd since we'd have to call to it
    NULL
};

bool is_blacklisted(char* proc) {
    const char **blacklist = xpcproxy_blacklist;
    
    while (*blacklist) {
        // i think this should be strcmp, but stek
        // tells me it should be strstr, so i take his word :)
        if (strstr(proc, *blacklist)) {
            return true;
        }
        
        ++blacklist;
    }
    
    return false;
}

typedef int (*pspawn_t)(pid_t * pid, const char* path, const posix_spawn_file_actions_t *file_actions, posix_spawnattr_t *attrp, char const* argv[], const char* envp[]);

pspawn_t old_pspawn, old_pspawnp;

int fake_posix_spawn_common(pid_t * pid, const char* path, const posix_spawn_file_actions_t *file_actions, posix_spawnattr_t *attrp, const char* argv[], const char* envp[], pspawn_t old) {
    DEBUGLOG("We got called (fake_posix_spawn)! %s", path);
    
    const char *inject_me = NULL;
    
    // is the process that's being called xpcproxy?
    // cus we wanna inject into that bitch
    if (current_process == PROCESS_LAUNCHD &&
        strcmp(path, "/usr/libexec/xpcproxy") == 0) {
        inject_me = PSPAWN_HOOK_DYLIB;
        
        // let's check the blacklist, we don't wanna be
        // injecting into certain procs, yano
        const char* called_bin = argv[1];
        if (called_bin != NULL) {
            if (is_blacklisted(called_bin)) {
                inject_me = NULL;
                DEBUGLOG("xpcproxy for '%s' which is in blacklist, not injecting", called_bin);
            }
        }
    } else if (current_process == PROCESS_XPCPROXY) {
        // if we're in xpcproxy just inject into fuckin everytin ;)
        inject_me = SBINJECT_PAYLOAD_DYLIB;
    }
    
    if (inject_me == NULL) {
        DEBUGLOG("Nothing to inject.");
        return old(pid, path, file_actions, attrp, argv, envp);
    }
    
    DEBUGLOG("Injecting %s into %s", inject_me, path);
    
    int envcount = 0;
    
    // This prints out the Env vars to the log, and grabs the position of
    // DYLD_INSERT_LIBRARIES, if it already exists
    // If not, the position will be equal to the end of the env args
    if (envp != NULL) {
        DEBUGLOG("Env: ");
        const char** currentenv = envp;
        while (*currentenv != NULL) {
            DEBUGLOG("\t%s", *currentenv);
            if (strstr(*currentenv, "DYLD_INSERT_LIBRARIES") == NULL) {
                envcount++;
            }
            currentenv++;
        }
    }
    
    char const** newenvp = malloc((envcount + 2) * sizeof(char **));
    int j = 0;
    for (int i = 0; i < envcount; i++) {
        if (strstr(envp[j], "DYLD_INSERT_LIBRARIES") != NULL) {
            continue;
        }
        newenvp[i] = envp[j];
        j++;
    }
    
    char *envp_inject = malloc(strlen("DYLD_INSERT_LIBRARIES=") + strlen(inject_me) + 1);
    
    envp_inject[0] = '\0';
    
    strcat(envp_inject, "DYLD_INSERT_LIBRARIES=");
    strcat(envp_inject, inject_me);
    
    newenvp[j] = envp_inject;
    newenvp[j + 1] = NULL;
    
    DEBUGLOG("New Env:");
    const char** currentenv = newenvp;
    while (*currentenv != NULL) {
        DEBUGLOG("\t%s", *currentenv);
        currentenv++;
    }
    
    posix_spawnattr_t attr;
    
    posix_spawnattr_t *newattrp = &attr;
    
    if (attrp) { /* add to existing attribs */
        newattrp = attrp;
        short flags;
        posix_spawnattr_getflags(attrp, &flags);
        flags |= POSIX_SPAWN_START_SUSPENDED;
        posix_spawnattr_setflags(attrp, flags);
    } else { /* set new attribs */
        posix_spawnattr_init(&attr);
        posix_spawnattr_setflags(&attr, POSIX_SPAWN_START_SUSPENDED);
    }
    
    int origret;
    
    if (current_process == PROCESS_XPCPROXY) {
        calljailbreakd(getpid(), JAILBREAKD_COMMAND_ENTITLE_AND_SIGCONT_FROM_XPCPROXY);
        closejailbreakfd();
        
        origret = old(pid, path, file_actions, newattrp, argv, newenvp);
    } else {
        int gotpid;
        origret = old(&gotpid, path, file_actions, newattrp, argv, newenvp);
        
        if (origret == 0) {
            calljailbreakd(gotpid, JAILBREAKD_COMMAND_ENTITLE_AND_SIGCONT);
        }
    }
    
    return origret;
}

int fake_posix_spawn(pid_t * pid, const char* file, const posix_spawn_file_actions_t *file_actions, posix_spawnattr_t *attrp, const char* argv[], const char* envp[]) {
    DEBUGLOG("fake_posix_spawn was called: %s", file);
    return fake_posix_spawn_common(pid, file, file_actions, attrp, argv, envp, old_pspawn);
}

int fake_posix_spawnp(pid_t * pid, const char* file, const posix_spawn_file_actions_t *file_actions, posix_spawnattr_t *attrp, const char* argv[], const char* envp[]) {
    DEBUGLOG("fake_posix_spawnp was called: %s", file);
    return fake_posix_spawn_common(pid, file, file_actions, attrp, argv, envp, old_pspawnp);
}

void rebind_pspawns(void) {
    struct rebinding rebindings[] = {
        { "posix_spawn", (void *)fake_posix_spawn, (void **)&old_pspawn },
        { "posix_spawnp", (void *)fake_posix_spawnp, (void **)&old_pspawnp },
    };
    
    rebind_symbols(rebindings, 2);
}

void* thd_func(void* arg) {
    DEBUGLOG("in a new thread!");
    rebind_pspawns();
    return NULL;
}

__attribute__ ((constructor))
static void ctor(void) {
    current_process = (getpid() == 1) ? PROCESS_LAUNCHD : PROCESS_XPCPROXY;
    
    DEBUGLOG("hello from pid %d", getpid());
    
    if (current_process == PROCESS_LAUNCHD) {
        pthread_t thd;
        pthread_create(&thd, NULL, thd_func, NULL);
        return;
    }
    
    rebind_pspawns();
}
