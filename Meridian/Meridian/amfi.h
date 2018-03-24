//
//  amfi.h
//  Meridian
//
//  Created by Ben Sparkes on 19/12/2017.
//  Copyright © 2017 Ben Sparkes. All rights reserved.
//

void init_amfi(void);
int patch_amfi(mach_port_t amfi_port);
int get_kqueue_for_pid(pid_t pid);
void inject_trust(const char *path);

uint8_t *get_code_directory(const char* file_path, uint64_t file_off);
uint8_t *get_sha1(uint8_t* code_dir);
uint32_t swap_uint32(uint32_t val);
