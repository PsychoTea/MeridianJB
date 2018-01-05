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
#include <dirent.h>
#include <unistd.h>
#include <sys/fcntl.h>
#include <sys/spawn.h>
#import <Foundation/Foundation.h>

int file_exists(char *path) {
    return access(path, F_OK) == -1;
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
    
    while (nread = read(fd_from, buf, sizeof buf), nread > 0)
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

char* bundled_file(char *filename) {
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

void touch_file(char *path, mode_t mode) {
    close(creat(path, mode));
}

// https://stackoverflow.com/questions/8465006/how-do-i-concatenate-two-strings-in-c
char* concat(const char *s1, const char *s2)
{
    char *result = malloc(strlen(s1)+strlen(s2)+1);
    strcpy(result, s1);
    strcat(result, s2);
    return result;
}

// creds to stek29 on this one
int execprog(uint64_t kern_ucred, const char *prog, const char* args[]) {
    if (args == NULL) {
        args = (const char **)&(const char*[]){ prog, NULL };
    }
    
    const char *logfile = [NSString stringWithFormat:@"/meridian/logs/%@-%lu",
                           [[NSMutableString stringWithUTF8String:prog] stringByReplacingOccurrencesOfString:@"/" withString:@"_"],
                           time(NULL)].UTF8String;
    printf("Spawning [ ");
    for (const char **arg = args; *arg != NULL; ++arg) {
        printf("'%s' ", *arg);
    }
    printf("] to logfile [ %s ] \n", logfile);
    
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
    
    printf("process spawned with pid %d \n", pd);
    
    #define CS_GET_TASK_ALLOW       0x0000004    /* has get-task-allow entitlement */
    #define CS_INSTALLER            0x0000008    /* has installer entitlement      */
    #define CS_HARD                 0x0000100    /* don't load invalid pages       */
    #define CS_RESTRICT             0x0000800    /* tell dyld to treat restricted  */
    #define CS_PLATFORM_BINARY      0x4000000    /* this is a platform binary      */
    
    /*
     1. read 8 bytes from proc+0x100 into self_ucred
     2. read 8 bytes from kern_ucred + 0x78 and write them to self_ucred + 0x78
     3. write 12 zeros to self_ucred + 0x18
     */
    
    int tries = 3;
    while (tries-- > 0) {
        sleep(1);
        uint64_t proc = rk64(kernprocaddr + 0x08);
        while (proc) {
            uint32_t pid = rk32(proc + 0x10);
            if (pid == pd) {
                uint32_t csflags = rk32(proc + 0x2a8);
                csflags = (csflags | CS_PLATFORM_BINARY | CS_INSTALLER | CS_GET_TASK_ALLOW) & ~(CS_RESTRICT  | CS_HARD);
                wk32(proc + 0x2a8, csflags);
                tries = 0;
                
                // i don't think this bit is implemented properly (note: it's really not)
                // i'll fix it at some point. promise.
                /*uint64_t self_ucred = rk64(proc + 0x100);
                uint32_t selfcred_temp = rk32(kern_ucred + 0x78);
                wk32(self_ucred + 0x78, selfcred_temp);
                
                for (int i = 0; i < 12; i++) {
                    wk32(self_ucred + 0x18 + (i * sizeof(uint32_t)), 0);
                }*/
                
                printf("gave elevated perms to pid %d \n", pid);
                // did we though?
                
                // original shit
                // kcall(find_copyout(), 3, proc+0x100, &self_ucred, sizeof(self_ucred));
                // kcall(find_bcopy(), 3, kern_ucred + 0x78, self_ucred + 0x78, sizeof(uint64_t));
                // kcall(find_bzero(), 2, self_ucred + 0x18, 12);
                break;
            }
            proc = rk64(proc + 0x08);
        }
    }
        
    int status;
    waitpid(pd, &status, 0);
    printf("'%s' exited with %d (sig %d)\n", prog, WEXITSTATUS(status), WTERMSIG(status));
    
    char buf[65] = {0};
    int fd = open(logfile, O_RDONLY);
    if (fd == -1) {
        perror("open logfile");
        return 1;
    }
    
    printf("contents of %s: \n ------------------------- \n", logfile);
    while(read(fd, buf, sizeof(buf) - 1) == sizeof(buf) - 1) {
        printf("%s", buf);
    }
    printf("%s", buf);
    printf("\n-------------------------\n");
    
    close(fd);
    remove(logfile);
    
    return 0;
}
