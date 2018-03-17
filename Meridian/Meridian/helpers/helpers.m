//
//  helpers.m
//  Meridian
//
//  Created by Ben Sparkes on 30/12/2017.
//  Copyright © 2017 Ben Sparkes. All rights reserved.
//

#include "helpers.h"
#include "ViewController.h"
#include "kernel.h"
#include "untar.h"
#include "amfi.h"
#include "jailbreak_daemonUser.h"
#include <dirent.h>
#include <unistd.h>
#include <dlfcn.h>
#include <sys/fcntl.h>
#include <sys/spawn.h>
#include <sys/stat.h>
#include <sys/sysctl.h>
#import <Foundation/Foundation.h>

int call_jailbreakd(int command, pid_t pid) {
    mach_port_t jbd_port;
    if (bootstrap_look_up(bootstrap_port, "zone.sparkes.jailbreakd", &jbd_port) != 0) {
        return -1;
    }
    
    return jbd_call(jbd_port, command, pid);
}

uint64_t find_proc_by_name(char* name) {
    uint64_t proc = rk64(kernprocaddr + 0x08);
    
    while (proc) {
        char proc_name[40] = { 0 };
        
        tfp0_kread(proc + 0x26c, proc_name, 40);
        
        if (!strcmp(name, proc_name)) {
            return proc;
        }
        
        proc = rk64(proc + 0x08);
    }
    
    return 0;
}

uint64_t find_proc_by_pid(uint32_t pid) {
    uint64_t proc = rk64(kernprocaddr + 0x08);
    
    while (proc) {
        uint32_t proc_pid = rk32(proc + 0x10);
        
        if (pid == proc_pid) {
            return proc;
        }
        
        proc = rk64(proc + 0x08);
    }
    
    return 0;
}

uint32_t get_pid_for_name(char* name) {
    uint64_t proc = find_proc_by_name(name);
    if (proc == 0) {
        return 0;
    }
    
    return rk32(proc + 0x10);
}

int uicache() {
    return execprog("/bin/uicache", NULL);
}

int start_launchdaemon(const char *path) {
    chmod(path, 0755);
    chown(path, 0, 0);
    return execprog("/bin/launchctl", (const char **)&(const char*[]) {
        "/bin/launchctl",
        "load",
        "-w",
        path,
        NULL
    });
}

int respring() {
    pid_t springBoard = get_pid_for_name("SpringBoard");
    if (springBoard == 0) {
        return 1;
    }
    
    kill(springBoard, 9);
    return 0;
}

int inject_library(pid_t pid, const char *path) {
    return execprog("/meridian/injector", (const char **)&(const char*[]) {
        "/meridian/injector",
        itoa(pid),
        path,
        NULL
    });
}

int killall(const char *procname, const char *kill) {
    return execprog("/usr/bin/killall", (const char **)&(const char *[]) {
        "/usr/bin/killall",
        kill,
        procname,
        NULL
    });
}

int check_for_jailbreak() {
    int csops(pid_t pid, unsigned int ops, void *useraddr, size_t usersize);
    
    uint32_t flags;
    csops(getpid(), 0, &flags, 0);
    
    return flags & CS_PLATFORM_BINARY;
}

char *itoa(long n) {
    int len = n==0 ? 1 : floor(log10l(labs(n)))+1;
    if (n<0) len++; // room for negative sign '-'
    
    char    *buf = calloc(sizeof(char), len+1); // +1 for null
    snprintf(buf, len+1, "%ld", n);
    return   buf;
}

// remember: returns 0 if file exists
int file_exists(const char *path) {
    return access(path, F_OK);
}

void read_file(const char *path) {
    char buf[65] = {0};
    int fd = open(path, O_RDONLY);
    if (fd == -1) {
        perror("open path");
        return;
    }
    
    printf("contents of %s: \n ------------------------- \n", path);
    while(read(fd, buf, sizeof(buf) - 1) == sizeof(buf) - 1) {
        printf("%s", buf);
    }
    printf("%s", buf);
    printf("\n-------------------------\n");
    
    close(fd);
}

int cp(const char *from, const char *to) {
    int fd_to, fd_from;
    char buf[4096];
    ssize_t nread;
    int saved_errno;
    
    fd_from = open(from, O_RDONLY);
    if (fd_from < 0)
        return -1;
    
    fd_to = open(to, O_WRONLY | O_CREAT | O_EXCL, 0666);
    if (fd_to < 0)
        goto out_error;
    
    while ((nread = read(fd_from, buf, sizeof buf)) > 0)
    {
        char *out_ptr = buf;
        ssize_t nwritten;
        
        do {
            nwritten = write(fd_to, out_ptr, nread);
            
            if (nwritten >= 0)
            {
                nread -= nwritten;
                out_ptr += nwritten;
            }
            else if (errno != EINTR)
            {
                goto out_error;
            }
        } while (nread > 0);
    }
    
    if (nread == 0)
    {
        if (close(fd_to) < 0)
        {
            fd_to = -1;
            goto out_error;
        }
        close(fd_from);
        
        /* Success! */
        return 0;
    }
    
out_error:
    saved_errno = errno;
    
    close(fd_from);
    if (fd_to >= 0)
        close(fd_to);
    
    errno = saved_errno;
    return -1;
}

