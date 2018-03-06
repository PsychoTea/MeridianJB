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

int load_offsets(void);

#endif
