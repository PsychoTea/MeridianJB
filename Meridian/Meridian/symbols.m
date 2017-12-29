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

#include "./Offsets/iPhone6,1/14A403.h"
#include "./Offsets/iPhone6,1/14A456.h"
#include "./Offsets/iPhone6,1/14B100.h"
#include "./Offsets/iPhone6,1/14B150.h"
#include "./Offsets/iPhone6,1/14B72.h"
#include "./Offsets/iPhone6,1/14C92.h"
#include "./Offsets/iPhone6,1/14D27.h"
#include "./Offsets/iPhone6,1/14E277.iphone6.h"
//#include "./Offsets/iPhone6,1/14E277.iphone8b.h"
#include "./Offsets/iPhone6,1/14E304.iphone6.h"
//#include "./Offsets/iPhone6,1/14E304.iphone8b.h"
#include "./Offsets/iPhone6,1/14F89.iphone6.h"
//#include "./Offsets/iPhone6,1/14F89.iphone8b.h"
#include "./Offsets/iPhone6,1/14G60.iphone6.h"
//#include "./Offsets/iPhone6,1/14G60.iphone8b.h"
#include "./Offsets/iPhone6,2/14A403.h"
#include "./Offsets/iPhone6,2/14A456.h"
#include "./Offsets/iPhone6,2/14B100.h"
#include "./Offsets/iPhone6,2/14B150.h"
#include "./Offsets/iPhone6,2/14B72.h"
#include "./Offsets/iPhone6,2/14C92.h"
#include "./Offsets/iPhone6,2/14D27.h"
#include "./Offsets/iPhone6,2/14E277.iphone6.h"
//#include "./Offsets/iPhone6,2/14E277.iphone8b.h"
#include "./Offsets/iPhone6,2/14E304.iphone6.h"
//#include "./Offsets/iPhone6,2/14E304.iphone8b.h"
#include "./Offsets/iPhone6,2/14F89.iphone6.h"
//#include "./Offsets/iPhone6,2/14F89.iphone8b.h"
#include "./Offsets/iPhone6,2/14G60.iphone6.h"
//#include "./Offsets/iPhone6,2/14G60.iphone8b.h"
#include "./Offsets/iPhone7,1/14A403.n56.h"
#include "./Offsets/iPhone7,1/14A403.n66.h"
#include "./Offsets/iPhone7,1/14A456.n56.h"
#include "./Offsets/iPhone7,1/14A456.n66.h"
#include "./Offsets/iPhone7,1/14B100.n56.h"
#include "./Offsets/iPhone7,1/14B100.n66.h"
#include "./Offsets/iPhone7,1/14B150.n56.h"
#include "./Offsets/iPhone7,1/14B150.n66.h"
#include "./Offsets/iPhone7,1/14B72.n56.h"
#include "./Offsets/iPhone7,1/14B72.n66.h"
#include "./Offsets/iPhone7,1/14C92.n56.h"
#include "./Offsets/iPhone7,1/14C92.n66.h"
#include "./Offsets/iPhone7,1/14D27.n56.h"
#include "./Offsets/iPhone7,1/14D27.n66.h"
#include "./Offsets/iPhone7,1/14E277.iphone7.h"
#include "./Offsets/iPhone7,1/14E277.n66.h"
#include "./Offsets/iPhone7,1/14E304.iphone7.h"
#include "./Offsets/iPhone7,1/14E304.n66.h"
#include "./Offsets/iPhone7,1/14F89.iphone7.h"
#include "./Offsets/iPhone7,1/14F89.n66.h"
#include "./Offsets/iPhone7,1/14G60.iphone7.h"
#include "./Offsets/iPhone7,1/14G60.n66.h"
#include "./Offsets/iPhone7,2/14A403.n61.h"
#include "./Offsets/iPhone7,2/14A403.n71.h"
#include "./Offsets/iPhone7,2/14A456.n61.h"
#include "./Offsets/iPhone7,2/14A456.n71.h"
#include "./Offsets/iPhone7,2/14B100.n61.h"
#include "./Offsets/iPhone7,2/14B100.n71.h"
#include "./Offsets/iPhone7,2/14B150.n61.h"
#include "./Offsets/iPhone7,2/14B150.n71.h"
#include "./Offsets/iPhone7,2/14B72.n61.h"
#include "./Offsets/iPhone7,2/14B72.n71.h"
#include "./Offsets/iPhone7,2/14C92.n61.h"
#include "./Offsets/iPhone7,2/14C92.n71.h"
#include "./Offsets/iPhone7,2/14D27.n61.h"
#include "./Offsets/iPhone7,2/14D27.n71.h"
#include "./Offsets/iPhone7,2/14E277.iphone7.h"
#include "./Offsets/iPhone7,2/14E277.n71.h"
#include "./Offsets/iPhone7,2/14E304.iphone7.h"
#include "./Offsets/iPhone7,2/14E304.n71.h"
#include "./Offsets/iPhone7,2/14F89.iphone7.h"
#include "./Offsets/iPhone7,2/14F89.n71.h"
#include "./Offsets/iPhone7,2/14G60.iphone7.h"
#include "./Offsets/iPhone7,2/14G60.n71.h"
#include "./Offsets/iPhone8,1/14A403.n61.h"
#include "./Offsets/iPhone8,1/14A403.n71.h"
#include "./Offsets/iPhone8,1/14A456.n61.h"
#include "./Offsets/iPhone8,1/14A456.n71.h"
#include "./Offsets/iPhone8,1/14B100.n61.h"
#include "./Offsets/iPhone8,1/14B100.n71.h"
#include "./Offsets/iPhone8,1/14B150.n61.h"
#include "./Offsets/iPhone8,1/14B150.n71.h"
#include "./Offsets/iPhone8,1/14B72.n61.h"
#include "./Offsets/iPhone8,1/14B72.n71.h"
#include "./Offsets/iPhone8,1/14C92.n61.h"
#include "./Offsets/iPhone8,1/14C92.n71.h"
#include "./Offsets/iPhone8,1/14D27.n61.h"
#include "./Offsets/iPhone8,1/14D27.n71.h"
#include "./Offsets/iPhone8,1/14E277.iphone7.h"
#include "./Offsets/iPhone8,1/14E277.n71.h"
#include "./Offsets/iPhone8,1/14E304.iphone7.h"
#include "./Offsets/iPhone8,1/14E304.n71.h"
#include "./Offsets/iPhone8,1/14F89.iphone7.h"
#include "./Offsets/iPhone8,1/14F89.n71.h"
#include "./Offsets/iPhone8,1/14G60.iphone7.h"
#include "./Offsets/iPhone8,1/14G60.n71.h"
#include "./Offsets/iPhone8,2/14A403.n56.h"
#include "./Offsets/iPhone8,2/14A403.n66.h"
#include "./Offsets/iPhone8,2/14A456.n56.h"
#include "./Offsets/iPhone8,2/14A456.n66.h"
#include "./Offsets/iPhone8,2/14B100.n56.h"
#include "./Offsets/iPhone8,2/14B100.n66.h"
#include "./Offsets/iPhone8,2/14B150.n56.h"
#include "./Offsets/iPhone8,2/14B150.n66.h"
#include "./Offsets/iPhone8,2/14B72.n56.h"
#include "./Offsets/iPhone8,2/14B72.n66.h"
#include "./Offsets/iPhone8,2/14C92.n56.h"
#include "./Offsets/iPhone8,2/14C92.n66.h"
#include "./Offsets/iPhone8,2/14D27.n56.h"
#include "./Offsets/iPhone8,2/14D27.n66.h"
#include "./Offsets/iPhone8,2/14E277.iphone7.h"
#include "./Offsets/iPhone8,2/14E277.n66.h"
#include "./Offsets/iPhone8,2/14E304.iphone7.h"
#include "./Offsets/iPhone8,2/14E304.n66.h"
#include "./Offsets/iPhone8,2/14F89.iphone7.h"
#include "./Offsets/iPhone8,2/14F89.n66.h"
#include "./Offsets/iPhone8,2/14G60.iphone7.h"
#include "./Offsets/iPhone8,2/14G60.n66.h"
#include "./Offsets/iPhone8,4/14A403.h"
#include "./Offsets/iPhone8,4/14A456.h"
#include "./Offsets/iPhone8,4/14B100.h"
#include "./Offsets/iPhone8,4/14B150.h"
#include "./Offsets/iPhone8,4/14B72.h"
#include "./Offsets/iPhone8,4/14C92.h"
#include "./Offsets/iPhone8,4/14D27.h"
#include "./Offsets/iPhone8,4/14E277.iphone6.h"
//#include "./Offsets/iPhone8,4/14E277.iphone8b.h"
#include "./Offsets/iPhone8,4/14E304.iphone6.h"
//#include "./Offsets/iPhone8,4/14E304.iphone8b.h"
#include "./Offsets/iPhone8,4/14F89.iphone6.h"
//#include "./Offsets/iPhone8,4/14F89.iphone8b.h"
#include "./Offsets/iPhone8,4/14G60.iphone6.h"
//#include "./Offsets/iPhone8,4/14G60.iphone8b.h"
#include "./Offsets/iPhone9,1/14A403.h"
#include "./Offsets/iPhone9,1/14A456.h"
#include "./Offsets/iPhone9,1/14A551.h"
#include "./Offsets/iPhone9,1/14B100.h"
#include "./Offsets/iPhone9,1/14B150.h"
#include "./Offsets/iPhone9,1/14B72c.h"
#include "./Offsets/iPhone9,1/14C92.h"
#include "./Offsets/iPhone9,1/14D27.h"
#include "./Offsets/iPhone9,1/14E277.h"
#include "./Offsets/iPhone9,1/14E304.h"
#include "./Offsets/iPhone9,1/14F89.h"
#include "./Offsets/iPhone9,1/14G60.h"
#include "./Offsets/iPhone9,2/14A403.h"
#include "./Offsets/iPhone9,2/14A456.h"
#include "./Offsets/iPhone9,2/14A551.h"
#include "./Offsets/iPhone9,2/14B100.h"
#include "./Offsets/iPhone9,2/14B150.h"
#include "./Offsets/iPhone9,2/14B72c.h"
#include "./Offsets/iPhone9,2/14C92.h"
#include "./Offsets/iPhone9,2/14D27.h"
#include "./Offsets/iPhone9,2/14E277.h"
#include "./Offsets/iPhone9,2/14E304.h"
#include "./Offsets/iPhone9,2/14F89.h"
#include "./Offsets/iPhone9,2/14G60.h"
#include "./Offsets/iPhone9,3/14A403.h"
#include "./Offsets/iPhone9,3/14A456.h"
#include "./Offsets/iPhone9,3/14A551.h"
#include "./Offsets/iPhone9,3/14B100.h"
#include "./Offsets/iPhone9,3/14B150.h"
#include "./Offsets/iPhone9,3/14B72c.h"
#include "./Offsets/iPhone9,3/14C92.h"
#include "./Offsets/iPhone9,3/14D27.h"
#include "./Offsets/iPhone9,3/14E277.h"
#include "./Offsets/iPhone9,3/14E304.h"
#include "./Offsets/iPhone9,3/14F89.h"
#include "./Offsets/iPhone9,3/14G60.h"
#include "./Offsets/iPhone9,4/14A403.h"
#include "./Offsets/iPhone9,4/14A456.h"
#include "./Offsets/iPhone9,4/14A551.h"
#include "./Offsets/iPhone9,4/14B100.h"
#include "./Offsets/iPhone9,4/14B150.h"
#include "./Offsets/iPhone9,4/14B72c.h"
#include "./Offsets/iPhone9,4/14C92.h"
#include "./Offsets/iPhone9,4/14D27.h"
#include "./Offsets/iPhone9,4/14E277.h"
#include "./Offsets/iPhone9,4/14E304.h"
#include "./Offsets/iPhone9,4/14F89.h"
#include "./Offsets/iPhone9,4/14G60.h"
#include "./Offsets/iPod7,1/14A403.h"
#include "./Offsets/iPod7,1/14A456.h"
#include "./Offsets/iPod7,1/14B100.h"
#include "./Offsets/iPod7,1/14B150.h"
#include "./Offsets/iPod7,1/14B72.h"
#include "./Offsets/iPod7,1/14C92.h"
#include "./Offsets/iPod7,1/14D27.h"
#include "./Offsets/iPod7,1/14E277.h"
#include "./Offsets/iPod7,1/14E304.h"
#include "./Offsets/iPod7,1/14F89.h"
#include "./Offsets/iPod7,1/14G60.h"

#import <sys/utsname.h>
#import <sys/sysctl.h>

BOOL init_symbols()
{
//    NSString *ver = [[NSProcessInfo processInfo] operatingSystemVersionString];
//
//    struct utsname u;
//    uname(&u);

    // creds: arx8x from v0rtexNonce/offsets.m

    int d_prop[2] = { CTL_HW, HW_MACHINE };
    char model[20];
    size_t d_prop_len = sizeof(model);
    sysctl(d_prop, 2, model, &d_prop_len, NULL, 0);
    
    int version_prop[2] = { CTL_KERN, KERN_OSVERSION };
    char build[20];
    size_t version_prop_len = sizeof(build);
    sysctl(version_prop, 2, build, &version_prop_len, NULL, 0);
    
//    LOG("Device: %s", u.machine);
//    LOG("Device Name: %s", u.nodename);
//    LOG("Device iOS Version: %@", ver);
    
    printf("%s \n", model);
    printf("%s \n", build);
    
    return FALSE;
    
    /*
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
            return TRUE;
        }
    }*/
    
    LOG("Device not supported. \n");
    return FALSE;
}
