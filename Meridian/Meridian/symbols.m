//
//  symbols.m
//  Meridian
//
//  Created by Ben Sparkes on 16/12/2017.
//  Copyright © 2017 Ben Sparkes. All rights reserved.
//

#include <sys/utsname.h>
#include "symbols.h"
#include "common.h"

uint64_t OFFSET_ZONE_MAP;
uint64_t OFFSET_KERNEL_MAP;
uint64_t OFFSET_KERNEL_TASK;
uint64_t OFFSET_REALHOST;
uint64_t OFFSET_BZERO;
uint64_t OFFSET_BCOPY;
uint64_t OFFSET_COPYIN;
uint64_t OFFSET_COPYOUT;
uint64_t OFFSET_CHGPROCCNT;
uint64_t OFFSET_KAUTH_CRED_REF;
uint64_t OFFSET_IPC_PORT_ALLOC_SPECIAL;
uint64_t OFFSET_IPC_KOBJECT_SET;
uint64_t OFFSET_IPC_PORT_MAKE_SEND;
uint64_t OFFSET_IOSURFACEROOTUSERCLIENT_VTAB;
uint64_t OFFSET_OSSERIALIZER_SERIALIZE;
uint64_t OFFSET_ROP_LDR_X0_X0_0x10;
uint64_t OFFSET_ROP_ADD_X0_X0_0x10;
uint64_t OFFSET_ROOT_MOUNT_V_NODE;

#import <sys/utsname.h>

