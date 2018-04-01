#include <stdlib.h>
#include <stddef.h>
#include <Foundation/Foundation.h>
#include "cs_dingling.h"
#include "helpers/kexecute.h"
#include "helpers/kmem.h"
#include "helpers/osobject.h"
#include "helpers/patchfinder64.h"
#include "ubc_headers.h"
#include "kern_utils.h"

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

int check_vtype(uint64_t vnode) {
    /*
         struct vnode { // `vnode`
            ...
            uint16_t `v_type`;
     */
    uint16_t v_type = rk64(vnode + offsetof(struct vnode, v_type));
    return (v_type == VREG) ? 0 : 1;
}

uint64_t get_vu_ubcinfo(uint64_t vnode) {
    /*
         struct vnode { // `vnode`
            ...
            union {
                struct ubc_info *vu_ubcinfo;
            } v_un;
     */
    return rk64(vnode + offsetof(struct vnode, v_un));
}

uint64_t get_csblobs(uint64_t vu_ubcinfo) {
    /*
         struct ubc_info { // `vu_ubcinfo`
            ....
            struct cs_blob *cs_blobs;
     */
    return rk64(vu_ubcinfo + offsetof(struct ubc_info, cs_blobs));
}

uint64_t get_csb_entitlements(uint64_t cs_blobs) {
    return rk64(cs_blobs + offsetof(struct cs_blob, csb_entitlements));
}

void csblob_ent_dict_set(uint64_t cs_blobs, uint64_t dict) {
    // void csblob_entitlements_dictionary_set(struct cs_blob *csblob, void *entitlements)
    kexecute(offset_csblob_ent_dict_set, cs_blobs, dict, 0, 0, 0, 0, 0);
}

int csblob_get_ents(uint64_t cs_blob, CS_GenericBlob *ent_blob) {
    ent_blob = NULL;
    
    uint64_t out_start_ptr = kalloc(sizeof(void **));
    uint64_t out_length_ptr = kalloc(sizeof(size_t));
    int ret = kexecute(offset_csblob_get_ents, cs_blob, out_start_ptr, out_length_ptr, 0, 0, 0, 0);
    if (ret != 0) {
        return -1;
    }
    
    int out_length = rk64(out_length_ptr);
    if (out_length == 0) {
        return 0;
    }
    
    uint64_t out_start = rk64(out_start_ptr);
    
    // read CS_GenericBlob (there may be a better way to do this,
    // but `kread` can get hung up on null bytes - eg in `length`
    
    NSLog(@"out_start of blob: %llx", out_start);
    uint32_t magic = rk32(out_start);
    uint32_t length = rk32(out_start + 4);
    char *dict_str = malloc(length);
    kread(out_start + 8, dict_str, length);
    
    *ent_blob = (CS_GenericBlob) {
        magic,
        length
    };
    
    strncpy(ent_blob->data, dict_str, length);
    
    return out_length;
}

uint64_t construct_cs_blob(const void *cs,
                           uint32_t cs_length,
                           uint8_t cd_hash[20],
                           uint32_t chosen_off,
                           uint64_t macho_offset) {
    NSLog(@"cslength = %d", cs_length);
    uint64_t entire_csdir = kalloc(cs_length);
    kwrite(entire_csdir, cs, cs_length);
    
    const CS_CodeDirectory *blob = (const CS_CodeDirectory *)((uintptr_t)cs + chosen_off);
    
    uint64_t cs_blob = kalloc(sizeof(struct cs_blob));
    wk64(cs_blob + offsetof(struct cs_blob, csb_next), 0);
    wk32(cs_blob + offsetof(struct cs_blob, csb_cpu_type), -1); // kern will update this for us :-)
    wk32(cs_blob + offsetof(struct cs_blob, csb_flags), (ntohl(blob->flags) & CS_ALLOWED_MACHO) | CS_VALID | CS_SIGNED); // 536870913

    wk64(cs_blob + offsetof(struct cs_blob, csb_base_offset), macho_offset);
    wk64(cs_blob + offsetof(struct cs_blob, csb_start_offset), 0);
    if (ntohl(blob->version) >= CS_SUPPORTSSCATTER && (ntohl(blob->scatterOffset))) {
        const SC_Scatter *scatter = (const SC_Scatter *)((const char *)blob + ntohl(blob->scatterOffset));
        wk64(cs_blob + offsetof(struct cs_blob, csb_start_offset), ((off_t)ntohl(scatter->base)) * (1U << blob->pageSize));
    }
    wk64(cs_blob + offsetof(struct cs_blob, csb_end_offset), ((vm_offset_t)ntohl(blob->codeLimit) +
                                                              ((1U << blob->pageSize) - 1) &
                                                                ~((vm_offset_t)((1U << blob->pageSize) - 1))));
    
    wk64(cs_blob + offsetof(struct cs_blob, csb_mem_size), cs_length); // hopefully 0x1c0 or so
    wk64(cs_blob + offsetof(struct cs_blob, csb_mem_offset), 0);
    wk64(cs_blob + offsetof(struct cs_blob, csb_mem_kaddr), entire_csdir);
    
    kwrite(cs_blob + offsetof(struct cs_blob, csb_cdhash), cd_hash, CS_CDHASH_LEN);
    wk64(cs_blob + offsetof(struct cs_blob, csb_hashtype), 0xfffffff0070ad9d0 + kernel_slide); // cs_hash_sha1
    
    wk64(cs_blob + offsetof(struct cs_blob, csb_hash_pagesize), (1U << blob->pageSize)); // 0x1000
    wk64(cs_blob + offsetof(struct cs_blob, csb_hash_pagemask), (1U << blob->pageSize) - 1); // 0xfff
    wk64(cs_blob + offsetof(struct cs_blob, csb_hash_pageshift), blob->pageSize); // 0xc
    wk64(cs_blob + offsetof(struct cs_blob, csb_hash_firstlevel_pagesize), 0);
    wk64(cs_blob + offsetof(struct cs_blob, csb_cd), entire_csdir + chosen_off);
    
    wk64(cs_blob + offsetof(struct cs_blob, csb_teamid), 0);
    wk64(cs_blob + offsetof(struct cs_blob, csb_entitlements_blob), 0);
    wk64(cs_blob + offsetof(struct cs_blob, csb_entitlements), 0);
    wk32(cs_blob + offsetof(struct cs_blob, csb_platform_binary), 0);
    wk32(cs_blob + offsetof(struct cs_blob, csb_platform_path), 0);
    
    NSLog(@"cs_blob struct size: %ld", sizeof(struct cs_blob));
    
    return cs_blob;
}

