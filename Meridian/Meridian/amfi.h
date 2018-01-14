//
//  amfi.h
//  Meridian
//
//  Created by Ben Sparkes on 19/12/2017.
//  Copyright © 2017 Ben Sparkes. All rights reserved.
//

void init_amfi(task_t task_for_port0);
int amfi_main_destroy(void);
void* amfi_main_destroy_thread(void* args);
int patch_amfi(mach_port_t amfi_port);
int get_kqueue_for_pid(pid_t pid);
void inject_trust(const char *path);

uint8_t *get_code_directory(const char* name);
uint8_t *get_sha1(uint8_t* code_dir);
uint32_t swap_uint32(uint32_t val);