BOOL init_symbols()
{
    NSString *ver = [[NSProcessInfo processInfo] operatingSystemVersionString];
    
    struct utsname u;
    uname(&u);
    
    LOG("Device: %s", u.machine);
    LOG("Device Name: %s", u.nodename);
    LOG("Device iOS Version: %@", ver);
    
    if (strcmp(u.machine, "iPhone9,3") == 0)
    {
        if ([ver  isEqual: @"Version 10.3.1 (Build 14E304)"])
        {
            OFFSET_ZONE_MAP                             = 0xfffffff007590478;
            OFFSET_KERNEL_MAP                           = 0xfffffff0075ec050;
            OFFSET_KERNEL_TASK                          = 0xfffffff0075ec048;
            OFFSET_REALHOST                             = 0xfffffff007572ba0;
            OFFSET_BZERO                                = 0xfffffff0070c1f80;
            OFFSET_BCOPY                                = 0xfffffff0070c1dc0;
            OFFSET_COPYIN                               = 0xfffffff0071c6134;
            OFFSET_COPYOUT                              = 0xfffffff0071c6414;
            OFFSET_CHGPROCCNT                           = 0xfffffff007049e4b;
            OFFSET_KAUTH_CRED_REF                       = 0xfffffff0073ada04;
            OFFSET_IPC_PORT_ALLOC_SPECIAL               = 0xfffffff0070df05c;
            OFFSET_IPC_KOBJECT_SET                      = 0xfffffff0070f22b4;
            OFFSET_IPC_PORT_MAKE_SEND                   = 0xfffffff0070deb80;
            OFFSET_IOSURFACEROOTUSERCLIENT_VTAB         = 0xfffffff006e4a238;
            OFFSET_ROP_ADD_X0_X0_0x10                   = 0xfffffff0064ff0a8;
            OFFSET_ROP_LDR_X0_X0_0x10                   = 0xfffffff0074cf02c;
            OFFSET_ROOT_MOUNT_V_NODE                    = 0xfffffff0075ec0b0;
        }
    }
    
    else if (strcmp(u.machine, "iPhone8,1") == 0)
    {
        if ([ver isEqual: @"Version 10.3.2 (Build 14F89)"])
        {
            OFFSET_ZONE_MAP                             = 0xfffffff007548478;
            OFFSET_KERNEL_MAP                           = 0xfffffff0075a4050;
            OFFSET_KERNEL_TASK                          = 0xfffffff0075a4048;
            OFFSET_REALHOST                             = 0xfffffff00752aba0;
            OFFSET_BZERO                                = 0xfffffff007081f80;
            OFFSET_BCOPY                                = 0xfffffff007081dc0;
            OFFSET_COPYIN                               = 0xfffffff0071806f4;
            OFFSET_COPYOUT                              = 0xfffffff0071808e8;
            OFFSET_IPC_PORT_ALLOC_SPECIAL               = 0xfffffff007099e94;
            OFFSET_IPC_KOBJECT_SET                      = 0xfffffff0070ad16c;
            OFFSET_IPC_PORT_MAKE_SEND                   = 0xfffffff0070999b8;
            OFFSET_IOSURFACEROOTUSERCLIENT_VTAB         = 0xfffffff006e7c9f8;
            OFFSET_ROP_ADD_X0_X0_0x10                   = 0xfffffff006b916b8;
            OFFSET_ROOT_MOUNT_V_NODE                    = 0xfffffff0075ec0b0;
        }
    }
    
    else if (strcmp(u.machine, "iPhone8,1") == 0)
    {
        if ([ver isEqual: @"Version 10.3.3 (Build 14G60)"])
        {
            OFFSET_ZONE_MAP                            = 0xfffffff007548478;
            OFFSET_KERNEL_MAP                          = 0xfffffff0075a4050;
            OFFSET_KERNEL_TASK                         = 0xfffffff0075a4048;
            OFFSET_REALHOST                            = 0xfffffff00752aba0;
            OFFSET_BZERO                               = 0xfffffff007081f80;
            OFFSET_BCOPY                               = 0xfffffff007081dc0;
            OFFSET_COPYIN                              = 0xfffffff0071803a0;
            OFFSET_COPYOUT                             = 0xfffffff007180594;
            OFFSET_CHGPROCCNT                          = 0xfffffff007049e01;
            OFFSET_KAUTH_CRED_REF                      = 0xfffffff007367c18;
            OFFSET_IPC_PORT_ALLOC_SPECIAL              = 0xfffffff007099e94;
            OFFSET_IPC_KOBJECT_SET                     = 0xfffffff0070ad16c;
            OFFSET_IPC_PORT_MAKE_SEND                  = 0xfffffff0070999b8;
            OFFSET_IOSURFACEROOTUSERCLIENT_VTAB        = 0xfffffff006e7c9f8;
            OFFSET_ROP_ADD_X0_X0_0x10                  = 0xfffffff006462174;
            OFFSET_ROP_LDR_X0_X0_0x10                  = 0xfffffff0073690d8;
            OFFSET_ROOT_MOUNT_V_NODE                   = 0xfffffff0075a40b0;
        }
    }
    
    else if (strcmp(u.machine, "iPhone6,1") == 0)
    {
        if ([ver isEqual: @"Version 10.3.3 (Build 14G60)"])
        {
            OFFSET_ZONE_MAP                             = 0xfffffff00754c478;
            OFFSET_KERNEL_MAP                           = 0xfffffff0075a8050;
            OFFSET_KERNEL_TASK                          = 0xfffffff0075a8048;
            OFFSET_REALHOST                             = 0xfffffff00752eba0;
            OFFSET_BZERO                                = 0xfffffff007081f80;
            OFFSET_BCOPY                                = 0xfffffff007081dc0;
            OFFSET_COPYIN                               = 0xfffffff007180e98;
            OFFSET_COPYOUT                              = 0xfffffff00718108c;
            OFFSET_IPC_PORT_ALLOC_SPECIAL               = 0xfffffff007099f14;
            OFFSET_IPC_KOBJECT_SET                      = 0xfffffff0070ad1ec;
            OFFSET_IPC_PORT_MAKE_SEND                   = 0xfffffff007099a38;
            OFFSET_IOSURFACEROOTUSERCLIENT_VTAB         = 0xfffffff006f25538;
            OFFSET_ROP_ADD_X0_X0_0x10                   = 0xfffffff006522174;
            OFFSET_ROOT_MOUNT_V_NODE                    = 0xfffffff0075a80b0;
        }
    }
    
    else
    {
        LOG("Device not supported.");
        return FALSE;
    }
    
    return TRUE;
}
