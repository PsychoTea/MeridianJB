// Massive creds to @theninjaprawn for his async_wake fork & help getting this patch to work :)
// [2018-3-14] big thanks for stek for letting me use his code on proper blob parsing :) -> https://github.com/stek29/electra/blob/amfid_fix/basebinaries/amfid_payload/

#include <dlfcn.h>
#include <stdio.h>
#include <unistd.h>
#include <sys/types.h>
#include <mach/mach.h>
#include <mach-o/loader.h>
#include <mach-o/fat.h>
#include <mach/error.h>
#include <errno.h>
#include <stdlib.h>
#include <sys/sysctl.h>
#include <dlfcn.h>
#include <sys/mman.h>
#include <spawn.h>
#include <sys/stat.h>
#include <pthread.h>
#include <Foundation/Foundation.h>
#include <CommonCrypto/CommonDigest.h>
#include "helpers/fishhook.h"
#include "kern_utils.h"
#include "helpers/kexecute.h"
#include "helpers/kmem.h"
#include "helpers/patchfinder64.h"
#include "ent_patching.h"

int (*old_MISValidateSignatureAndCopyInfo)(NSString* file, NSDictionary* options, NSMutableDictionary** info);
int (*old_MISValidateSignatureAndCopyInfo_broken)(NSString* file, NSDictionary* options, NSMutableDictionary** info);

int fake_MISValidateSignatureAndCopyInfo(NSString* file, NSDictionary* options, NSMutableDictionary** info) {
    const char* file_path = [file UTF8String];
    INFO(@"called for file %s", file_path);
    
    // Call the original func
    old_MISValidateSignatureAndCopyInfo(file, options, info);
    
    if (info == NULL) {
        INFO("info is null - skipping");
        return 0;
    }
    
    if (*info == NULL) {
        *info = [[NSMutableDictionary alloc] init];
        if (*info == nil) {
            ERROR("out of memory - can't alloc info");
            return 0;
        }
    }
    
    if ([*info objectForKey:@"CdHash"]) {
        return 0;
    }
    
    NSNumber* file_offset = [options objectForKey:@"UniversalFileOffset"];
    uint64_t file_off = [file_offset unsignedLongLongValue];
    
    img_info_t img;
    img.name = file.UTF8String;
    img.file_off = file_off;
    
    if (open_img(&img)) {
        ERROR(@"failed to open file: %@", file);
        return 0;
    }
    
    uint32_t cs_length;
    const uint8_t *cs = find_code_signature(&img, &cs_length);
    if (cs == NULL) {
        ERROR(@"can't find code signature: %@", file);
        close_img(&img);
        return 0;
    }
    
    const CS_CodeDirectory *chosen_csdir = NULL;
    uint32_t cdir_offset = 0;
    const CS_GenericBlob *entitlements = NULL; // may be NULL for no entitlements
    int ret = find_best_codedir(cs, cs_length, &chosen_csdir, &cdir_offset, &entitlements);
    if (ret != 0) {
        ERROR(@"failed to find the best code directory");
        close_img(&img);
        return 0;
    }
    
    uint8_t cd_hash[CS_CDHASH_LEN];
    ret = hash_code_directory(chosen_csdir, cd_hash);
    if (ret != 0) {
        ERROR(@"failed to hash code directory");
        close_img(&img);
        return 0;
    }
    
    NSData *ns_cdhash = [[NSData alloc] initWithBytes:cd_hash length:sizeof(cd_hash)];
    [*info setValue: ns_cdhash forKey:@"CdHash"];

    const char *hash_name = get_hash_name(chosen_csdir->hashType);
    
    INFO(@"magic was performed [%08x (%s)]: %@", ntohl(*(uint64_t *)cd_hash), hash_name, file);
    
    // let's check entitlements, add platform-application if necessary
    ret = fixup_platform_application(file.UTF8String,
                                     file_off,
                                     cs,
                                     cs_length,
                                     cd_hash,
                                     cdir_offset,
                                     entitlements);
    
    if (ret != 0) {
        ERROR(@"fixup_platform_application returned: %d", ret);
    }
    
    close_img(&img);
    return 0;
}

void *hook_funcs(void *arg) {
    INFO(@"created new thread");
    // This is some wicked crazy shit that needs to happen to correctly patch
    // after amfid has been killed & launched & patched again... it's nuts.
    // shouldn't even work. creds whoever came up w this @ ElectraTeam
    void *libmis = dlopen("/usr/lib/libmis.dylib", RTLD_NOW);
    old_MISValidateSignatureAndCopyInfo = dlsym(libmis, "MISValidateSignatureAndCopyInfo");
    
    struct rebinding rebindings[] = {
        { "MISValidateSignatureAndCopyInfo", (void *)fake_MISValidateSignatureAndCopyInfo, (void **)&old_MISValidateSignatureAndCopyInfo_broken }
        /*                                                                                                       you can say that again  ^^^^^^ */
    };
    
    rebind_symbols(rebindings, 1);
    
    // touch file so Meridian know's we're alive in here
    fclose(fopen("/var/tmp/amfid_payload.alive", "w+"));
    
    return NULL;
}

__attribute__ ((constructor))
static void ctor(void) {
    INFO("preparing to fuck up amfid :)");
    
    kern_return_t ret = host_get_special_port(mach_host_self(), HOST_LOCAL_NODE, 4, &tfp0);
    if (ret != KERN_SUCCESS || tfp0 == MACH_PORT_NULL) {
        INFO("failed to get tfp0!");
        return;
    }
    INFO("got tfp0: %x", tfp0);
    
    NSDictionary *off_file = [NSDictionary dictionaryWithContentsOfFile:@"/meridian/offsets.plist"];
    
    kernel_base                 = strtoull([off_file[@"KernelBase"]           UTF8String], NULL, 16);
    kernel_slide                = strtoull([off_file[@"KernelSlide"]          UTF8String], NULL, 16);
    offset_zonemap              = strtoull([off_file[@"ZoneMap"]              UTF8String], NULL, 16) + kernel_slide;
    offset_kernel_task          = strtoull([off_file[@"KernelTask"]           UTF8String], NULL, 16) + kernel_slide;
    offset_vfs_context_current  = strtoull([off_file[@"VfsContextCurrent"]    UTF8String], NULL, 16) + kernel_slide;
    offset_vnode_getfromfd      = strtoull([off_file[@"VnodeGetFromFD"]       UTF8String], NULL, 16) + kernel_slide;
    offset_vnode_getattr        = strtoull([off_file[@"VnodeGetAttr"]         UTF8String], NULL, 16) + kernel_slide;
    offset_csblob_ent_dict_set  = strtoull([off_file[@"CSBlobEntDictSet"]     UTF8String], NULL, 16) + kernel_slide;
    offset_sha1_init            = strtoull([off_file[@"SHA1Init"]             UTF8String], NULL, 16) + kernel_slide;
    offset_sha1_update          = strtoull([off_file[@"SHA1Update"]           UTF8String], NULL, 16) + kernel_slide;
    offset_sha1_final           = strtoull([off_file[@"SHA1Final"]            UTF8String], NULL, 16) + kernel_slide;
    INFO(@"grabbed all offsets! eg: %llx, %llx, slide: %llx", offset_kernel_task, offset_sha1_final, kernel_slide);
    
    init_kernel(kernel_base, NULL);
    init_kexecute();
    
    pthread_t thread;
    pthread_create(&thread, NULL, hook_funcs, NULL);
}
