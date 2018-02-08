//
//  v0rtex-old.h
//  Meridian
//
//  Created by Ben Sparkes on 08/02/2018.
//  Copyright © 2018 Ben Sparkes. All rights reserved.
//

#import "common.h"
#include <mach/mach.h>
#include <stdint.h>

kern_return_t v0rtex_old(task_t *tfp0, kptr_t *kslide, kptr_t *kernucred, kptr_t *kernprocaddr)
