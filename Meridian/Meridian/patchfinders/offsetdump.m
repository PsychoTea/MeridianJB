//
//  offsetdump.m
//  Meridian
//
//  Created by Ben Sparkes on 30/03/2018.
//  Copyright © 2018 Ben Sparkes. All rights reserved.
//

#import <Foundation/Foundation.h>

#include "patchfinder64.h"
#include "v0rtex.h"

void dumpOffsetsToFile(offsets_t *offsets, uint64_t kernel_base, uint64_t kernel_slide) {
    NSData *blob = [NSData dataWithContentsOfFile:@"/meridian/offsets.plist"];
    NSMutableDictionary *off_file = [NSPropertyListSerialization propertyListWithData:blob
                                                                              options:NSPropertyListMutableContainers
                                                                               format:nil
                                                                                error:nil];
    
    // There is probably a better way than doing this all manually, but ¯\_(ツ)_/¯
    // We don't really need to log *all* of these, but better safe than PR'ing, right?
    // See the amfid patch for an example of using this (amfid/main.m)
    
    off_file[@"Base"]                           = [NSString stringWithFormat:@"0x%016llx", offsets->base];
    off_file[@"KernelBase"]                     = [NSString stringWithFormat:@"0x%016llx", kernel_base];
    off_file[@"KernelSlide"]                    = [NSString stringWithFormat:@"0x%016llx", kernel_slide];
    
    off_file[@"SizeOfTask"]                     = [NSString stringWithFormat:@"0x%016llx", offsets->sizeof_task];
    off_file[@"TaskItkSelf"]                    = [NSString stringWithFormat:@"0x%016llx", offsets->task_itk_self];
    off_file[@"TaskItkRegistered"]              = [NSString stringWithFormat:@"0x%016llx", offsets->task_itk_registered];
    off_file[@"TaskBsdInfo"]                    = [NSString stringWithFormat:@"0x%016llx", offsets->task_bsd_info];
    off_file[@"ProcUcred"]                      = [NSString stringWithFormat:@"0x%016llx", offsets->proc_ucred];
    off_file[@"VmMapHdr"]                       = [NSString stringWithFormat:@"0x%016llx", offsets->vm_map_hdr];
    off_file[@"IpcSpaceIsTask"]                 = [NSString stringWithFormat:@"0x%016llx", offsets->ipc_space_is_task];
    off_file[@"RealhostSpecial"]                = [NSString stringWithFormat:@"0x%016llx", offsets->realhost_special];
    off_file[@"IOUserClientIPC"]                = [NSString stringWithFormat:@"0x%016llx", offsets->iouserclient_ipc];
    off_file[@"VtabGetRetainCount"]             = [NSString stringWithFormat:@"0x%016llx", offsets->vtab_get_retain_count];
    off_file[@"VtabGetExternalTrapForIndex"]    = [NSString stringWithFormat:@"0x%016llx", offsets->vtab_get_external_trap_for_index];
    
    off_file[@"ZoneMap"]                        = [NSString stringWithFormat:@"0x%016llx", offsets->zone_map];
    off_file[@"KernelMap"]                      = [NSString stringWithFormat:@"0x%016llx", offsets->kernel_map];
    off_file[@"KernelTask"]                     = [NSString stringWithFormat:@"0x%016llx", offsets->kernel_task];
    off_file[@"RealHost"]                       = [NSString stringWithFormat:@"0x%016llx", offsets->realhost];
    
    off_file[@"CopyIn"]                         = [NSString stringWithFormat:@"0x%016llx", offsets->copyin];
    off_file[@"CopyOut"]                        = [NSString stringWithFormat:@"0x%016llx", offsets->copyout];
    off_file[@"Chgproccnt"]                     = [NSString stringWithFormat:@"0x%016llx", offsets->chgproccnt];
    off_file[@"KauthCredRef"]                   = [NSString stringWithFormat:@"0x%016llx", offsets->kauth_cred_ref];
    off_file[@"IpcPortAllocSpecial"]            = [NSString stringWithFormat:@"0x%016llx", offsets->ipc_port_alloc_special];
    off_file[@"IpcKobjectSet"]                  = [NSString stringWithFormat:@"0x%016llx", offsets->ipc_kobject_set];
    off_file[@"IpcPortMakeSend"]                = [NSString stringWithFormat:@"0x%016llx", offsets->ipc_port_make_send];
    off_file[@"OSSerializerSerialize"]          = [NSString stringWithFormat:@"0x%016llx", offsets->osserializer_serialize];
    off_file[@"RopLDR"]                         = [NSString stringWithFormat:@"0x%016llx", offsets->rop_ldr_x0_x0_0x10];
    
    off_file[@"RootVnode"]                      = [NSString stringWithFormat:@"0x%016llx", offsets->root_vnode];
    
    off_file[@"VfsContextCurrent"]              = [NSString stringWithFormat:@"0x%016llx", offsets->vfs_context_current];
    off_file[@"VnodeGetFromFD"]                 = [NSString stringWithFormat:@"0x%016llx", offsets->vnode_getfromfd];
    off_file[@"VnodeGetAttr"]                   = [NSString stringWithFormat:@"0x%016llx", offsets->vnode_getattr];
    off_file[@"CSBlobEntDictSet"]               = [NSString stringWithFormat:@"0x%016llx", offsets->csblob_ent_dict_set];
    off_file[@"SHA1Init"]                       = [NSString stringWithFormat:@"0x%016llx", offsets->sha1_init];
    off_file[@"SHA1Update"]                     = [NSString stringWithFormat:@"0x%016llx", offsets->sha1_update];
    off_file[@"SHA1Final"]                      = [NSString stringWithFormat:@"0x%016llx", offsets->sha1_final];
    
    [off_file writeToFile:@"/meridian/offsets.plist" atomically:YES];
}