char* bundled_file(const char *filename) {
    return concat(bundle_path(), filename);
}

char* bundle_path() {
    CFBundleRef mainBundle = CFBundleGetMainBundle();
    CFURLRef resourcesURL = CFBundleCopyResourcesDirectoryURL(mainBundle);
    int len = 4096;
    char* path = malloc(len);
    
    CFURLGetFileSystemRepresentation(resourcesURL, TRUE, (UInt8*)path, len);
    
    return concat(path, "/");
}

int extract_bundle(const char* bundle_name, const char* directory) {
    int ret;
    
    char *tarFile = malloc(strlen(bundle_name) +
                           strlen("/") +
                           strlen(bundle_name) +
                           3);
    
    strcpy(tarFile, directory);
    strcat(tarFile, "/");
    strcat(tarFile, bundle_name);
    
    ret = cp(bundled_file(bundle_name), tarFile);
    if (ret != 0) {
        return -10;
    }
    
    chdir(directory);
    
    ret = untar(fopen(tarFile, "r"), bundle_name);
    
    unlink(tarFile);
    
    return ret;
}

int extract_bundle_tar(const char *bundle_name) {
    const char *file_path = bundled_file(bundle_name);
    
    if (file_exists(file_path) != 0) {
        log_message([NSString stringWithFormat:@"Error, bundle file %s was not found at path %s!",
                     bundle_name, file_path]);
        return -1;
    }
    
    return execprog("/meridian/tar", (const char **)&(const char*[]) {
        "/meridian/tar",
        "--preserve-permissions",
        "--no-overwrite-dir",
        "-C",
        "/",
        "-xvf",
        file_path,
        NULL
    });
}

void touch_file(char *path) {
    fclose(fopen(path, "w+"));
}

// https://stackoverflow.com/questions/8465006/how-do-i-concatenate-two-strings-in-c
char* concat(const char *s1, const char *s2) {
    char *result = malloc(strlen(s1)+strlen(s2)+1);
    strcpy(result, s1);
    strcat(result, s2);
    return result;
}

void grant_csflags(pid_t pid) {    
    int tries = 3;
    while (tries-- > 0) {
        uint64_t proc = find_proc_by_pid(pid);
        if (proc == 0) {
            sleep(1);
            continue;
        }
        
        uint32_t csflags = rk32(proc + 0x2a8);
        csflags = (csflags |
                   CS_PLATFORM_BINARY |
                   CS_INSTALLER |
                   CS_GET_TASK_ALLOW)
                   & ~(CS_RESTRICT | CS_HARD);
        wk32(proc + 0x2a8, csflags);
        break;
    }
}

// creds to stek29 on this one
int execprog(const char *prog, const char* args[]) {
    if (args == NULL) {
        args = (const char **)&(const char*[]){ prog, NULL };
    }
    
    const char *logfile = [NSString stringWithFormat:@"/meridian/logs/%@-%lu",
                           [[NSMutableString stringWithUTF8String:prog] stringByReplacingOccurrencesOfString:@"/" withString:@"_"],
                           time(NULL)].UTF8String;
    
    NSString *prog_args = @"";
    for (const char **arg = args; *arg != NULL; ++arg) {
        prog_args = [prog_args stringByAppendingString:[NSString stringWithFormat:@"%s ", *arg]];
    }
    NSLog(@"[execprog] Spawning [ %@ ] to logfile [ %s ]", prog_args, logfile);
    
    int rv;
    posix_spawn_file_actions_t child_fd_actions;
    if ((rv = posix_spawn_file_actions_init (&child_fd_actions))) {
        perror ("posix_spawn_file_actions_init");
        return rv;
    }
    if ((rv = posix_spawn_file_actions_addopen (&child_fd_actions, STDOUT_FILENO, logfile,
                                                O_WRONLY | O_CREAT | O_TRUNC, 0666))) {
        perror ("posix_spawn_file_actions_addopen");
        return rv;
    }
    if ((rv = posix_spawn_file_actions_adddup2 (&child_fd_actions, STDOUT_FILENO, STDERR_FILENO))) {
        perror ("posix_spawn_file_actions_adddup2");
        return rv;
    }
    
    pid_t pd;
    if ((rv = posix_spawn(&pd, prog, &child_fd_actions, NULL, (char**)args, NULL))) {
        printf("posix_spawn error: %d (%s)\n", rv, strerror(rv));
        return rv;
    }
    
    NSLog(@"[execprog] Process spawned with pid %d", pd);
    
    grant_csflags(pd);
    
    int status;
    waitpid(pd, &status, 0);
    NSLog(@"'%s' exited with %d (sig %d)\n", prog, WEXITSTATUS(status), WTERMSIG(status));
    
    char buf[65] = {0};
    int fd = open(logfile, O_RDONLY);
    if (fd == -1) {
        perror("open logfile");
        return 1;
    }
    
    NSLog(@"contents of %s:", logfile);
    NSLog(@"-------------------------");
    NSString *outputString = @"";
    while(read(fd, buf, sizeof(buf) - 1) == sizeof(buf) - 1) {
        outputString = [outputString stringByAppendingString:[NSString stringWithFormat:@"%s", buf]];
    }
    NSLog(@"%@", outputString);
    NSLog(@"-------------------------");
    
    close(fd);
    remove(logfile);
    
    return 0;
}

