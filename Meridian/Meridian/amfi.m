//
//  amfi.m
//  v0rtex
//
//  Created by Ben on 19/12/2017.
//  Copyright © 2017 Sticktron. All rights reserved.
//

#import "patchfinder64.h"
#import "libjb.h"
#import "kernel.h"
#import "amfi.h"
#import <Foundation/Foundation.h>
#import <CommonCrypto/CommonDigest.h>
#import <mach-o/loader.h>

task_t tfp0;
uint64_t trust_cache;
uint64_t amficache;

void init_amfi(task_t task_for_port0) {
    tfp0 = task_for_port0;
    trust_cache = find_trustcache();
    amficache = find_amficache();
    
    term_kernel();
    
    printf("trust_cache = 0x%llx \n", trust_cache);
    printf("amficache = 0x%llx \n", amficache);
}

// creds to xerub for grab_hashes (and ty for libjb update!)
void trust_files(const char *path) {
    struct trust_mem mem;
    mem.next = rk64(trust_cache);
    *(uint64_t *)&mem.uuid[0] = 0xabadbabeabadbabe;
    *(uint64_t *)&mem.uuid[8] = 0xabadbabeabadbabe;
    
    grab_hashes(path, tfp0_kread, amficache, mem.next);
    
    size_t length = (sizeof(mem) + numhash * 20 + 0xFFFF) & ~0xFFFF;
    
    uint64_t kernel_trust;
    mach_vm_allocate(tfp0, (mach_vm_address_t *)&kernel_trust, length, VM_FLAGS_ANYWHERE);
    
    mem.count = numhash;
    kwrite(kernel_trust, &mem, sizeof(mem));
    kwrite(kernel_trust + sizeof(mem), allhash, numhash * 20);
    kwrite_uint64(trust_cache, kernel_trust);
    
    free(allhash);
    free(allkern);
    free(amfitab);
    
    printf("[amfi] get fucked @ %s (%d files) \n", path, numhash);
}

// creds to stek29(?)
void inject_trust(const char *path) {
    typedef char hash_t[20];
    
    struct trust_chain {
        uint64_t next;
        unsigned char uuid[16];
        unsigned int count;
        hash_t hash[1];
    };
    
    struct trust_chain fake_chain;
    
    fake_chain.next = rk64(trust_cache);
    *(uint64_t *)&fake_chain.uuid[0] = 0xabadbabeabadbabe;
    *(uint64_t *)&fake_chain.uuid[8] = 0xabadbabeabadbabe;
    fake_chain.count = 1;
    
    uint8_t *codeDir = getCodeDirectory(path);
    if (codeDir == NULL) {
        printf("[amfi] was given null code dir for %s ! \n", path);
        return;
    }
    
    uint8_t *hash = getSHA256(codeDir);
    memmove(fake_chain.hash[0], hash, 20);
    
    free(hash);
    
    uint64_t kernel_trust = 0;
    mach_vm_allocate(tfp0, &kernel_trust, sizeof(fake_chain), VM_FLAGS_ANYWHERE);
    
    kwrite(kernel_trust, &fake_chain, sizeof(fake_chain));
    wk64(trust_cache, kernel_trust);
    
    printf("[amfi] signed %s \n", path);
}

// creds to nullpixel
uint8_t *getCodeDirectory(const char* name) {
    FILE* fd = fopen(name, "r");
    
    struct mach_header_64 mh;
    fread(&mh, sizeof(struct mach_header_64), 1, fd);
    
    long off = sizeof(struct mach_header_64);
    for (int i = 0; i < mh.ncmds; i++) {
        const struct load_command cmd;
        fseek(fd, off, SEEK_SET);
        fread(&cmd, sizeof(struct load_command), 1, fd);
        if (cmd.cmd == 0x1d) {
            uint32_t off_cs;
            fread(&off_cs, sizeof(uint32_t), 1, fd);
            uint32_t size_cs;
            fread(&size_cs, sizeof(uint32_t), 1, fd);
            
            uint8_t *cd = malloc(size_cs);
            fseek(fd, off_cs, SEEK_SET);
            fread(cd, size_cs, 1, fd);
            
            return cd;
        } else {
            off += cmd.cmdsize;
        }
    }
    
    return NULL;
}

// creds to nullpixel
uint8_t *getSHA256(uint8_t* code_dir) {
    uint8_t *out = malloc(CC_SHA256_DIGEST_LENGTH);
    
    uint32_t* code_dir_int = (uint32_t*)code_dir;
    
    uint32_t realsize = 0;
    for (int j = 0; j < 10; j++) {
        if (swap_uint32(code_dir_int[j]) == 0xfade0c02) {
            realsize = swap_uint32(code_dir_int[j+1]);
            code_dir += 4*j;
        }
    }
    
    CC_SHA256(code_dir, realsize, out);
    
    return out;
}

uint32_t swap_uint32(uint32_t val) {
    val = ((val << 8) & 0xFF00FF00) | ((val >> 8) & 0xFF00FF);
    return (val << 16) | (val >> 16);
}
