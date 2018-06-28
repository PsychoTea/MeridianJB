#import <Foundation/Foundation.h>
#import <sys/stat.h>
#import "kern_utils.h"
#import "helpers/kmem.h"
#import "helpers/patchfinder64.h"
#import "helpers/kexecute.h"
#import "helpers/offsetof.h"
#import "helpers/osobject.h"
#import "sandbox.h"

mach_port_t tfpzero;
uint64_t kernel_base;
uint64_t kernel_slide;

uint64_t kernprocaddr;
uint64_t offset_zonemap;

uint64_t offset_proc_find;
uint64_t offset_proc_name;

uint64_t proc_find(int pd) {
    NSLog(@"offset_proc_find = %llx, on pd = %d, our pid = %d", offset_proc_find, pd, getpid());
    
    uint64_t addr = kexecute(offset_proc_find, pd, 0, 0, 0, 0, 0, 0);
    NSLog(@"[proc_find] got addr: %llx", addr);
    
    uint64_t fix = zm_fix_addr(addr);
    
    uint32_t got_pid = rk32(fix + 0x10);
    if (got_pid != pd) {
        NSLog(@"[proc_find] failed! pd: %d, got pid: %d", pd, got_pid);
    }
    
    NSLog(@"[proc_find] got fixed addr: %llx", fix);
    
    return fix;
    
//    while (tries-- > 0) {
//        uint64_t proc = rk64(kernprocaddr + 0x08);
//
//        while (proc) {
//            uint32_t proc_pid = rk32(proc + 0x10);
//
//            if (proc_pid == pd) {
//                return proc;
//            }
//
//            proc = rk64(proc + 0x08);
//        }
//    }
    
    // return 0;
}

char *proc_name(int pd) {
    uint64_t proc = proc_find(pd);
    if (proc == 0) {
        return NULL;
    }
    
    char *proc_name = (char *)calloc(40, sizeof(char));
    
    kread(proc + 0x26c, proc_name, 40);
    
    return proc_name;
}

CACHED_FIND(uint64_t, our_task_addr) {
    uint64_t our_proc = proc_find(getpid());

    if (our_proc == 0) {
        fprintf(stderr, "failed to find our_task_addr!\n");
        exit(EXIT_FAILURE);
    }

    return rk64(our_proc + offsetof_task);
}

uint64_t find_port(mach_port_name_t port) {
    uint64_t task_addr = our_task_addr();
  
    uint64_t itk_space = rk64(task_addr + offsetof_itk_space);
  
    uint64_t is_table = rk64(itk_space + offsetof_ipc_space_is_table);
  
    uint32_t port_index = port >> 8;
    const int sizeof_ipc_entry_t = 0x18;
  
    uint64_t port_addr = rk64(is_table + (port_index * sizeof_ipc_entry_t));
    return port_addr;
}

void set_csflags(uint64_t proc) {
    uint32_t csflags = rk32(proc + offsetof_p_csflags);
    csflags = (csflags | CS_PLATFORM_BINARY | CS_INSTALLER | CS_GET_TASK_ALLOW | CS_DEBUGGED) & ~(CS_RESTRICT | CS_HARD | CS_KILL);
    wk32(proc + offsetof_p_csflags, csflags);
}

void set_csblob(uint64_t proc) {
    uint64_t textvp = rk64(proc + offsetof_p_textvp); // vnode of executable
    off_t textoff = rk64(proc + offsetof_p_textoff);
    
    if (textvp != 0){
      uint32_t vnode_type_tag = rk32(textvp + offsetof_v_type);
      uint16_t vnode_type = vnode_type_tag & 0xffff;
      uint16_t vnode_tag = (vnode_type_tag >> 16);
      
      if (vnode_type == 1) {
          uint64_t ubcinfo = rk64(textvp + offsetof_v_ubcinfo);
          
          uint64_t csblobs = rk64(ubcinfo + offsetof_ubcinfo_csblobs);
          while (csblobs != 0) {
              cpu_type_t csblob_cputype = rk32(csblobs + offsetof_csb_cputype);
              unsigned int csblob_flags = rk32(csblobs + offsetof_csb_flags);
              off_t csb_base_offset = rk64(csblobs + offsetof_csb_base_offset);
              uint64_t csb_entitlements = rk64(csblobs + offsetof_csb_entitlements_offset);
              unsigned int csb_signer_type = rk32(csblobs + offsetof_csb_signer_type);
              unsigned int csb_platform_binary = rk32(csblobs + offsetof_csb_platform_binary);
              unsigned int csb_platform_path = rk32(csblobs + offsetof_csb_platform_path);

              wk32(csblobs + offsetof_csb_platform_binary, 1);

              csb_platform_binary = rk32(csblobs + offsetof_csb_platform_binary);
              
              csblobs = rk64(csblobs);
          }
      }
    }
}