// too lazy to find & add IOKit headers so here we are
typedef mach_port_t io_service_t;
typedef mach_port_t io_connect_t;
extern const mach_port_t kIOMasterPortDefault;
CFMutableDictionaryRef IOServiceMatching(const char *name) CF_RETURNS_RETAINED;
io_service_t IOServiceGetMatchingService(mach_port_t masterPort, CFDictionaryRef matching CF_RELEASES_ARGUMENT);
kern_return_t IOServiceOpen(io_service_t service, task_port_t owningTask, uint32_t type, io_connect_t *client);
kern_return_t IOConnectCallAsyncStructMethod(mach_port_t connection, uint32_t selector, mach_port_t wake_port, uint64_t *reference, uint32_t referenceCnt, const void *inputStruct, size_t inputStructCnt, void *outputStruct, size_t *outputStructCnt);

// credits to tihmstar
void restart_device() {
    // open user client
    CFMutableDictionaryRef matching = IOServiceMatching("IOSurfaceRoot");
    io_service_t service = IOServiceGetMatchingService(kIOMasterPortDefault, matching);
    io_connect_t connect = 0;
    IOServiceOpen(service, mach_task_self(), 0, &connect);
    
    // add notification port with same refcon multiple times
    mach_port_t port = 0;
    mach_port_allocate(mach_task_self(), MACH_PORT_RIGHT_RECEIVE, &port);
    uint32_t references;
    uint64_t input[3] = {0};
    input[1] = 1234;  // keep refcon the same value
    while (1) {
        IOConnectCallAsyncStructMethod(connect, 17, port, &references, 1, input, sizeof(input), NULL, NULL);
    }
}

// credits to tihmstar
double uptime() {
    struct timeval boottime;
    size_t len = sizeof(boottime);
    int mib[2] = { CTL_KERN, KERN_BOOTTIME };
    if (sysctl(mib, 2, &boottime, &len, NULL, 0) < 0) {
        return -1.0;
    }
    
    time_t bsec = boottime.tv_sec, csec = time(NULL);
    
    return difftime(csec, bsec);
}

// credits to tihmstar
void suspend_all_threads() {
    thread_act_t other_thread, current_thread;
    unsigned int thread_count;
    thread_act_array_t thread_list;
    
    current_thread = mach_thread_self();
    int result = task_threads(mach_task_self(), &thread_list, &thread_count);
    if (result == -1) {
        exit(1);
    }
    if (!result && thread_count) {
        for (unsigned int i = 0; i < thread_count; ++i) {
            other_thread = thread_list[i];
            if (other_thread != current_thread) {
                int kr = thread_suspend(other_thread);
                if (kr != KERN_SUCCESS) {
                    mach_error("thread_suspend:", kr);
                    exit(1);
                }
            }
        }
    }
}

// credits to tihmstar
void resume_all_threads() {
    thread_act_t other_thread, current_thread;
    unsigned int thread_count;
    thread_act_array_t thread_list;
    
    current_thread = mach_thread_self();
    int result = task_threads(mach_task_self(), &thread_list, &thread_count);
    if (!result && thread_count) {
        for (unsigned int i = 0; i < thread_count; ++i) {
            other_thread = thread_list[i];
            if (other_thread != current_thread) {
                int kr = thread_resume(other_thread);
                if (kr != KERN_SUCCESS) {
                    mach_error("thread_suspend:", kr);
                }
            }
        }
    }
}
