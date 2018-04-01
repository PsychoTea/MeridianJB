//
//  offsetfinder.mm
//  Meridian
//
//  Created by Ben Sparkes on 08/03/2018.
//  Copyright © 2018 Ben Sparkes. All rights reserved.
//

#include "v0rtex.h"
#include "liboffsetfinder64.hpp"
#include "ViewController.h"
#import <Foundation/Foundation.h>

static bool DidInit = false;
static offsets_t off;

extern "C" offsets_t *get_offsets() {
    if (DidInit) {
        return &off;
    }

    try {
        tihmstar::offsetfinder64 fi("/System/Library/Caches/com.apple.kernelcaches/kernelcache");

        off.base = 0xfffffff007004000;

        off.sizeof_task                         = (kptr_t)fi.find_sizeof_task();
        off.task_itk_self                       = (kptr_t)fi.find_task_itk_self();
        off.task_itk_registered                 = (kptr_t)fi.find_task_itk_registered();
        off.task_bsd_info                       = (kptr_t)fi.find_task_bsd_info();
        off.proc_ucred                          = (kptr_t)fi.find_proc_ucred();
        off.vm_map_hdr                          = (kptr_t)fi.find_vm_map_hdr();
        off.ipc_space_is_task                   = (kptr_t)fi.find_ipc_space_is_task();
        off.realhost_special                    = 0x10;
        off.iouserclient_ipc                    = (kptr_t)fi.find_iouserclient_ipc();
        off.vtab_get_retain_count               = (kptr_t)fi.find_vtab_get_retain_count();
        off.vtab_get_external_trap_for_index    = (kptr_t)fi.find_vtab_get_external_trap_for_index();

        off.zone_map                            = (kptr_t)fi.find_zone_map();
        off.kernel_map                          = (kptr_t)fi.find_kernel_map();
        off.kernel_task                         = (kptr_t)fi.find_kernel_task();
        off.realhost                            = (kptr_t)fi.find_realhost();

        off.copyin                              = (kptr_t)fi.find_copyin();
        off.copyout                             = (kptr_t)fi.find_copyout();
        off.chgproccnt                          = (kptr_t)fi.find_chgproccnt();
        off.kauth_cred_ref                      = (kptr_t)fi.find_kauth_cred_ref();
        off.ipc_port_alloc_special              = (kptr_t)fi.find_ipc_port_alloc_special();
        off.ipc_kobject_set                     = (kptr_t)fi.find_ipc_kobject_set();
        off.ipc_port_make_send                  = (kptr_t)fi.find_ipc_port_make_send();
        off.osserializer_serialize              = (kptr_t)fi.find_osserializer_serialize();
        off.rop_ldr_x0_x0_0x10                  = (kptr_t)fi.find_rop_ldr_x0_x0_0x10();

        off.root_vnode                          = (kptr_t)fi.find_rootvnode();
        
        off.vfs_context_current                 = (kptr_t)fi.find_sym("_vfs_context_current");
        off.vnode_getfromfd                     = (kptr_t)fi.find_sym("_vnode_getfromfd");
        off.csblob_ent_dict_set                 = (kptr_t)fi.find_sym("_csblob_entitlements_dictionary_set");
        off.sha1_init                           = (kptr_t)fi.find_sym("_SHA1Init");
        off.sha1_update                         = (kptr_t)fi.find_sym("_SHA1Update");
        off.sha1_final                          = (kptr_t)fi.find_sym("_SHA1Final");
        
        NSLog(@"[OFFSET] sizeof_task = 0x%llx", off.sizeof_task);
        NSLog(@"[OFFSET] task_itk_self = 0x%llx", off.task_itk_self);
        NSLog(@"[OFFSET] task_itk_registered = 0x%llx", off.task_itk_registered);
        NSLog(@"[OFFSET] kernel_task = 0x%llx", off.kernel_task);
        NSLog(@"[OFFSET] rootvnode = 0x%llx", off.root_vnode);
        NSLog(@"[OFFSET] sha1_init = 0x%llx", off.sha1_init);
    } catch (tihmstar::exception &e) {
        NSLog(@"offsetfinder failure! %d (%s)", e.code(), e.what());
        return NULL;
    } catch (std::exception &e) {
        NSLog(@"fatal offsetfinder failure! %s", e.what());
        return NULL;
    }
        
    DidInit = true;

    return &off;
}
