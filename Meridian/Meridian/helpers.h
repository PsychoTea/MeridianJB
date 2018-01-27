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
int uicache(void);
char *itoa(long n);
int file_exists(char *path);
void read_file(const char* path);
int cp(const char *from, const char *to);
char* bundled_file(char *filename);
char* bundle_path(void);
void extract_bundle(char* bundle_name, char* directory);
void touch_file(char *path);
char* concat(const char *s1, const char *s2);
void grant_csflags(pid_t pd);
int execprog(const char *prog, const char* args[]);

#endif
