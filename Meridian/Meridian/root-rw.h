//
//  root-rw.h
//  Meridian
//
//  Created by Ben Sparkes on 16/12/2017.
//  Copyright © 2017 Ben Sparkes. All rights reserved.
//

#include <mach/mach.h>
#include <sys/mount.h>

int mount_root(task_t tfp0, uint64_t kslide);
