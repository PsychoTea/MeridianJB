// Massive creds to @theninjaprawn for his async_wake fork & help getting this patch to work :)
// [2018-3-14] big thanks for stek for letting me use his code on proper blob parsing :) -> https://github.com/stek29/electra/blob/amfid_fix/basebinaries/amfid_payload/

#include <dlfcn.h>
#include <stdio.h>
#include <unistd.h>
#include <sys/types.h>
#include <mach/mach.h>
#include <mach-o/loader.h>
#include <mach-o/fat.h>
#include <mach/error.h>
#include <errno.h>
#include <stdlib.h>
#include <sys/sysctl.h>
#include <dlfcn.h>
#include <sys/mman.h>
#include <spawn.h>
#include <sys/stat.h>
#include <pthread.h>
#include <Foundation/Foundation.h>
#include <CommonCrypto/CommonDigest.h>
#include "cs_blobs.h"
#include "fishhook.h"

kern_return_t mach_vm_write(vm_map_t target_task,
                            mach_vm_address_t address,
                            vm_offset_t data,
                            mach_msg_type_number_t dataCnt);

kern_return_t mach_vm_read_overwrite(vm_map_t target_task,
                                     mach_vm_address_t address,
                                     mach_vm_size_t size,
                                     mach_vm_address_t data,
                                     mach_vm_size_t *outsize);

kern_return_t mach_vm_region(vm_map_t target_task,
                             mach_vm_address_t *address,
                             mach_vm_size_t *size,
                             vm_region_flavor_t flavor,
                             vm_region_info_t info,
                             mach_msg_type_number_t *infoCnt,
                             mach_port_t *object_name);

#define LOG(str, args...) do { NSLog(@"[amfid_payload] " str, ##args); } while(0)
#define ERROR(str, args...) LOG("ERROR: [%s] " str, __func__, ##args)
#define INFO(str, args...)  LOG("INFO: " str, ##args)

mach_port_t tfp0;

size_t kread(uint64_t where, void *p, size_t size) {
	int rv;
	size_t offset = 0;
	while (offset < size) {
		mach_vm_size_t sz, chunk = 2048;
		if (chunk > size - offset) {
			chunk = size - offset;
		}
		rv = mach_vm_read_overwrite(mach_task_self(), where + offset, chunk, (mach_vm_address_t)p + offset, &sz);
		if (rv || sz == 0) {
			ERROR("error on kread(0x%016llx)", offset + where);
			break;
		}
		offset += sz;
	}
	return offset;
}

uint64_t kread64(uint64_t where) {
	uint64_t out;
	kread(where, &out, sizeof(uint64_t));
	return out;
}

void remote_read_overwrite(mach_port_t task_port,
                           uint64_t remote_address,
                           uint64_t local_address,
                           uint64_t length) {
    kern_return_t err;

    mach_vm_size_t outsize = 0;
    err = mach_vm_read_overwrite(task_port, (mach_vm_address_t)remote_address, (mach_vm_size_t)length, (mach_vm_address_t)local_address, &outsize);
    if (err != KERN_SUCCESS){
        ERROR("remote read failed");
        return;
    }

    if (outsize != length){
        ERROR(@"remote read was short (expected %llx, got %llx)", length, outsize);
        return;
    }
}

void remote_write(mach_port_t remote_task_port,
                  uint64_t remote_address,
                  uint64_t local_address,
                  uint64_t length) {
    kern_return_t err = mach_vm_write(remote_task_port,
                                      (mach_vm_address_t)remote_address,
                                      (vm_offset_t)local_address,
                                      (mach_msg_type_number_t)length);
    if (err != KERN_SUCCESS) {
        ERROR("remote write failed: %s %x", mach_error_string(err), err);
        return;
    }
}

