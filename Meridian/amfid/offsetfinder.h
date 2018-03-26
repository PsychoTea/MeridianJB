//
//  offsetfinder.h
//  Meridian
//
//  Created by Ben Sparkes on 08/03/2018.
//  Copyright © 2018 Ben Sparkes. All rights reserved.
//

#include <stdint.h> // uint*_t
#ifndef offsetfinder_h
#define offsetfinder_h

typedef struct
{
    uint64_t kernel_task;
    uint64_t zone_map;
    uint64_t vfs_context_current;
    uint64_t vnode_getfromfd;
    uint64_t csblob_ent_dict_set;
    uint64_t csblob_get_ents;
} offsets_t;

offsets_t off;

#ifdef __cplusplus
extern "C"
#endif
offsets_t *get_offsets(uint64_t kernel_slide);

#endif /* offsetfinder_h */
