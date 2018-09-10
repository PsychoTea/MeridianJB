#include <stdlib.h>
#include "cs_blobs.h"

#define LOG(str, args...) do { NSLog(@"[amfid_payload] " str, ##args); } while(0)
#define ERROR(str, args...) LOG("ERROR: [%s] " str, __func__, ##args)
#define INFO(str, args...)  LOG("INFO: " str, ##args)

typedef struct {
    const char *name;
    uint64_t file_off;
    int fd;
    const void *addr;
    size_t size;
} img_info_t;

const void *find_code_signature(img_info_t *info, uint32_t *cs_size);

int find_best_codedir(const void *csblob,
                      uint32_t csblob_size,
                      const CS_CodeDirectory **chosen_cd,
                      uint32_t *csb_offset,
                      const CS_GenericBlob **entitlements);

int hash_code_directory(const CS_CodeDirectory *directory, uint8_t hash[CS_CDHASH_LEN]);

static unsigned int hash_rank(const CS_CodeDirectory *cd);

const char *get_hash_name(uint8_t hash_type);

int open_img(img_info_t* info);
void close_img(img_info_t* info);
