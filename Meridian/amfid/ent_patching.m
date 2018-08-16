#include <stdlib.h>
#include <stddef.h>
#include <Foundation/Foundation.h>
#include "cs_dingling.h"
#include "kexecute.h"
#include "kmem.h"
#include "osobject.h"
#include "patchfinder64.h"
#include "ubc_headers.h"
#include "kern_utils.h"

// You don't wanna know why this exists :-)
int added_offset = -1;

// Default entitlements to be granted
const char *default_ents =  "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
                            "<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">"
                            "<plist version=\"1.0\">"
                                "<dict>"
                                    "<key>platform-application</key>"                         // escape container restriction
                                    "<true/>"
                                    "<key>com.apple.private.security.no-container</key>"      // no container
                                    "<true/>"
                                    "<key>get-task-allow</key>"                               // task_for_pid
                                    "<true/>"
                                    "<key>com.apple.private.skip-library-validation</key>"    // allow invalid libs
                                    "<true/>"
                                "</dict>"
                            "</plist>";

uint64_t get_vfs_context() {
    // vfs_context_t vfs_context_current(void)
    uint64_t vfs_context = kexecute(offset_vfs_context_current, 1, 0, 0, 0, 0, 0, 0);
    vfs_context = zm_fix_addr(vfs_context);
    return vfs_context;
}

int get_vnode_fromfd(uint64_t vfs_context, int fd, uint64_t *vpp) {
    uint64_t vnode = kalloc(sizeof(vnode_t *));
    
    // int vnode_getfromfd(vfs_context_t cfx, int fd, vnode_t vpp)
    int ret = kexecute(offset_vnode_getfromfd, vfs_context, fd, vnode, 0, 0, 0, 0);
    if (ret != 0) {
        return -1;
    }
    
    *vpp = vnode;
    return 0;
}

int vnode_put(uint64_t vnode) {
    return kexecute(offset_vnode_put, vnode, 0, 0, 0, 0, 0, 0);
}

int calculate_added_offset(uint64_t vnode) {
    int32_t possibly_iocount = rk32(vnode + offsetof(struct vnode, v_iocount));
    NSLog(@"possibly_iocount value: %d", possibly_iocount);
    
    // Since we've just called vnode_getfromfd, the iocount of this vnode cannot
    // be 0. It also cannot be a negative number, as this would be an invalid
    // iocount. However, if this is the case, we are actually looking at the
    // v_owner field due to mismatched offsets, dictating that this device is
    // running an older version of xnu with an 8 byte smaller vnode struct.
    return (possibly_iocount <= 0) ? -8 : 0;
}

int check_vtype(uint64_t vnode) {
    /*
         struct vnode { // `vnode`
            ...
            uint16_t `v_type`;
     */
    uint16_t v_type = rk16(vnode + offsetof(struct vnode, v_type) + added_offset);
    
    if (v_type != VREG) {
        NSLog(@"got weird vtype for vnode (0x%llx): %d", vnode, v_type);
        return 1;
    }
    
    return 0;
}

uint64_t get_vu_ubcinfo(uint64_t vnode) {
    /*
         struct vnode { // `vnode`
            ...
            union {
                struct ubc_info *vu_ubcinfo;
            } v_un;
     */
    return rk64(vnode + offsetof(struct vnode, v_un) + added_offset);
}

uint64_t get_csblobs(uint64_t vu_ubcinfo) {
    /*
         struct ubc_info { // `vu_ubcinfo`
            ....
            struct cs_blob *cs_blobs;
     */
    return rk64(vu_ubcinfo + offsetof(struct ubc_info, cs_blobs));
}

void csblob_ent_dict_set(uint64_t cs_blobs, uint64_t dict) {
    // void csblob_entitlements_dictionary_set(struct cs_blob *csblob, void *entitlements)
    kexecute(offset_csblob_ent_dict_set, cs_blobs, dict, 0, 0, 0, 0, 0);
}

void csblob_update_csflags(uint64_t cs_blobs, uint32_t flags_to_add) {
    /*
         struct cs_blob {
            ...
            unsigned int    csb_flags;
     */
    
    uint32_t csflags = rk32(cs_blobs + offsetof(struct cs_blob, csb_flags));
    
    csflags |= flags_to_add;
    
    wk32(cs_blobs + offsetof(struct cs_blob, csb_flags), csflags);
}

