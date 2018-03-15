//
//  root-rw.h
//  Meridian
//
//  Created by Ben Sparkes on 16/12/2017.
//  Copyright © 2017 Ben Sparkes. All rights reserved.
//

#include <mach/mach.h>
#include <sys/mount.h>

int mount_root(uint64_t kslide, int pre130);
