#ifndef PATCHFINDER64_H_
#define PATCHFINDER64_H_

#import "common.h"
#import <mach/mach.h>

int init_patchfinder(const char *filename);
void term_kernel(void);

enum { SearchInCore, SearchInPrelink };

uint64_t find_register_value(uint64_t where, int reg);
uint64_t find_reference(uint64_t to, int n, int prelink);
uint64_t find_strref(const char *string, int n, int prelink);

// amfi trust cache patching
uint64_t find_trustcache(void);
uint64_t find_amficache(void);

// lwvm patching for <10.3
uint64_t find_boot_args(unsigned *cmdline_offset);

// used in jailbreakd
uint64_t find_add_x0_x0_0x40_ret(void);
uint64_t find_OSBoolean_True(void);
uint64_t find_OSBoolean_False(void);
uint64_t find_OSUnserializeXML(void);
uint64_t find_smalloc(void);

#endif
