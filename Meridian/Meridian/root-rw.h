//
//  root-rw.h
//  Meridian
//
//  Created by Ben Sparkes on 16/12/2017.
//  Copyright © 2017 Ben Sparkes. All rights reserved.
//

#include <mach/mach.h>
#include <sys/mount.h>

int mount_root(uint64_t kslide, uint64_t root_vnode, int pre130);
