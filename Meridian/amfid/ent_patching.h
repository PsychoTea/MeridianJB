#include "cs_dingling.h"

int fixup_platform_application(const char *path,
                               uint64_t macho_offset,
                               const void *blob,
                               uint32_t cs_length,
                               uint8_t cd_hash[20],
                               uint32_t csdir_offset,
                               const CS_GenericBlob *entitlements);