void dump_csblob(uint64_t cs_blobs) {
    NSLog(@"csb_next: %llx \n", rk64(cs_blobs + offsetof(struct cs_blob, csb_next)));
    NSLog(@"csb_cpu_type: %d \n", rk32(cs_blobs + offsetof(struct cs_blob, csb_cpu_type)));
    NSLog(@"csb_flags: %d \n", (int)rk64(cs_blobs + offsetof(struct cs_blob, csb_flags)));
    NSLog(@"csb_base_offset: %llx \n", rk64(cs_blobs + offsetof(struct cs_blob, csb_base_offset)));
    NSLog(@"csb_start_offset: %llx \n", rk64(cs_blobs + offsetof(struct cs_blob, csb_start_offset)));
    NSLog(@"csb_mem_size: %llx \n", rk64(cs_blobs + offsetof(struct cs_blob, csb_mem_size)));
    NSLog(@"csb_mem_offset: %llx \n", rk64(cs_blobs + offsetof(struct cs_blob, csb_mem_offset)));
    NSLog(@"csb_mem_kaddr: %llx \n", rk64(cs_blobs + offsetof(struct cs_blob, csb_mem_kaddr)));
    NSLog(@"csb_cdhash: %llx \n", rk64(cs_blobs + offsetof(struct cs_blob, csb_cdhash)));
    NSLog(@"csb_hashtype: %llx \n", rk64(cs_blobs + offsetof(struct cs_blob, csb_hashtype)));
    NSLog(@"csb_hash_pagesize: %llx \n", rk64(cs_blobs + offsetof(struct cs_blob, csb_hash_pagesize)));
    NSLog(@"csb_hash_pagemask: %llx \n", rk64(cs_blobs + offsetof(struct cs_blob, csb_hash_pagemask)));
    NSLog(@"csb_hash_pageshift: %llx \n", rk64(cs_blobs + offsetof(struct cs_blob, csb_hash_pageshift)));
    NSLog(@"csb_hash_firstlevel_pagesize: %llx \n", rk64(cs_blobs + offsetof(struct cs_blob, csb_hash_firstlevel_pagesize)));
    NSLog(@"csb_cd: %llx \n", rk64(cs_blobs + offsetof(struct cs_blob, csb_cd)));
    NSLog(@"csb_teamid: %llx \n", rk64(cs_blobs + offsetof(struct cs_blob, csb_teamid)));
    NSLog(@"csb_entitlements_blob: %llx \n", rk64(cs_blobs + offsetof(struct cs_blob, csb_entitlements_blob)));
    NSLog(@"csb_entitlements: %llx \n", rk64(cs_blobs + offsetof(struct cs_blob, csb_entitlements)));
    NSLog(@"csb_platform_binary: %d \n", rk32(cs_blobs + offsetof(struct cs_blob, csb_platform_binary)));
    NSLog(@"csb_platform_path: %d \n", rk32(cs_blobs + offsetof(struct cs_blob, csb_platform_path)));
}

