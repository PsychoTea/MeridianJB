//
//  root-rw.h
//  v0rtex-s
//
//  Created by Ben on 16/12/2017.
//  Copyright © 2017 Sticktron. All rights reserved.
//

#include <mach/mach.h>
#include <sys/mount.h>

int mount_root(task_t tfp0, uint64_t kslide);
