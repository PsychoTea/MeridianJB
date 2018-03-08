//
//  offsetfinder.h
//  Meridian
//
//  Created by Ben Sparkes on 08/03/2018.
//  Copyright © 2018 Ben Sparkes. All rights reserved.
//

#ifndef offsetfinder_h
#define offsetfinder_h

#ifdef __cplusplus
extern "C"
#endif

offsets_t *get_offsets(void);

uint64_t get_offset_rootvnode(void);
uint64_t get_offset_zonemap(void);

#endif /* offsetfinder_h */
