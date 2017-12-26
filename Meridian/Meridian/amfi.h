//
//  amfi.h
//  v0rtex-s
//
//  Created by Ben on 19/12/2017.
//  Copyright © 2017 Sticktron. All rights reserved.
//



void init_amfi(task_t task_for_port0);
void trust_files(const char *path);
void inject_trust(const char *path);

uint8_t *getCodeDirectory(const char* name);
uint8_t *getSHA256(uint8_t* code_dir);
uint32_t swap_uint32(uint32_t val);
