#import <Foundation/Foundation.h>

#include <dlfcn.h>
#include <spawn.h>

#include <mach/mach.h>

#include "fishhook.h"
#include "jailbreak_daemonUser.h"

#define LAUNCHD_LOG_PATH    "/var/log/pspawn_hook_launchd.log"
#define XPCPROXY_LOG_PATH   "/var/log/pspawn_hook_xpcproxy.log"
#define OTHER_LOG_PATH      "/var/log/pspawn_hook_other.log"
FILE *log_file;
#define DEBUGLOG(fmt, args...)                                      \
do {                                                                \
    if (log_file == NULL) {                                         \
        const char *log_path;                                       \
        if (current_process == PROCESS_LAUNCHD) {                   \
            log_path = LAUNCHD_LOG_PATH;                            \
        } else if (current_process == PROCESS_XPCPROXY) {           \
            log_path = XPCPROXY_LOG_PATH;                           \
        } else if (current_process == PROCESS_OTHER) {              \
            log_path = OTHER_LOG_PATH;                              \
        }                                                           \
        log_file = fopen(log_path, "a");                            \
        if (log_file == NULL) break;                                \
    }                                                               \
    time_t seconds = time(NULL);                                    \
    char *time = ctime(&seconds);                                   \
    fprintf(log_file, "[%.*s] ", (int)strlen(time) - 1, time);      \
    fprintf(log_file, fmt "\n", ##args);                            \
    fflush(log_file);                                               \
} while(0);

#define PROC_PIDPATHINFO_MAXSIZE  (4 * MAXPATHLEN)
int proc_pidpath(pid_t pid, void *buffer, uint32_t buffersize);

#define JAILBREAKD_COMMAND_ENTITLE 1
#define JAILBREAKD_COMMAND_ENTITLE_AND_SIGCONT 2
#define JAILBREAKD_COMMAND_ENTITLE_AND_SIGCONT_FROM_XPCPROXY 3
#define JAILBREAKD_COMMAND_FIXUP_SETUID 4

#define FLAG_PLATFORMIZE (1 << 1)

enum CurrentProcess {
    PROCESS_LAUNCHD,
    PROCESS_XPCPROXY,
    PROCESS_OTHER
};
int current_process = PROCESS_OTHER;

kern_return_t bootstrap_look_up(mach_port_t port, const char *service, mach_port_t *server_port);

mach_port_t jbd_port;

dispatch_queue_t queue = NULL;

#define DYLD_INSERT             "DYLD_INSERT_LIBRARIES="
#define MAX_INJECT              1

#define PSPAWN_HOOK_DYLIB       "/usr/lib/pspawn_hook.dylib"
#define TWEAKLOADER_DYLIB       "/usr/lib/TweakLoader.dylib"
#define LIBJAILBREAK_DYLIB      "/usr/lib/libjailbreak.dylib"
#define AMFID_PAYLOAD_DYLIB     "/meridian/amfid_payload.dylib"

const char *xpcproxy_blacklist[] = {
    "com.apple.diagnosticd",    // syslog
    "MTLCompilerService",
    "com.apple.notifyd",        // fuck this daemon and everything it stands for
    "OTAPKIAssetTool",
    "FileProvider",             // seems to crash from oosb r/w etc
    "jailbreakd",               // gotta call to this
    "dropbear",
    "cfprefsd",
    NULL
};

bool is_blacklisted(const char *proc) {
    const char **blacklist = xpcproxy_blacklist;
    
    while (*blacklist) {
        if (strstr(proc, *blacklist)) {
            return true;
        }
        
        blacklist++;
    }
    
    return false;
}

typedef int (*pspawn_t)(pid_t *pid,
                        const char *path,
                        const posix_spawn_file_actions_t *file_actions,
                        posix_spawnattr_t *attrp,
                        const char *argv[],
                        const char *envp[]);

pspawn_t old_pspawn, old_pspawnp;

int fake_posix_spawn_common(pid_t *pid,
                            const char *path,
                            const posix_spawn_file_actions_t *file_actions,
                            posix_spawnattr_t *attrp,
                            const char *argv[],
                            const char *envp[],
                            pspawn_t old) {
    int retval = -1, ret = 0, ninject = 0;
    const char *inject[MAX_INJECT] = { NULL };
    
    pid_t child      = 0;
    char **newenvp   = NULL;
    char *insert_str = NULL;
    posix_spawnattr_t attr;
    
    if (!path || !argv || !envp) {
        DEBUGLOG("got some bullshit args: %p, %p, %p", path, argv, envp);
        goto out;
    }
    
    if (argv[1]) {
        DEBUGLOG("fake_posix_spawn_common: %s (arg1: %s)", path, argv[1]);
    } else {
        DEBUGLOG("fake_posix_spawn_common: %s", path);
    }
    
    int arg_c = 0;
    while (argv[arg_c] != NULL)
    {
        DEBUGLOG("arg[%d] = %s", arg_c, argv[arg_c]);
        
        arg_c++;
    }
    
    DEBUGLOG("got %d args", arg_c);
    
    switch (current_process) {
        case PROCESS_LAUNCHD:
            if (strcmp(path, "/usr/libexec/xpcproxy") == 0 &&
                argv[0] &&
                argv[1] &&
                strcmp(argv[1], "com.apple.MobileFileIntegrity") == 0 /* we're only interested in amfid */)
            {
                inject[ninject++] = PSPAWN_HOOK_DYLIB;
            }
            break;
        case PROCESS_XPCPROXY:
            if (strcmp(path, "/usr/libexec/amfid") == 0)
            {
                inject[ninject++] = AMFID_PAYLOAD_DYLIB;
                break;
            }
//            if (access(TWEAKLOADER_DYLIB, F_OK) == 0) {
//                inject[ninject++] = TWEAKLOADER_DYLIB;
//            }
            break;
    }
    
    if (ninject > MAX_INJECT) {
        DEBUGLOG("too much inject, yo! (%d)", ninject);
        goto out;
    }
    
    DEBUGLOG("Inject count: %d", ninject);
    
    if (ninject > 0) {
        if (!attrp) {
            ret = posix_spawnattr_init(&attr);
            if (ret != 0) {
                DEBUGLOG("posix_spawnattr_init: %s", strerror(ret));
                goto out;
            }
            
            attrp = &attr;
        }
        
        short flags;
        ret = posix_spawnattr_getflags(attrp, &flags);
        if (ret != 0) {
            DEBUGLOG("posix_spawnattr_getflags: %s", strerror(ret));
            goto out;
        }
        
        ret = posix_spawnattr_setflags(attrp, flags);
        if (ret != 0) {
            DEBUGLOG("posix_spawnattr_setflags: %s", strerror(ret));
            goto out;
        }
        
        DEBUGLOG("Env:");
        size_t nenv = 0;
        const char *insert = NULL;
        for (const char **ptr = envp; *ptr != NULL; ++ptr, ++nenv) {
            DEBUGLOG("\t%s", *ptr);
            if (strncmp(*ptr, DYLD_INSERT, strlen(DYLD_INSERT)) == 0) {
                insert = *ptr;
            }
        }
        
        ++nenv; // NULL
        if (!insert) ++nenv;
        
        newenvp = malloc(nenv * sizeof(*newenvp));
        if (!newenvp) {
            DEBUGLOG("malloc newenvp failed");
            goto out;
        }
        
        size_t slen = (insert ? strlen(insert) + 1 : strlen(DYLD_INSERT)) + strlen(inject[0]) + 1;
        for (size_t i = 1; i < ninject; i++) {
            slen += strlen(inject[i]) + 1;
        }
        
        insert_str = malloc(slen);
        if (!insert_str) {
            DEBUGLOG("malloc insert_str failed");
            goto out;
        }
        
        insert_str[0] = '\0';
        
        size_t start = 0;
        if (insert) {
            strcat(insert_str, insert);
            start = 0;
        } else {
            strcat(insert_str, DYLD_INSERT);
            strcat(insert_str, inject[0]);
            start = 1;
        }
        
        for (size_t i = start; i < ninject; i++) {
            strcat(insert_str, ":");
            strcat(insert_str, inject[i]);
        }
        
        nenv = 0;
        newenvp[nenv++] = insert_str;
        
        for (const char **ptr = envp; *ptr != NULL; ++ptr) {
            if (*ptr != insert) {
                newenvp[nenv++] = (char *)*ptr;
            }
        }
        newenvp[nenv++] = NULL;
        envp = (const char **)newenvp;
        
        DEBUGLOG("New Env:");
        for (const char **ptr = envp; *ptr != NULL; ++ptr) {
            DEBUGLOG("\t%s", *ptr);
        }
    }
    
    // Note: xpcproxy won't return from this call
    ret = old(&child, path, file_actions, attrp, argv, envp);
    if (ret != 0) {
        DEBUGLOG("posix_spawn: %s", strerror(ret));
        retval = ret;
        goto out;
    }
    DEBUGLOG("Spawned with pid: %d", child);
    
    if (pid) {
        *pid = child;
    }
    
    retval = 0;
    
out:;
    if (newenvp    != NULL)  free(newenvp);
    if (insert_str != NULL)  free(insert_str);
    if (attrp      == &attr) posix_spawnattr_destroy(&attr);
    
    return retval;
}

int fake_posix_spawn(pid_t *pid,
                     const char *file,
                     const posix_spawn_file_actions_t *file_actions,
                     posix_spawnattr_t *attrp,
                     const char *argv[],
                     const char *envp[]) {
    return fake_posix_spawn_common(pid, file, file_actions, attrp, argv, envp, old_pspawn);
}

int fake_posix_spawnp(pid_t *pid,
                      const char *file,
                      const posix_spawn_file_actions_t *file_actions,
                      posix_spawnattr_t *attrp,
                      const char *argv[],
                      const char *envp[]) {
    return fake_posix_spawn_common(pid, file, file_actions, attrp, argv, envp, old_pspawnp);
}

void rebind_pspawns(void) {
    struct rebinding rebindings[] = {
        { "posix_spawn",  (void *)fake_posix_spawn,  (void **)&old_pspawn },
        { "posix_spawnp", (void *)fake_posix_spawnp, (void **)&old_pspawnp }
    };
    
    rebind_symbols(rebindings, 2);
}

__attribute__ ((constructor))
static void ctor(void) {
    queue = dispatch_queue_create("pspawn.queue", NULL);
    
    char pathbuf[PROC_PIDPATHINFO_MAXSIZE];
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
    
    rebind_pspawns();
}
