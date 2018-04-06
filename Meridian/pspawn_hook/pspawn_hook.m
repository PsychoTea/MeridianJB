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
#include <mach/mach.h>
#include <pthread.h>
#include <Foundation/Foundation.h>
#include "fishhook.h"
#include "mach/jailbreak_daemonUser.h"

#define LAUNCHD_LOG_PATH    "/tmp/pspawn_hook_launchd.log"
#define XPCPROXY_LOG_PATH   "/tmp/pspawn_hook_xpcproxy.log"
#define OTHER_LOG_PATH      "/tmp/pspawn_hook_other.log"
FILE *log_file;
#define DEBUGLOG(fmt, args...)                                      \
do {                                                                \
    if (log_file == NULL) {                                         \
        const char *log_path;                                       \
        if (current_process == PROCESS_LAUNCHD) {                   \
            log_path = LAUNCHD_LOG_PATH;                            \
        } else if (current_process == PROCESS_XPCPROXY) {           \
            log_path = XPCPROXY_LOG_PATH;                           \
        } else {                                                    \
            log_path = OTHER_LOG_PATH;                              \
        }                                                           \
        log_file = fopen(log_path, "a");                            \
        if (log_file == NULL) break;                                \
    }                                                               \
    fprintf(log_file, fmt "\n", ##args);                            \
    fflush(log_file);                                               \
} while(0);

#define PROC_PIDPATHINFO_MAXSIZE  (4 * MAXPATHLEN)
int proc_pidpath(pid_t pid, void *buffer, uint32_t buffersize);

#define JAILBREAKD_COMMAND_ENTITLE 1
#define JAILBREAKD_COMMAND_ENTITLE_AND_SIGCONT 2
#define JAILBREAKD_COMMAND_ENTITLE_AND_SIGCONT_FROM_XPCPROXY 3
#define JAILBREAKD_COMMAND_FIXUP_SETUID 4

enum CurrentProcess {
    PROCESS_LAUNCHD,
    PROCESS_XPCPROXY,
    PROCESS_OTHER
};

int current_process = PROCESS_OTHER;

kern_return_t bootstrap_look_up(mach_port_t port, const char *service, mach_port_t *server_port);

mach_port_t jbd_port;

char pathbuf[PROC_PIDPATHINFO_MAXSIZE];

#define PSPAWN_HOOK_DYLIB       "/usr/lib/pspawn_hook.dylib"
#define TWEAKLOADER_DYLIB       "/usr/lib/TweakLoader.dylib"
#define AMFID_PAYLOAD_DYLIB     "/meridian/amfid_payload.dylib"

const char* xpcproxy_blacklist[] = {
    "com.apple.diagnosticd",        // syslog
    "com.apple.WebKit",             // O_o
    "MTLCompilerService",           // ?_?
    "OTAPKIAssetTool",              // h_h
    "cfprefsd",                     // o_o
    "FileProvider",                 // seems to crash from oosb r/w etc 
    "jailbreakd",                   // don't inject into jbd since we'd have to call to it
    NULL
};

bool is_blacklisted(const char* proc) {
    const char **blacklist = xpcproxy_blacklist;
    
    while (*blacklist) {
        if (strstr(proc, *blacklist)) {
            return true;
        }
        
        ++blacklist;
    }
    
    return false;
}

typedef int (*pspawn_t)(pid_t *pid, const char *path, const posix_spawn_file_actions_t *file_actions, posix_spawnattr_t *attrp, char const *argv[], const char *envp[]);

pspawn_t old_pspawn, old_pspawnp;

int fake_posix_spawn_common(pid_t *pid, const char *path, const posix_spawn_file_actions_t *file_actions, posix_spawnattr_t *attrp, char const *argv[], const char *envp[], pspawn_t old) {
    DEBUGLOG("fake_posix_spawn_common: %s", path);

    // TEMPORARY
    if (strcmp(path, "/usr/bin/xz") == 0 ||
        strcmp(path, "/Applications/Cydia.app/Cydia") == 0) {
        return old(pid, path, file_actions, attrp, argv, envp);
    }
    
    const char *inject_me = NULL;
    
    // is the process that's being called xpcproxy?
    // cus we wanna inject into that bitch
    if (current_process == PROCESS_LAUNCHD &&
        strcmp(path, "/usr/libexec/xpcproxy") == 0) {
        inject_me = PSPAWN_HOOK_DYLIB;                          /* inject pspawn into xpcproxy              */
        
        // let's check the blacklist, we don't wanna be
        // injecting into certain procs, yano
        const char* called_bin = argv[1];
        if (called_bin != NULL && is_blacklisted(called_bin)) {
            inject_me = NULL;
            DEBUGLOG("xpcproxy for '%s' which is in blacklist, not injecting", called_bin);
        }
    } else if (current_process == PROCESS_XPCPROXY) {
        if (strcmp(path, "/usr/libexec/amfid") == 0) {          /* patch amfid                              */
            inject_me = AMFID_PAYLOAD_DYLIB;
        } else if (access(TWEAKLOADER_DYLIB, F_OK) == 0) {      /* if twkldr is installed, load it + pspawn */
            inject_me = PSPAWN_HOOK_DYLIB ":" TWEAKLOADER_DYLIB;
        } else {                                                /* just load pspawn                         */
            inject_me = PSPAWN_HOOK_DYLIB;
        }
    } else if (current_process == PROCESS_OTHER) {              /* load pspawn for child entitlement        */
        inject_me = PSPAWN_HOOK_DYLIB;
    }
    
    if (inject_me == NULL) {
        DEBUGLOG("Nothing to inject.");
        return old(pid, path, file_actions, attrp, argv, envp);
    }
    
    DEBUGLOG("Injecting %s", inject_me);
    
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
    
    if (current_process == PROCESS_LAUNCHD) {
        int gotpid;
        origret = old(&gotpid, path, file_actions, newattrp, argv, newenvp);
        
        if (origret == 0) {
            if (pid != NULL) *pid = gotpid;
            jbd_call(jbd_port, JAILBREAKD_COMMAND_ENTITLE_AND_SIGCONT, gotpid);
        }
    } else {
        pid_t pidToCall = (current_process == PROCESS_OTHER) ? *pid : getpid();
        DEBUGLOG("calling with pid: %d", pidToCall);
        jbd_call(jbd_port, JAILBREAKD_COMMAND_ENTITLE_AND_SIGCONT_FROM_XPCPROXY, pidToCall);
        
        origret = old(pid, path, file_actions, newattrp, argv, newenvp);
    }
    
    return origret;
}

int fake_posix_spawn(pid_t * pid, const char *file, const posix_spawn_file_actions_t *file_actions, posix_spawnattr_t *attrp, const char *argv[], const char *envp[]) {
    return fake_posix_spawn_common(pid, file, file_actions, attrp, argv, envp, old_pspawn);
}

int fake_posix_spawnp(pid_t *pid, const char *file, const posix_spawn_file_actions_t *file_actions, posix_spawnattr_t *attrp, const char *argv[], const char *envp[]) {
    return fake_posix_spawn_common(pid, file, file_actions, attrp, argv, envp, old_pspawnp);
}

typedef int (*execl_t)(const char *name, const char *arg, ...);
execl_t old_execl;
int fake_execl(const char *name, const char *arg, ...) {
    DEBUGLOG("fake_execl has been called: %s", name);
    return old_execl(name, arg);
}

typedef int (*execle_t)(const char *name, const char *arg, ...);
execle_t old_execle;
int fake_execle(const char *name, const char *arg, ...) {
    DEBUGLOG("fake_execle has been called: %s", name);
    return old_execle(name, arg);
}

typedef int (*execlp_t)(const char *name, const char *arg);
execlp_t old_execlp;
int fake_execlp(const char *name, const char *arg) {
    DEBUGLOG("fake_execlp has been called: %s", name);
    return old_execlp(name, arg);
}

typedef int (*execv_t)(const char *name, char *const argv[]);
execv_t old_execv;
int fake_execv(const char *name, char *const argv[]) {
    DEBUGLOG("fake_execv has been called: %s", name);
    return old_execv(name, argv);
}

typedef int (*execvp_t)(const char *name, char *const argv[]);
execvp_t old_execvp;
int fake_execvp(const char *name, char *const argv[]) {
    DEBUGLOG("fake_execvp has been called: %s", name);
    return old_execvp(name, argv);
}

typedef int (*execvP_t)(const char *name, const char *path, char *const argv[]);
execvP_t old_execvP;
int fake_execvP(const char *name, const char *path, char *const argv[]) {
    DEBUGLOG("fake_execvP has been called: %s", name);
    return old_execvP(name, path, argv);
}

void rebind_pspawns(void) {
    struct rebinding rebindings[] = {
        { "posix_spawn", (void *)fake_posix_spawn, (void **)&old_pspawn },
        { "posix_spawnp", (void *)fake_posix_spawnp, (void **)&old_pspawnp },
        { "execl", (void *)fake_execl, (void **)&old_execl },
        { "execle", (void *)fake_execle, (void **)&old_execle },
        { "execlp", (void *)fake_execlp, (void **)&old_execlp },
        { "execv", (void *)fake_execv, (void **)&old_execv },
        { "execvp", (void *)fake_execvp, (void **)&old_execvp },
        { "execvP", (void *)fake_execvP, (void **)&old_execvP }
    };
    
    rebind_symbols(rebindings, 8);
}

void *thd_func(void *arg) {
    DEBUGLOG("in a new thread!");
    
    rebind_pspawns();
    return NULL;
}

__attribute__ ((constructor))
static void ctor(void) {
    // we have to set current_process before we can do any logging etc
    bzero(pathbuf, sizeof(pathbuf));
    proc_pidpath(getpid(), pathbuf, sizeof(pathbuf));
    
    if (getpid() == 1) {
        current_process = PROCESS_LAUNCHD;
    } else if (strcmp(pathbuf, "/usr/libexec/xpcproxy") == 0) {
        current_process = PROCESS_XPCPROXY;
    } else {
        current_process = PROCESS_OTHER;
    }
    
    DEBUGLOG("========================");
    DEBUGLOG("hello from pid %d", getpid());
    DEBUGLOG("my path: %s", pathbuf);
    
    if (current_process == PROCESS_LAUNCHD) {
        if (host_get_special_port(mach_host_self(), HOST_LOCAL_NODE, 15, &jbd_port)) {
            DEBUGLOG("Can't get hsp15 :(");
            return;
        }
        DEBUGLOG("got jbd port: %x", jbd_port);
        
        pthread_t thd;
        pthread_create(&thd, NULL, thd_func, NULL);
        return;
    }
    
    if (bootstrap_look_up(bootstrap_port, "zone.sparkes.jailbreakd", &jbd_port)) {
        DEBUGLOG("Can't get bootstrap port :(");
        return;
    }
    DEBUGLOG("got jbd port: %x", jbd_port);
    
    rebind_pspawns();
}