int set_memory_object_code_signed(uint64_t vu_ubcinfo) {
    uint64_t ui_control = rk64(vu_ubcinfo + offsetof(struct ubc_info, ui_control));
    if (ui_control == 0) {
        NSLog(@"failed to get ui_control");
        return 1;
    }
    
    uint64_t moc_object = rk64(ui_control + 0x8); // offsetof(struct memory_object_control, moc_object)
    if (moc_object == 0) {
        NSLog(@"failed to get moc_object");
        return 1;
    }
    
    uint64_t code_signed_addr = moc_object + 0xb8;
    
    uint32_t curr_code_signed = rk32(code_signed_addr);
    
    // `code_signed` is only 1 bit
    curr_code_signed |= 0x100;
    wk32(code_signed_addr, curr_code_signed);
    
    return 0;
}

uint64_t cs_hash_ptr = 0;
uint64_t find_csb_hashtype(uint32_t hashType) {
    // We're keeping hold of this just incase the patchfind for `cs_find_md` fails
    if (cs_hash_ptr == 0) {
        const struct cs_hash hash = {
            .cs_type = CS_HASHTYPE_SHA1,
            .cs_size = CS_SHA1_LEN,
            .cs_init = offset_sha1_init,
            .cs_update = offset_sha1_update,
            .cs_final = offset_sha1_final
        };
        cs_hash_ptr = kalloc(sizeof(hash));
        if (cs_hash_ptr != 0) {
            kwrite(cs_hash_ptr, &hash, sizeof(hash));
        } else {
            NSLog(@"failed to kalloc %lu bytes! (find_csb_hashtype)", sizeof(hash));
        }
    }
    
    uint64_t cs_find_md = find_cs_find_md();
    if (cs_find_md == 0) {
        // Dammit :( If the hash isn't SHA1 it now won't run,
        // but if we return 0 it will just KP. I'd rather a Killed: 9
        NSLog(@"FATAL ERROR! Unable to find 'cs_find_md'!!");
        return cs_hash_ptr;
    }
    
    return rk64(cs_find_md + ((hashType - 1) * 0x8));
}

uint64_t construct_cs_blob(const void *cs,
                       uint32_t cs_length,
                       uint8_t cd_hash[20],
                       uint32_t chosen_off,
                       uint64_t macho_offset) {
    uint64_t entire_csdir = kalloc(cs_length);
    if (entire_csdir == 0) {
        NSLog(@"error!! failed to kalloc %d bytes!! (construct_cs_blob)", cs_length);
        return 0;
    }
    kwrite(entire_csdir, cs, cs_length);
    
    const CS_CodeDirectory *blob = (const CS_CodeDirectory *)((uintptr_t)cs + chosen_off);
    
    struct cs_blob *cs_blob = malloc(sizeof(struct cs_blob));
    bzero(cs_blob, sizeof(struct cs_blob));
    
    cs_blob->csb_next = 0;
    cs_blob->csb_cpu_type = -1;
    
    cs_blob->csb_flags = (ntohl(blob->flags) & CS_ALLOWED_MACHO) | CS_VALID | CS_SIGNED;
    
    cs_blob->csb_base_offset = macho_offset;
    cs_blob->csb_start_offset = 0;
    
    if (ntohl(blob->version) >= CS_SUPPORTSSCATTER && ntohl(blob->scatterOffset) != 0) {
        const SC_Scatter *scatter = (const SC_Scatter *)((const char *)blob + ntohl(blob->scatterOffset));
        cs_blob->csb_start_offset = ((off_t)ntohl(scatter->base)) * (1U << blob->pageSize);
    }
    
    cs_blob->csb_mem_size = cs_length;
    cs_blob->csb_mem_offset = 0;
    cs_blob->csb_mem_kaddr = entire_csdir;
    
    memcpy(cs_blob->csb_cdhash, cd_hash, CS_CDHASH_LEN);
    
    uint64_t csb_hashtype = find_csb_hashtype(blob->hashType);
    if (csb_hashtype == 0) {
        NSLog(@"failed to get csb_hashtype!! (construct_cs_blob)");
        return 0;
    }
    cs_blob->csb_hashtype = (const struct cs_hash *)csb_hashtype;
    
    cs_blob->csb_hash_pagesize = (1U << blob->pageSize);
    cs_blob->csb_hash_pagemask = (1U << blob->pageSize) - 1;
    cs_blob->csb_hash_pageshift = blob->pageSize;
    
    cs_blob->csb_end_offset = ntohl(blob->codeLimit) + cs_blob->csb_hash_pagemask & ~cs_blob->csb_hash_pagemask;
    
    cs_blob->csb_hash_firstlevel_pagesize = 0;
    cs_blob->csb_cd = (const CS_CodeDirectory *)(entire_csdir + chosen_off);
    
    if (cs_blob->csb_flags & CS_PLATFORM_BINARY) {
        cs_blob->csb_platform_binary = 1;
        cs_blob->csb_platform_path = !!(cs_blob->csb_flags & CS_PLATFORM_PATH);
    } else if ((ntohl(blob->version) >= CS_SUPPORTSTEAMID) &&
               (blob->teamOffset > 0)) {
        const char *name = ((const char *)blob) + ntohl(blob->teamOffset);
        int length = strlen(name) + 1;
        
        uint64_t teamid_addr = kalloc(length);
        
        if (teamid_addr == 0) {
            NSLog(@"failed to kalloc %d bytes!! (construct_cs_blob)", length);
            return 0;
        }
        
        kwrite(teamid_addr, name, length);
        cs_blob->csb_teamid = (const char *)teamid_addr;
    }
    
    uint64_t kernel_blob = kalloc(sizeof(struct cs_blob));
    kwrite(kernel_blob, cs_blob, sizeof(struct cs_blob));
    
    free(cs_blob);
    
    return kernel_blob;
}