int fixup_platform_application(const char *path,
                               uint64_t macho_offset,
                               const void *blob,
                               uint32_t cs_length,
                               uint8_t cd_hash[20],
                               uint32_t csdir_offset,
                               const CS_GenericBlob *entitlements) {
    NSLog(@"fixup_platform_appl called for %s", path);
    
    int ret;
    
    uint64_t vfs_context = get_vfs_context();
    if (vfs_context == 0) {
        ret = -1;
        goto out;
    }
    NSLog(@"got vfs_context: %llx", vfs_context);
    
    int fd = open(path, O_RDONLY);
    if (fd < 0) {
        ret = -2;
        goto out;
    }
    NSLog(@"got fd: %d", fd);
    
    uint64_t *vpp = malloc(sizeof(vnode_t *));
    ret = get_vnode_fromfd(vfs_context, fd, vpp);
    if (ret != 0) {
        ret = -3;
        goto out;
    }
    NSLog(@"got vpp: %llx", *vpp);
    
    uint64_t vnode = rk64(*vpp);
    if (vnode == 0) {
        ret = -4;
        goto out;
    }
    NSLog(@"got vnode: %llx", vnode);
    
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
    NSLog(@"got vu_ubcinfo: %llx", vu_ubcinfo);
    
    uint64_t cs_blobs = get_csblobs(vu_ubcinfo);
    if (cs_blobs == 0) {
        NSLog(@"generating new csblobs");
        uint64_t new_cs_blob = construct_cs_blob(blob,
                                                 cs_length,
                                                 cd_hash,
                                                 csdir_offset,
                                                 macho_offset);
        if (new_cs_blob < 1) {
            NSLog(@"failed to construct csblob");
            ret = -7;
            goto out;
        }
        NSLog(@"new_cs_blob = %llx", new_cs_blob);
        
        wk64(vu_ubcinfo + offsetof(struct ubc_info, cs_blobs), new_cs_blob);
        cs_blobs = rk64(vu_ubcinfo + offsetof(struct ubc_info, cs_blobs));
        NSLog(@"cs_blobs = %llx", cs_blobs);
        
        // we now need to update a few other bits and bobs
        
        // memory_object_signed
        // uip->ui_control->moc_object->code_signed = 1
        uint64_t ui_control = rk64(vu_ubcinfo + offsetof(struct ubc_info, ui_control));
        NSLog(@"uicontrol = %llx", ui_control);
        if (ui_control == 0) {
            NSLog(@"failed to get ui_control");
        } else {
            uint64_t moc_object = rk64(ui_control + 0x8); // offsetof(struct memory_object_control, moc_object)
            NSLog(@"moc_object = %llx", moc_object);
            if (moc_object == 0) {
                NSLog(@"failed to get moc_object");
            } else {
                uint64_t code_signed_addr = moc_object + 0xb8;

                uint32_t curr_code_signed = rk32(code_signed_addr);
                NSLog(@"curr_code_signed = %x", curr_code_signed);

                // `code_signed` is only 1 bit
                curr_code_signed |= 0x100;
                wk32(code_signed_addr, curr_code_signed);
                NSLog(@"new code signed = %x", rk32(code_signed_addr));
            }
        }

        // set generation count
        wk64(vu_ubcinfo + offsetof(struct ubc_info, cs_add_gen), 1);
        NSLog(@"cs_add_gen: %llx", rk64(vu_ubcinfo + offsetof(struct ubc_info, cs_add_gen)));

        // record_mtime
        uint64_t vnode_attr = kalloc(sizeof(struct vnode_attr));
        wk64(vnode_attr + offsetof(struct vnode_attr, va_supported), 0);
        wk64(vnode_attr + offsetof(struct vnode_attr, va_active), 1LL << 14);
        wk64(vnode_attr + offsetof(struct vnode_attr, va_vaflags), 0);
        // vnode_getattr
        ret = kexecute(0xfffffff00721849c + kernel_slide, vnode, vnode_attr, vfs_context, NULL, NULL, NULL, NULL);
        if (ret != 0) {
            NSLog(@"vnode_attr failed - ret value: %d", ret);
        } else {
            uint64_t mtime = rk64(vnode_attr + offsetof(struct vnode_attr, va_modify_time));
            if (mtime == 0) {
                NSLog(@"mtime is 0!");
            } else {
                NSLog(@"got mtime: %llx", mtime);
                wk64(vu_ubcinfo + offsetof(struct ubc_info, cs_mtime), mtime);
            }
        }
    }
    
    if (entitlements == NULL) {
        // generate a new CS_GenericBlob
        // TODO: move to new func
        // this is all we're here to do, really :-)
        NSLog(@"entitlements is null, created new ones");
        const char *cstring = "<dict><key>platform-application</key><true/></dict>";
        uint64_t dict = OSUnserializeXML(cstring);
        csblob_ent_dict_set(cs_blobs, dict);
    } else {
        // there are some entitlements, let's parse them, update the osdict w/
        // platform-application (true), and write them into kern
        NSLog(@"entitlements magic: %llx", ntohl(entitlements->magic));
        NSLog(@"entitlements length: %d", ntohl(entitlements->length));
        NSLog(@"entitlements data: %s", entitlements->data);
        uint64_t dict = OSUnserializeXML(entitlements->data);
        
        ret = OSDictionary_SetItem(dict, "platform-application", find_OSBoolean_True());
        NSLog(@"osdict_setitem ret: %d", ret);
        if (ret != 1) {
            ret = -10;
            goto out;
        }

        csblob_ent_dict_set(cs_blobs, dict);
        NSLog(@"csblob_ent_dict_set");
    }
    
    ret = 0;
    
out:
    if (fd >= 0)
        close(fd);
    return ret;
}
