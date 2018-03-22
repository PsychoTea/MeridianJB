#ifndef PATCHFINDER64_H_
#define PATCHFINDER64_H_

#define CACHED_FIND(type, name) \
	type __##name(void);\
	type name(void) { \
		type cached = 0; \
		if (cached == 0) { \
			cached = __##name(); \
		} \
		return cached; \
	} \
	type __##name(void)

int init_kernel(uint64_t base, const char *filename);
void term_kernel(void);

// Fun part
uint64_t find_add_x0_x0_0x40_ret(void);
uint64_t find_OSBoolean_True(void);
uint64_t find_OSBoolean_False(void);
uint64_t find_osunserializexml(void);
uint64_t find_vfs_context_current(void);
uint64_t find_vnode_getfromfd(void);
uint64_t find_csblob_ent_dict_set(void);
uint64_t find_csblob_get_ents(void);


#endif
