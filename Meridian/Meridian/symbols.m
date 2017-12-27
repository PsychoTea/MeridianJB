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
    
    // iPhone 7 (Global)
    if (strcmp(u.machine, "iPhone9,1") == 0)
    {
        if ([ver isEqual: @"Version 10.3.1 (Build 14E304)"])
        {
            OFFSET_ZONE_MAP                        = 0xfffffff007590478;
            OFFSET_KERNEL_MAP                      = 0xfffffff0075ec050;
            OFFSET_KERNEL_TASK                     = 0xfffffff0075ec048;
            OFFSET_REALHOST                        = 0xfffffff007572ba0;
            OFFSET_BZERO                           = 0xfffffff0070c1f80;
            OFFSET_BCOPY                           = 0xfffffff0070c1dc0;
            OFFSET_COPYIN                          = 0xfffffff0071c6134;
            OFFSET_COPYOUT                         = 0xfffffff0071c6414;
            OFFSET_ROOT_MOUNT_V_NODE               = 0xfffffff0075ec0b0;
            OFFSET_CHGPROCCNT                      = 0xfffffff0073d366c;
            OFFSET_KAUTH_CRED_REF                  = 0xfffffff0073ada04;
            OFFSET_IPC_PORT_ALLOC_SPECIAL          = 0xfffffff0070df05c;
            OFFSET_IPC_KOBJECT_SET                 = 0xfffffff0070f22b4;
            OFFSET_IPC_PORT_MAKE_SEND              = 0xfffffff0070deb80;
            OFFSET_IOSURFACEROOTUSERCLIENT_VTAB    = 0xfffffff006e4a238;
            OFFSET_ROP_ADD_X0_X0_0x10              = 0xfffffff0063c9398;
            OFFSET_OSSERIALIZER_SERIALIZE          = 0xfffffff007486530;
            OFFSET_ROP_LDR_X0_X0_0x10              = 0xfffffff006314a84;
            return TRUE;
        }
        
        if ([ver isEqual: @"Version 10.1.1 (Build 14B100)"])
        {
            OFFSET_ZONE_MAP                             = 0xfffffff0070c8090;
            OFFSET_KERNEL_MAP                           = 0xfffffff0075f6058;
            OFFSET_KERNEL_TASK                          = 0xfffffff0075f6050;
            OFFSET_REALHOST                             = 0xfffffff00757c898;
            OFFSET_BZERO                                = 0xfffffff0070c2140;
            OFFSET_BCOPY                                = 0xfffffff0070c1f80;
            OFFSET_COPYIN                               = 0xfffffff0071c890c;
            OFFSET_COPYOUT                              = 0xfffffff0071c8bec;
            OFFSET_CHGPROCCNT                           = 0xfffffff0073dc328;
            OFFSET_KAUTH_CRED_REF                       = 0xfffffff0073b61b8;
            OFFSET_IPC_PORT_ALLOC_SPECIAL               = 0xfffffff0070deb2c;
            OFFSET_IPC_KOBJECT_SET                      = 0xfffffff0070f1d14;
            OFFSET_IPC_PORT_MAKE_SEND                   = 0xfffffff0070de7e0;
            OFFSET_IOSURFACEROOTUSERCLIENT_VTAB         = 0xfffffff006e521e0;
            OFFSET_ROP_ADD_X0_X0_0x10                   = 0xfffffff0063ed29c;
            OFFSET_OSSERIALIZER_SERIALIZE               = 0xfffffff0074916b4;
            OFFSET_ROP_LDR_X0_X0_0x10                   = 0xfffffff006338ab8;
            OFFSET_ROOT_MOUNT_V_NODE                    = 0xfffffff0075f60b8;
            return TRUE;
        }
    }
    
    // iPhone 7 (GSM)
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
            OFFSET_CHGPROCCNT                           = 0xfffffff0073d366c;
            OFFSET_KAUTH_CRED_REF                       = 0xfffffff0073ada04;
            OFFSET_IPC_PORT_ALLOC_SPECIAL               = 0xfffffff0070df05c;
            OFFSET_IPC_KOBJECT_SET                      = 0xfffffff0070f22b4;
            OFFSET_IPC_PORT_MAKE_SEND                   = 0xfffffff0070deb80;
            OFFSET_IOSURFACEROOTUSERCLIENT_VTAB         = 0xfffffff006e4a238;
            OFFSET_OSSERIALIZER_SERIALIZE               = 0xfffffff007486530;
            OFFSET_ROP_ADD_X0_X0_0x10                   = 0xfffffff0064ff0a8;
            OFFSET_ROP_LDR_X0_X0_0x10                   = 0xfffffff0074cf02c;
            OFFSET_ROOT_MOUNT_V_NODE                    = 0xfffffff0075ec0b0;
            OFFSET_OSSERIALIZER_SERIALIZE          = 0xfffffff007486530;
            return TRUE;
        }
    }
    
    LOG("Device not supported. \n");
    return FALSE;
}
