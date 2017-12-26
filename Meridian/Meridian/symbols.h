//
//  symbols.h
//  v0rtex-s
//
//  Created by Ben on 16/12/2017.
//  Copyright © 2017 Sticktron. All rights reserved.
//

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <strings.h>
#include "common.h"

extern uint64_t OFFSET_ZONE_MAP;
extern uint64_t OFFSET_KERNEL_MAP;
extern uint64_t OFFSET_KERNEL_TASK;
extern uint64_t OFFSET_REALHOST;
extern uint64_t OFFSET_BZERO;
extern uint64_t OFFSET_BCOPY;
extern uint64_t OFFSET_COPYIN;
extern uint64_t OFFSET_COPYOUT;
extern uint64_t OFFSET_CHGPROCCNT;
extern uint64_t OFFSET_KAUTH_CRED_REF;
extern uint64_t OFFSET_IPC_PORT_ALLOC_SPECIAL;
extern uint64_t OFFSET_IPC_KOBJECT_SET;
extern uint64_t OFFSET_IPC_PORT_MAKE_SEND;
extern uint64_t OFFSET_IOSURFACEROOTUSERCLIENT_VTAB;
extern uint64_t OFFSET_OSSERIALIZER_SERIALIZE;
extern uint64_t OFFSET_ROP_LDR_X0_X0_0x10;
extern uint64_t OFFSET_ROP_ADD_X0_X0_0x10;
extern uint64_t OFFSET_ROOT_MOUNT_V_NODE;

BOOL init_symbols(void);
