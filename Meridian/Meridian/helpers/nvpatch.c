/*
 * nvpatch.c - Patch kernel to unrestrict NVRAM variables
 *
 * Copyright (c) 2014 Samuel Groß
 * Copyright (c) 2016 Pupyshev Nikita
 * Copyright (c) 2017 Siguza
 */

#include <errno.h>              // errno
#include <stdio.h>              // fprintf, stderr
#include <stdlib.h>             // free, malloc
#include <string.h>             // memmem, strcmp, strnlen
#include <mach/vm_types.h>      // vm_address_t
#include <mach-o/loader.h>

#include "kernel.h"

#define MAX_HEADER_SIZE 0x4000

#define STRING_SEG  "__TEXT"
#define STRING_SEC  "__cstring"
#define OFVAR_SEG   "__DATA"
#define OFVAR_SEC   "__data"

enum
{
    kOFVarTypeBoolean = 1,
    kOFVarTypeNumber,
    kOFVarTypeString,
    kOFVarTypeData,
};

enum
{
    kOFVarPermRootOnly = 0,
    kOFVarPermUserRead,
    kOFVarPermUserWrite,
    kOFVarPermKernelOnly,
};

typedef struct
{
    vm_address_t name;
    uint32_t type;
    uint32_t perm;
    int32_t offset;
} OFVar;

typedef struct
{
    vm_address_t addr;
    vm_size_t len;
    char *buf;
} segment_t;

int nvpatch(const char *target) {
    struct mach_header_64 *hdr = malloc(MAX_HEADER_SIZE);
    if (hdr == NULL) return -1;
    memset(hdr, 0, MAX_HEADER_SIZE);
    
    kread(kernel_base, hdr, MAX_HEADER_SIZE);
    
    segment_t cstring = {
        .addr = 0,
        .len = 0,
        .buf = NULL,
    },
    data = {
        .addr = 0,
        .len = 0,
        .buf = NULL,
    };
    
    for (struct load_command *cmd = (struct load_command *)(hdr + 1),
                             *end = (struct load_command *)((char *)cmd + hdr->sizeofcmds);
         cmd < end;
         cmd = (struct load_command *)((char *)cmd + cmd->cmdsize)) {
        switch (cmd->cmd) {
            case LC_SEGMENT_64:
            {
                struct segment_command_64 *seg = (struct segment_command_64 *)cmd;
                struct section_64 *sec = (struct section_64 *)(seg + 1);
                
                for (size_t i = 0; i < seg->nsects; ++i) {
                    if (strcmp(sec[i].segname, STRING_SEG) == 0 &&
                        strcmp(sec[i].sectname, STRING_SEC) == 0) {
                        cstring.addr = sec[i].addr;
                        cstring.len = sec[i].size;
                        cstring.buf = malloc(cstring.len);
                        
                        kread(cstring.addr, cstring.buf, cstring.len);
                    } else if (strcmp(sec[i].segname, OFVAR_SEG) == 0 &&
                               strcmp(sec[i].sectname, OFVAR_SEC) == 0) {
                        data.addr = sec[i].addr;
                        data.len = sec[i].size;
                        data.buf = malloc(data.len);
                        
                        kread(data.addr, data.buf, data.len);
                    }
                }
            }
                
            default:
                break;
        }
    }
    
    if (cstring.buf == NULL) {
        printf("failed to find %s.%s section \n", STRING_SEG, STRING_SEC);
        return -2;
    }
    
    if (data.buf == NULL) {
        printf("failed to find %s.%s section \n", OFVAR_SEG, OFVAR_SEC);
        return -3;
    }
    
    char first[] = "little-endian?";
    char *str = memmem(cstring.buf, cstring.len, first, sizeof(first));
    if (str == NULL) {
        printf("failed to find string %s \n", first);
        return -4;
    }
    
    vm_address_t str_addr = (str - cstring.buf) + cstring.addr;
    printf("found string %s at %lx \n", first, str_addr);
    
    OFVar *gOFVars = NULL;
    for (vm_address_t *ptr = (vm_address_t *)data.buf,
                      *end = (vm_address_t *)&data.buf[data.len];
         ptr < end;
         ++ptr) {
        if (*ptr == str_addr) {
            gOFVars = (OFVar *)ptr;
            break;
        }
    }
    
    if (gOFVars == NULL) {
        printf("failed to find gOFVariables \n");
        return -5;
    }
    
    vm_address_t gOFAddr = ((char *)gOFVars - data.buf) + data.addr;
    printf("found gOFVariables at %lx \n", gOFAddr);
    
    size_t numvars = 0;
    size_t longest_name = 0;
    
    for (OFVar *var = gOFVars; (char *)var < &data.buf[data.len]; ++var) {
        if (var->name == 0) {
            break;
        }
        
        if (var->name < cstring.addr || var->name >= cstring.addr + cstring.len) {
            printf("gOFVariables[%lu].name is out of bounds \n", numvars);
            return -6;
        }
        
        char *name = &cstring.buf[var->name - cstring.addr];
        size_t maxlen = cstring.len - (name - cstring.buf);
        size_t namelen = strnlen(name, maxlen);
        if (namelen == maxlen) {
            printf("gOFVariables[%lu].name exceeds __cstring size \n", numvars);
            return -7;
        }
        
        for (size_t i = 0; i < namelen; ++i) {
            if (name[i] < 0x20 || name[i] > 0x7f) {
                printf("gOFVariables[%lu].name contains non-printable character: 0x%02x \n", numvars, name[i]);
                return -8;
            }
        }
        
        longest_name = namelen > longest_name ? namelen : longest_name;
        
        switch (var->type) {
            case kOFVarTypeBoolean:
            case kOFVarTypeNumber:
            case kOFVarTypeString:
            case kOFVarTypeData:
                break;
                
            default:
                printf("gOFVariables[%lu] has unknown type: 0x%x \n", numvars, var->type);
                return -9;
        }
        
        switch (var->perm) {
            case kOFVarPermRootOnly:
            case kOFVarPermUserRead:
            case kOFVarPermUserWrite:
            case kOFVarPermKernelOnly:
                break;
                
            default:
                printf("gOFVariables[%lu] has unknown permissions: 0x%x \n", numvars, var->perm);
                return -10;
        }
        
        ++numvars;
    }
    
    if (numvars <= 0) {
        printf("gOFVariables contains zero entries \n");
        return -11;
    }
    
    for (size_t i = 0; i < numvars; ++i) {
        char *name = &cstring.buf[gOFVars[i].name - cstring.addr];
        if (strcmp(name, target) == 0) {
            if (gOFVars[i].perm != kOFVarPermKernelOnly) {
                printf("target var %s is not set as kernel-only \n", target);
                goto done;
            }
            
            vm_size_t off = ((char *)&gOFVars[i].perm) - data.buf;
            uint32_t newperm = kOFVarPermUserWrite;
            kwrite(data.addr + off, &newperm, sizeof(newperm));
            printf("great success for var %s! \n", target);
            goto done;
        }
    }
    printf("failed to find variable %s! \n", target);
    return -13;
    
done:;
    
    free(cstring.buf);
    free(data.buf);
    free(hdr);
    
    return 0;
}

