//
//  amfi.m
//  Meridian
//
//  Created by Ben Sparkes on 19/12/2017.
//  Copyright © 2017 Ben Sparkes. All rights reserved.
//

#import "patchfinder64.h"
#import "kernel.h"
#import "amfi.h"
#import "helpers.h"
#import "ViewController.h"
#import "libjb.h"
#import <Foundation/Foundation.h>
#import <CommonCrypto/CommonDigest.h>
#import <mach-o/loader.h>
#import <mach-o/dyld_images.h>
#import <sys/stat.h>
#import <sys/event.h>
#import <dlfcn.h>
#import <pthread.h>
#import <sys/spawn.h>

uint64_t trust_cache;
uint64_t amficache;

void init_amfi() {
    trust_cache = find_trustcache();
    amficache = find_amficache();
    
    NSLog(@"[amfi] trust_cache = 0x%llx \n", trust_cache);
    NSLog(@"[amfi] amficache = 0x%llx \n", amficache);
}

int defecate_amfi() {
    NSLog(@"[amfi] amfid defecation has been reached");
    
    {
        // copy some files
        NSLog(@"[amfi] copying in our patches \n");
        
        unlink("/meridian/amfid_fucker");
        unlink("/meridian/amfid_payload.dylib");
        
        cp(bundled_file("amfid.tar"), "/meridian/amfid.tar");
        chdir("/meridian");
        untar(fopen("/meridian/amfid.tar", "r+"), "amfid.tar");
        
        NSLog(@"[amfi] fucker exists: %d", file_exists("/meridian/amfid_fucker"));
        NSLog(@"[amfi] payload exists: %d", file_exists("/meridian/amfid_payload.dylib"));
    }
    
    {
        // trust our payload
        NSLog(@"[amfi] trusting our patches \n");
        inject_trust("/meridian/amfid_fucker");
        inject_trust("/meridian/amfid_payload.dylib");
    }
    
    NSString *kernprocstring = [NSString stringWithFormat:@"%llu", kernprocaddr];
    NSLog(@"[amfi] sent kernprocaddr 0x%llx", kernprocaddr);
    
    char* prog_args[] =  {
        "/meridian/amfid_fucker",
        (char *)[kernprocstring UTF8String],
        NULL
    };
    
    pid_t pd;
    int rv = posix_spawn(&pd, "/meridian/amfid_fucker", NULL, NULL, prog_args, NULL);
    if (rv != 0) {
        NSLog(@"[amfi] there was an issue spawning amfid_fucker: ret code %d (%s)", rv, strerror(rv));
        return rv;
    }

    // i'm not sure if this is needed but i cba to test it without so w/e
    grant_csflags(pd);
    
    NSLog(@"[amfi] amfid_fucker spawned with pid %d", pd);
    
    return rv;
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
    
    uint8_t *codeDir = get_code_directory(path);
    if (codeDir == NULL) {
        NSLog(@"[amfi] was given null code dir for %s!", path);
        return;
    }
    
    uint8_t *hash = get_sha1(codeDir);
    memmove(fake_chain.hash[0], hash, 20);
    
    free(hash);
    
    uint64_t kernel_trust = 0;
    mach_vm_allocate(tfp0, &kernel_trust, sizeof(fake_chain), VM_FLAGS_ANYWHERE);
    
    kwrite(kernel_trust, &fake_chain, sizeof(fake_chain));
    wk64(trust_cache, kernel_trust);
    
    NSLog(@"[amfi] signed %s \n", path);
}

// creds to nullpixel
uint8_t *get_code_directory(const char* name) {
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
uint8_t *get_sha1(uint8_t* code_dir) {
    uint8_t *out = malloc(CC_SHA1_DIGEST_LENGTH);
    
    uint32_t* code_dir_int = (uint32_t*)code_dir;
    
    uint32_t realsize = 0;
    for (int j = 0; j < 10; j++) {
        if (swap_uint32(code_dir_int[j]) == 0xfade0c02) {
            realsize = swap_uint32(code_dir_int[j+1]);
            code_dir += 4*j;
        }
    }
    
    CC_SHA1(code_dir, realsize, out);
    
    return out;
}

uint32_t swap_uint32(uint32_t val) {
    val = ((val << 8) & 0xFF00FF00) | ((val >> 8) & 0xFF00FF);
    return (val << 16) | (val >> 16);
}