uint64_t binary_load_address() {
    kern_return_t err;
    mach_msg_type_number_t region_count = VM_REGION_BASIC_INFO_COUNT_64;
    memory_object_name_t object_name = MACH_PORT_NULL;
    mach_vm_size_t target_first_size = 0x1000;
    mach_vm_address_t target_first_addr = 0x0;
    struct vm_region_basic_info_64 region = {0};
    err = mach_vm_region(mach_task_self(), &target_first_addr, &target_first_size, VM_REGION_BASIC_INFO_64, (vm_region_info_t)&region, &region_count, &object_name);

    if (err != KERN_SUCCESS) {
        ERROR("failed to get the region");
        return -1;
    }

    return target_first_addr;
}

static unsigned int hash_rank(const CodeDirectory *cd) {
    uint32_t type = cd->hashType;
    
    int arrLength = sizeof(hashPriorities) / sizeof(hashPriorities[0]);
    for (int i = 0; i < arrLength; i++) {
        if (hashPriorities[i] == type) {
            return i + 1;
        }
    }
    
    return 0;
}

int hash_code_directory(const CodeDirectory *directory, uint8_t hash[CS_CDHASH_LEN]) {
    uint32_t realsize = ntohl(directory->length);
    
    if (ntohl(directory->magic) != CSMAGIC_CODEDIRECTORY) {
        ERROR("expected CSMAGIC_CODEDIRECTORY");
        return 1;
    }
    
    uint8_t out[CS_HASH_MAX_SIZE];
    uint8_t hash_type = directory->hashType;
    
    switch (hash_type) {
        case CS_HASHTYPE_SHA1:
            CC_SHA1(directory, realsize, out);
            break;
        
        case CS_HASHTYPE_SHA256:
        case CS_HASHTYPE_SHA256_TRUNCATED:
            CC_SHA256(directory, realsize, out);
            break;
            
        case CS_HASHTYPE_SHA384:
            CC_SHA384(directory, realsize, out);
            break;
            
        default:
            INFO("Unknown hash type: 0x%x", hash_type);
            return 2;
    }
    
    memcpy(hash, out, CS_CDHASH_LEN);
    return 0;
}

#define BLOB_FITS(blob, size) ((size >= sizeof(*blob)) && (size >= ntohl(blob->length)))

int hash_code_signature(const void *csblob, uint32_t csblob_size, uint8_t dst[CS_CDHASH_LEN]) {
    const CS_GenericBlob *gen_blob = (const CS_GenericBlob *)csblob;
    
    if (!BLOB_FITS(gen_blob, csblob_size)) {
        ERROR("csblob too small even for generic blob");
        return 1;
    }
    
    const CodeDirectory *chosen_cd = NULL;
    
    if (ntohl(gen_blob->magic) == CSMAGIC_EMBEDDED_SIGNATURE) {
        uint8_t highest_cd_hash_rank = 0;
        
        const CS_SuperBlob *super_blob = (const CS_SuperBlob *)csblob;
        if (!BLOB_FITS(super_blob, csblob_size)) {
            ERROR("csblob too small for superblob");
            return 1;
        }
        
        uint32_t sblength = ntohl(super_blob->length);
        
        for (int i = 0; i != ntohl(super_blob->count); ++i){
            const CS_BlobIndex *blobIndex = &super_blob->index[i];
            
            uint32_t type = ntohl(blobIndex->type);
            uint32_t offset = ntohl(blobIndex->offset);
            
            if (offset > sblength) {
                ERROR("offset of blob #%d overflows superblob length", i);
                return 1;
            }
            
            if (type == CSSLOT_CODEDIRECTORY ||
                (type >= CSSLOT_ALTERNATE_CODEDIRECTORIES &&
                 type < CSSLOT_ALTERNATE_CODEDIRECTORY_LIMIT)) {
                const CodeDirectory *sub_cd = (const CodeDirectory *)((uintptr_t)csblob + offset);
                
                if (!BLOB_FITS(sub_cd, sblength - offset)) {
                    ERROR("subblob codedirectory doesnt fit in superblob");
                    return 1;
                }
                
                uint8_t rank = hash_rank(sub_cd);
                
                if (rank > highest_cd_hash_rank) {
                    chosen_cd = sub_cd;
                    highest_cd_hash_rank = rank;
                }
            }
        }
    } else if (ntohl(gen_blob->magic) == CSMAGIC_CODEDIRECTORY) {
        const CodeDirectory *code_dir = (const CodeDirectory *)csblob;
        if (!BLOB_FITS(code_dir, csblob_size)) {
            ERROR("csblob too small for codedirectory");
            return 1;
        }
        chosen_cd = code_dir;
    } else {
        ERROR("Unknown magic at csblob start: %08x", ntohl(gen_blob->magic));
        return 1;
    }
    
    if (chosen_cd == NULL) {
        ERROR("didn't find codedirectory to hash");
        return 1;
    }
    
    return hash_code_directory(chosen_cd, dst);
}

