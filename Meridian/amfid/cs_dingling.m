#include "cs_dingling.h"
#include <sys/mman.h>
#include <spawn.h>
#include <sys/stat.h>
#include <mach-o/loader.h>
#import <Foundation/Foundation.h>
#import <CommonCrypto/CommonDigest.h>

// Finds the LC_CODE_SIGNATURE load command
const uint8_t *find_code_signature(img_info_t *info, uint32_t *cs_size) {
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

#define BLOB_FITS(blob, size) ((size >= sizeof(*blob)) && (size >= ntohl(blob->length)))

int find_best_codedir(const void *csblob,
                      uint32_t csblob_size,
                      const CS_CodeDirectory **chosen_cd,
                      uint32_t *csb_offset,
                      const CS_GenericBlob **entitlements) {
    *chosen_cd = NULL;
    *entitlements = NULL;
    
    const CS_GenericBlob *gen_blob = (const CS_GenericBlob *)csblob;
    
    if (!BLOB_FITS(gen_blob, csblob_size)) {
        ERROR("csblob too small even for generic blob");
        return 1;
    }
    
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
                    const CS_CodeDirectory *sub_cd = (const CS_CodeDirectory *)((uintptr_t)csblob + offset);
                    
                    if (!BLOB_FITS(sub_cd, sblength - offset)) {
                        ERROR("subblob codedirectory doesnt fit in superblob");
                        return 1;
                    }
                    
                    uint8_t rank = hash_rank(sub_cd);
                    if (rank > highest_cd_hash_rank) {
                        *chosen_cd = sub_cd;
                        *csb_offset = offset;
                        highest_cd_hash_rank = rank;
                    }
                } else if (type == CSSLOT_ENTITLEMENTS) {
                    *entitlements = (const CS_GenericBlob *)((uintptr_t)csblob + offset);
                }
        }
    } else if (ntohl(gen_blob->magic) == CSMAGIC_CODEDIRECTORY) {
        const CS_CodeDirectory *code_dir = (const CS_CodeDirectory *)csblob;
        if (!BLOB_FITS(code_dir, csblob_size)) {
            ERROR("csblob too small for codedirectory");
            return 1;
        }
        *chosen_cd = code_dir;
    } else {
        ERROR("Unknown magic at csblob start: %08x", ntohl(gen_blob->magic));
        return 1;
    }
    
    if (chosen_cd == NULL) {
        ERROR("didn't find codedirectory to hash");
        return 1;
    }
    
    return 0;
}

static unsigned int hash_rank(const CS_CodeDirectory *cd) {
    uint32_t type = cd->hashType;
    
    int arrLength = sizeof(hashPriorities) / sizeof(hashPriorities[0]);
    for (int i = 0; i < arrLength; i++) {
        if (hashPriorities[i] == type) {
            return i + 1;
        }
    }
    
    return 0;
}

int hash_code_directory(const CS_CodeDirectory *directory, uint8_t hash[CS_CDHASH_LEN]) {
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
