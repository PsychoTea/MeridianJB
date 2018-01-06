//
//  offsets.h
//  Meridian
//
//  Created by Ben Sparkes on 30/12/2017.
//  Copyright © 2017 Ben Sparkes. All rights reserved.
//

#ifndef OFFSETS_H
#define OFFSETS_H

#include "common.h"

typedef struct
{
    kptr_t base;
    kptr_t sizeof_task;
    kptr_t task_itk_self;
    kptr_t task_itk_registered;
    kptr_t task_bsd_info;
    kptr_t proc_ucred;
    kptr_t vm_map_hdr;
    kptr_t ipc_space_is_task;
    kptr_t realhost_special;
    kptr_t iouserclient_ipc;
    kptr_t vtab_get_retain_count;
    kptr_t vtab_get_external_trap_for_index;
} offsets_t;

uint64_t OFFSET_ZONE_MAP;
uint64_t OFFSET_KERNEL_MAP;
uint64_t OFFSET_KERNEL_TASK;
uint64_t OFFSET_REALHOST;
uint64_t OFFSET_BZERO;
uint64_t OFFSET_BCOPY;
uint64_t OFFSET_COPYIN;
uint64_t OFFSET_COPYOUT;
uint64_t OFFSET_IPC_PORT_ALLOC_SPECIAL;
uint64_t OFFSET_IPC_KOBJECT_SET;
uint64_t OFFSET_IPC_PORT_MAKE_SEND;
uint64_t OFFSET_IOSURFACEROOTUSERCLIENT_VTAB;
uint64_t OFFSET_ROP_ADD_X0_X0_0x10;
uint64_t OFFSET_ROOTVNODE;
uint64_t OFFSET_CHGPROCCNT;
uint64_t OFFSET_KAUTH_CRED_REF;
uint64_t OFFSET_OSSERIALIZER_SERIALIZE;
uint64_t OFFSET_ROP_LDR_X0_X0_0x10;

static offsets_t struct_offsets;

int load_offsets(void);

#endif
