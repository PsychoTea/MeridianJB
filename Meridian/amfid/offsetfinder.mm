//
//  offsetfinder.mm
//  Meridian
//
//  Created by Ben Sparkes on 08/03/2018.
//  Copyright © 2018 Ben Sparkes. All rights reserved.
//

#include "offsetfinder.h"
#include "liboffsetfinder64.hpp"
#import <Foundation/Foundation.h>

static bool DidInit = false;

extern "C" offsets_t *get_offsets(uint64_t kernel_slide) {
    if (DidInit) {
        return &off;
    }

    try {
        NSLog(@"initializing liboffsetfinder64...");
        tihmstar::offsetfinder64 fi("/System/Library/Caches/com.apple.kernelcaches/kernelcache");
        NSLog(@"initilization complete.");
        
        off.kernel_task                         = (uint64_t)fi.find_kernel_task() + kernel_slide;
        NSLog(@"[OFFSET] kernel_task = 0x%llx", off.kernel_task);
        off.zone_map                            = (uint64_t)fi.find_zone_map() + kernel_slide;
        NSLog(@"[OFFSET] zone_map = 0x%llx", off.zone_map);
        off.vfs_context_current                 = (uint64_t)fi.find_sym("_vfs_context_current") + kernel_slide;
        NSLog(@"[OFFSET] vfs_context_current = 0x%llx", off.vfs_context_current);
        off.vnode_getfromfd                     = (uint64_t)fi.find_sym("_vnode_getfromfd") + kernel_slide;
        NSLog(@"[OFFSET] vnode_getfromfd = 0x%llx", off.vnode_getfromfd);
        off.csblob_ent_dict_set                 = (uint64_t)fi.find_sym("_csblob_entitlements_dictionary_set") + kernel_slide;
        NSLog(@"[OFFSET] csblob_ent_dict_set = 0x%llx", off.csblob_ent_dict_set);
        off.csblob_get_ents                     = (uint64_t)fi.find_sym("_csblob_get_entitlements") + kernel_slide;
        NSLog(@"[OFFSET] csblob_get_ents = 0x%llx", off.csblob_get_ents);
    }
    catch (tihmstar::exception &e) {
        NSLog(@"offsetfinder failure! %d (%s)", e.code(), e.what());
        return NULL;
    } catch (std::exception &e) {
        NSLog(@"fatal offsetfinder failure! %s", e.what());
        return NULL;
    }
        
    DidInit = true;

    return &off;
}
