//
//  helpers.h
//  Meridian
//
//  Created by Ben Sparkes on 30/12/2017.
//  Copyright © 2017 Ben Sparkes. All rights reserved.
//

#ifndef helpers_h
#define helpers_h

#include <stdio.h>

#define CS_GET_TASK_ALLOW       0x0000004    /* has get-task-allow entitlement */
#define CS_INSTALLER            0x0000008    /* has installer entitlement      */
#define CS_HARD                 0x0000100    /* don't load invalid pages       */
#define CS_RESTRICT             0x0000800    /* tell dyld to treat restricted  */
#define CS_PLATFORM_BINARY      0x4000000    /* this is a platform binary      */

#define JAILBREAKD_COMMAND_ENTITLE 1
#define JAILBREAKD_COMMAND_ENTITLE_AND_SIGCONT 2
#define JAILBREAKD_COMMAND_ENTITLE_AND_SIGCONT_FROM_XPCPROXY 3
#define JAILBREAKD_COMMAND_FIXUP_SETUID 4

int call_jailbreakd(int command, pid_t pid);
uint64_t find_proc_by_name(char* name);
uint64_t find_proc_by_pid(uint32_t pid);
uint32_t get_pid_for_name(char* name);
int uicache(void);
int start_launchdaemon(const char *path);
int respring(void);
int inject_library(pid_t pid, const char *path);
int killall(const char *procname, const char *kill);
int check_for_jailbreak(void);
char *itoa(long n);
int file_exists(const char *path);
void read_file(const char* path);
int cp(const char *from, const char *to);
char* bundled_file(const char *filename);
char* bundle_path(void);
int extract_bundle(const char* bundle_name, const char* directory);
int extract_bundle_tar(const char *bundle_name);
void touch_file(char *path);
char* concat(const char *s1, const char *s2);
void grant_csflags(pid_t pd);
int execprog(const char *prog, const char* args[]);
void restart_device(void);
double uptime(void);
void suspend_all_threads(void);
void resume_all_threads(void);

#endif