uint64_t fresh_entitlements_blob = 0;
uint64_t get_fresh_entitlements_blob() {
    if (fresh_entitlements_blob == 0) {
        int size = 8 + strlen(default_ents);
        CS_GenericBlob *entitlements_blob = (CS_GenericBlob *)malloc(size);
        bzero(entitlements_blob, size);
        
        entitlements_blob->magic = CSMAGIC_EMBEDDED_ENTITLEMENTS;
        entitlements_blob->length = size;
        strncpy(entitlements_blob->data, default_ents, strlen(default_ents) + 1);
        
        // Copy the data into kernel, and write to the csb_entitlements_blob field
        uint64_t fresh_entitlements_blob = kalloc(size);
        if (fresh_entitlements_blob == 0) {
            NSLog(@"failed to allocate %d bytes!! in ent_patching", size);
            return -1;
        }
        
        kwrite(fresh_entitlements_blob, entitlements_blob, size);
        free(entitlements_blob);
    }
    
    return fresh_entitlements_blob;
}

int fixup_platform_application(const char *path,
                               uint64_t macho_offset,
                               const void *blob,
                               uint32_t cs_length,
                               uint8_t cd_hash[20],
                               uint32_t csdir_offset,
                               const CS_GenericBlob *entitlements) {
    int ret;
    
    uint64_t vfs_context = get_vfs_context();
    if (vfs_context == 0) {
        ret = -1;
        goto out;
    }
    
    int fd = open(path, O_RDONLY);
    if (fd < 0) {
        ret = -2;
        goto out;
    }
    
    uint64_t vpp;
    ret = get_vnode_fromfd(vfs_context, fd, &vpp);
    if (ret != 0) {
        ret = -3;
        goto out;
    }
    
    close(fd);
    
    uint64_t vnode = rk64(vpp);
    if (vnode == 0) {
        ret = -4;
        goto out;
    }
    
    if (added_offset == -1) {
        added_offset = calculate_added_offset(vnode);
        NSLog(@"added_offset was set to: %d", added_offset);
    }
    
    ret = check_vtype(vnode);
    if (ret != 0) {
        ret = -5;
        goto out;
    }
    
    uint64_t vu_ubcinfo = get_vu_ubcinfo(vnode);
    if (vu_ubcinfo == 0) {
        ret = -6;
        goto out;
    }
    
    bool is_new_cs_blob = false;
    uint64_t cs_blobs = get_csblobs(vu_ubcinfo);
    if (cs_blobs == 0) {
        is_new_cs_blob = true;
        cs_blobs = construct_cs_blob(blob,
                                                 cs_length,
                                                 cd_hash,
                                                 csdir_offset,
                                                 macho_offset);
        if (cs_blobs == 0) {
            NSLog(@"failed to construct csblob");
            ret = -7;
            goto out;
        }
        
        wk64(vu_ubcinfo + offsetof(struct ubc_info, cs_blobs), cs_blobs);
    }
    
    if (entitlements == NULL) {
        // generate some new entitlements
        // this is all we're here to do, really :-)
        uint64_t dict = OSUnserializeXML(default_ents);
        if (dict == 0) {
            NSLog(@"failed to call OSUnserializeXML in ent_patching!!");
            ret = -9;
            goto out;
        }
        
        csblob_ent_dict_set(cs_blobs, dict);
        csblob_update_csflags(dict, CS_GET_TASK_ALLOW);
        
        // Update csb_entitlements_blob with a blob based on `default_ents`
        wk64(cs_blobs + offsetof(struct cs_blob, csb_entitlements_blob), get_fresh_entitlements_blob());
    } else {
        // there are some entitlements, let's parse them, update the osdict w/
        // platform-application (true), and write them into kern
        uint64_t dict = OSUnserializeXML(entitlements->data);

        // gotta check for get-task-allow as it sets another csflag
        // remember: csflags have to be *perfect* otherwise the trick won't work
        // the reason this is *before* we add it manually is because the kernel won't
        // know about the manually added entitlement, and therefore this flag won't be set
        // (assuming it wasn't already in the existing entitlements)
        ret = OSDictionary_GetItem(dict, "get-task-allow");
        if (ret) csblob_update_csflags(cs_blobs, CS_GET_TASK_ALLOW);
        
        OSDictionary_SetItem(dict, "platform-application",                      find_OSBoolean_True());
        OSDictionary_SetItem(dict, "com.apple.private.security.no-container",   find_OSBoolean_True());
        OSDictionary_SetItem(dict, "get-task-allow",                            find_OSBoolean_True());
        OSDictionary_SetItem(dict, "com.apple.private.skip-library-validation", find_OSBoolean_True());
        
        csblob_ent_dict_set(cs_blobs, dict);
        
        // map the genblob up to csb_entitlements_blob
        // idk if we necessarily need to do this but w/e
        // TODO: fix this so it uses the *new* entitlements, not the original ones (duh)
        // Note to self: this field seems to be checked in the case of things like uicache, which requires
        // the 'com.apple.lsapplicationworkspace.rebuildappdatabases' entitlement. I suspect this field is
        // designed to be 'userland-viewable'
        int size = ntohl(entitlements->length);
        uint64_t entptr = kalloc(size);
        if (entptr == 0) {
            NSLog(@"failed to allocate %d bytes!! in ent_patching", size);
            ret = -11;
            goto out;
        }
        
        kwrite(entptr, entitlements, size);
        wk64(cs_blobs + offsetof(struct cs_blob, csb_entitlements_blob), entptr);
    }
    
    if (is_new_cs_blob) {
        // memory_object_signed
        // uip->ui_control->moc_object->code_signed = 1
        ret = set_memory_object_code_signed(vu_ubcinfo);
        if (ret != 0) {
            ret = -8;
            goto out;
        }
        
        // TODO: Update global cs_* vars
        
        // disabled for now... causes panics on 2nd run of the binary
        // something to do with a mutex lock.. i don't care to figure out what
        // set generation count
//        wk64(vu_ubcinfo + offsetof(struct ubc_info, cs_add_gen), 1);
//        NSLog(@"cs_add_gen: %llx", rk64(vu_ubcinfo + offsetof(struct ubc_info, cs_add_gen)));
        
        // Update the cs_mtime field in ubc_info struct
        uint64_t vnode_attr = kalloc(sizeof(struct vnode_attr));
        wk64(vnode_attr + offsetof(struct vnode_attr, va_active), 1LL << 14);
        
        // int vnode_getattr(vnode_t vp, struct vnode_attr *vap, vfs_context_t ctx)
        ret = kexecute(offset_vnode_getattr, vnode, vnode_attr, vfs_context, 0, 0, 0, 0);
        if (ret != 0) {
            NSLog(@"vnode_attr failed - ret value: %d", ret);
        } else {
            uint64_t mtime = rk64(vnode_attr + offsetof(struct vnode_attr, va_modify_time));
            if (mtime != 0) {
                wk64(vu_ubcinfo + offsetof(struct ubc_info, cs_mtime), mtime);
            }
        }
    }
    
    ret = vnode_put(vnode);
    if (ret != 0) {
        NSLog(@"failed vnode_put(%llx)! ret: %d", vnode, ret);
        ret = 12;
        goto out;
    }
    
    ret = 0;
    
out:
    return ret;
}