typedef struct {
    const char* name;
    uint64_t file_off;
    int fd;
    const void* addr;
    size_t size;
} img_info_t;

void close_img(img_info_t* info) {
    if (info == NULL) {
        return;
    }
    
    if (info->addr != NULL) {
        const void *map = (void*) ((uintptr_t) info->addr - info->file_off);
        size_t fsize = info->size + info->file_off;
        
        munmap((void*)map, fsize);
    }
    
    if (info->fd != -1) {
        close(info->fd);
    }
}

int open_img(img_info_t* info) {
#define _LOG_ERROR(str, args...) ERROR("(%s) " str, info->name, ##args)
    int ret = -1;
    
    if (info == NULL) {
        INFO("img info is NULL");
        return ret;
    }
    
    info->fd = -1;
    info->size = 0;
    info->addr = NULL;
    
    info->fd = open(info->name, O_RDONLY);
    if (info->fd == -1) {
        _LOG_ERROR("Couldn't open file");
        ret = 1;
        goto out;
    }
    
    struct stat s;
    if (fstat(info->fd, &s) != 0) {
        _LOG_ERROR("fstat: 0x%x (%s)", errno, strerror(errno));
        ret = 2;
        goto out;
    }
    
    size_t fsize = s.st_size;
    info->size = fsize - info->file_off;
    const void *map = mmap(NULL, fsize, PROT_READ, MAP_PRIVATE, info->fd, 0);
    
    if (map == MAP_FAILED) {
        _LOG_ERROR("mmap: 0x%x (%s)", errno, strerror(errno));
        ret = 4;
        goto out;
    }
    
    info->addr = (const void*) ((uintptr_t) map + info->file_off);
    ret = 0;
    
    out:;
        if (ret) {
            close_img(info);
        }
        return ret;
    
#undef _LOG_ERROR
}

const uint8_t *find_code_signature(img_info_t* info, uint32_t* cs_size) {
#define _LOG_ERROR(str, args...) ERROR("(%s) " str, info->name, ##args)
    if (info == NULL || info->addr == NULL) {
        return NULL;
    }
    
    // mach_header_64 is mach_header + reserved for padding
    const struct mach_header *mh = (const struct mach_header*)info->addr;
    
    uint32_t sizeofmh = 0;
    
    switch (mh->magic) {
        case MH_MAGIC_64:
            sizeofmh = sizeof(struct mach_header_64);
            break;
        case MH_MAGIC:
            sizeofmh = sizeof(struct mach_header);
            break;
        default:
            _LOG_ERROR("your magic is not valid in these lands: %08x", mh->magic);
            return NULL;
    }
    
    if (mh->sizeofcmds < mh->ncmds * sizeof(struct load_command)) {
        _LOG_ERROR("Corrupted macho (sizeofcmds < ncmds * sizeof(lc))");
        return NULL;
    }
    if (mh->sizeofcmds + sizeofmh > info->size) {
        _LOG_ERROR("Corrupted macho (sizeofcmds + sizeof(mh) > size)");
        return NULL;
    }
    
    const struct load_command *cmd = (const struct load_command *)((uintptr_t) info->addr + sizeofmh);
    for (int i = 0; i != mh->ncmds; ++i) {
        if (cmd->cmd == LC_CODE_SIGNATURE) {
            const struct linkedit_data_command* cscmd = (const struct linkedit_data_command*)cmd;
            if (cscmd->dataoff + cscmd->datasize > info->size) {
                _LOG_ERROR("Corrupted LC_CODE_SIGNATURE: dataoff + datasize > fsize");
                return NULL;
            }
            
            if (cs_size) {
                *cs_size = cscmd->datasize;
            }
            
            return (const uint8_t*)((uintptr_t)info->addr + cscmd->dataoff);
        }
        
        cmd = (const struct load_command *)((uintptr_t)cmd + cmd->cmdsize);
        if ((uintptr_t)cmd + sizeof(struct load_command) > (uintptr_t)info->addr + info->size) {
            _LOG_ERROR("Corrupted macho: Unexpected end of file while parsing load commands");
            return NULL;
        }
    }
    
    _LOG_ERROR("Didnt find the code signature");
    return NULL;
#undef _LOG_ERROR
}