const char* abs_path_exceptions[] = {
    "/meridian",
    "/Library",
    "/private/var/mobile/Library",
    "/private/var/mnt",
    NULL
};

uint64_t get_exception_osarray(void) {
    static uint64_t cached = 0;

    if (cached == 0) {
        cached = OSUnserializeXML(
            "<array>"
            "<string>/meridian/</string>"
            "<string>/Library/</string>"
            "<string>/private/var/mobile/Library/</string>"
            "<string>/private/var/mnt/</string>"
            "</array>"
        );
    }

    return cached;
}

static const char *exc_key = "com.apple.security.exception.files.absolute-path.read-only";

void set_sandbox_extensions(uint64_t proc) {
    uint64_t proc_ucred = rk64(proc + 0x100);
    uint64_t sandbox = rk64(rk64(proc_ucred + 0x78) + 0x8 + 0x8);

    if (sandbox == 0) {
        fprintf(stderr, "no sandbox, skipping \n");
        return;
    }

    if (has_file_extension(sandbox, abs_path_exceptions[0])) {
        fprintf(stderr, "already has '%s', skipping \n", abs_path_exceptions[0]);
        return;
    }

    uint64_t ext = 0;
    const char** path = abs_path_exceptions;
    while (*path != NULL) {
        ext = extension_create_file(*path, ext);
        if (ext == 0) {
            fprintf(stderr, "extension_create_file(%s) failed, panic! \n", *path);
            NSLog(@"extension_create_file(%s) failed, panic!", *path);
        }
        ++path;
    }
    
    if (ext != 0) {
        extension_add(ext, sandbox, exc_key);
    }
}

void set_amfi_entitlements(uint64_t proc) {
    uint64_t proc_ucred = rk64(proc + 0x100);
    uint64_t amfi_entitlements = rk64(rk64(proc_ucred + 0x78) + 0x8);

    OSDictionary_SetItem(amfi_entitlements, "get-task-allow", find_OSBoolean_True());
    OSDictionary_SetItem(amfi_entitlements, "com.apple.private.skip-library-validation", find_OSBoolean_True());

    uint64_t present = OSDictionary_GetItem(amfi_entitlements, exc_key);

    int rv = 0;

    if (present == 0) {
        rv = OSDictionary_SetItem(amfi_entitlements, exc_key, get_exception_osarray());
    } else if (present != get_exception_osarray()) {
        unsigned int itemCount = OSArray_ItemCount(present);
        
        BOOL foundEntitlements = NO;
        
        uint64_t itemBuffer = OSArray_ItemBuffer(present);
        
        for (int i = 0; i < itemCount; i++) {
            uint64_t item = rk64(itemBuffer + (i * sizeof(void *)));
            char *entitlementString = OSString_CopyString(item);
            if (strcmp(entitlementString, "/meridian/") == 0){
                foundEntitlements = YES;
                free(entitlementString);
                break;
            }
            free(entitlementString);
        }
        
        if (!foundEntitlements){
            rv = OSArray_Merge(present, get_exception_osarray());
        } else {
            rv = 1;
        }
    } else {
        rv = 1;
    }

    if (rv != 1) {
        NSLog(@"Setting exc FAILED! amfi_entitlements: 0x%llx present: 0x%llx\n", amfi_entitlements, present);
    }
}

int setcsflagsandplatformize(int pid) {
    uint64_t proc = proc_find(pid);
    if (proc == 0) {
        NSLog(@"Unable to find pid %d to entitle!", pid);
        return 1;
    }
    
    set_csflags(proc);
    set_amfi_entitlements(proc);
    set_sandbox_extensions(proc);
    set_csblob(proc);
    return 0;
}
