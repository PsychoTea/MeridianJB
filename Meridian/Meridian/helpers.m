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
#include "libjb.h"
#include <dirent.h>
#include <unistd.h>
#include <sys/fcntl.h>
#include <sys/spawn.h>
#include <sys/stat.h>
#import <Foundation/Foundation.h>

uint64_t find_proc_by_name(char* name) {
    uint64_t proc = rk64(kernprocaddr + 0x08);
    
    while (proc) {
        char proc_name[40] = { 0 };
        
        tfp0_kread(proc + 0x26c, proc_name, 40);
        
        if (!strcmp(proc_name, name)) {
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
        
        if (proc_pid == pid) {
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
    return execprog("/meridian/bins/uicache", NULL);
}

char *itoa(long n) {
    int len = n==0 ? 1 : floor(log10l(labs(n)))+1;
    if (n<0) len++; // room for negative sign '-'
    
    char    *buf = calloc(sizeof(char), len+1); // +1 for null
    snprintf(buf, len+1, "%ld", n);
    return   buf;
}

int file_exists(const char *path) {
    return access(path, F_OK) == -1;
}

int file_exist(const char *filename) {
    struct stat buffer;
    int r = stat(filename, &buffer);
    return (r == 0);
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

void extract_bundle(const char* bundle_name, const char* directory) {
    char tarFile[100];
    strcpy(tarFile, directory);
    strcat(tarFile, "/");
    strcat(tarFile, bundle_name);
    
    cp(bundled_file(bundle_name), tarFile);
    
    chdir(directory);
    
    untar(fopen(tarFile, "r"), bundle_name);
    
    unlink(tarFile);
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