int (*old_MISValidateSignatureAndCopyInfo)(NSString* file, NSDictionary* options, NSMutableDictionary** info);
int (*old_MISValidateSignatureAndCopyInfo_broken)(NSString* file, NSDictionary* options, NSMutableDictionary** info);

int fake_MISValidateSignatureAndCopyInfo(NSString* file, NSDictionary* options, NSMutableDictionary** info) {
    const char* file_path = [file UTF8String];
    INFO(@"called for file %s", file_path);
    
    // Call the original func
    old_MISValidateSignatureAndCopyInfo(file, options, info);
    
    if (info == NULL) {
        INFO("info is null - skipping");
        return 0;
    }
    
    if (*info == NULL) {
        *info = [[NSMutableDictionary alloc] init];
        if (*info == nil) {
            ERROR("out of memory - can't alloc info");
            return 0;
        }
    }
    
    if ([*info objectForKey:@"CdHash"]) {
        return 0;
    }
    
    NSNumber* file_offset = [options objectForKey:@"UniversalFileOffset"];
    uint64_t file_off = [file_offset unsignedLongLongValue];
    
    img_info_t img;
    img.name = file.UTF8String;
    img.file_off = file_off;
    
    if (open_img(&img)) {
        ERROR(@"failed to open file: %@", file);
        return 0;
    }
    
    uint32_t cs_length;
    const uint8_t *cs = find_code_signature(&img, &cs_length);
    if (cs == NULL) {
        ERROR(@"can't find code signature: %@", file);
        close_img(&img);
        return 0;
    }
    
    uint8_t cd_hash[CS_CDHASH_LEN];
    
    if (hash_code_signature(cs, cs_length, cd_hash)) {
        ERROR(@"failed to get cdhash from signature: %@", file);
        close_img(&img);
        return 0;
    }
    
    NSData *ns_cdhash = [[NSData alloc] initWithBytes:cd_hash length:sizeof(cd_hash)];
    [*info setValue: ns_cdhash forKey:@"CdHash"];
    
    INFO(@"magic was performed [%08x]: %@", ntohl(*(uint64_t *)cd_hash), file);
    
    return 0;
}

void *hook_funcs(void *arg) {
    // This is some wicked crazy shit that needs to happen to correctly patch
    // after amfid has been killed & launched & patched again... it's nuts.
    // shouldn't even work. creds whoever came up w this @ ElectraTeam
    void *libmis = dlopen("/usr/lib/libmis.dylib", RTLD_NOW);
    old_MISValidateSignatureAndCopyInfo = dlsym(libmis, "MISValidateSignatureAndCopyInfo");
    
    struct rebinding rebindings[] = {
        { "MISValidateSignatureAndCopyInfo", (void *)fake_MISValidateSignatureAndCopyInfo, (void **)&old_MISValidateSignatureAndCopyInfo_broken },
        /*                                                                                                                               ^^^^^^ you can say that again */
    };
    
    rebind_symbols(rebindings, 1);
    
    // touch file so Meridian know's we're alive in here
    fclose(fopen("/var/tmp/amfid_payload.alive", "w+"));
    
    return NULL;
}

__attribute__ ((constructor))
static void ctor(void) {
    INFO("preparing to fuck up amfid :)");
    pthread_t thread;
    pthread_create(&thread, NULL, hook_funcs, NULL);
}
