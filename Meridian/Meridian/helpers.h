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

uint64_t find_proc_by_name(char* name);
uint64_t find_proc_by_pid(uint32_t pid);
uint32_t get_pid_for_name(char* name);
int file_exists(char *path);
void read_file(const char* path);
int cp(const char *from, const char *to);
char* bundled_file(char *filename);
char* bundle_path(void);
void touch_file(char *path);
char* concat(const char *s1, const char *s2);
int execprog(uint64_t kern_ucred, const char *prog, const char* args[]);

#endif
