#include <sched.h>
#include <sys/param.h>
#include <sys/stat.h>

#include "common.h"
#include "kern_utils.h"
#include "kexecute.h"
#include "kmem.h"
#include "offsetof.h"
#include "osobject.h"
#include "sandbox.h"

mach_port_t tfp0;
uint64_t kernel_base;
uint64_t kernel_slide;

uint64_t offset_kernel_task;
uint64_t offset_zonemap;
uint64_t offset_add_ret_gadget;
uint64_t offset_osboolean_true;
uint64_t offset_osboolean_false;
uint64_t offset_osunserializexml;
uint64_t offset_smalloc;

uint64_t proc_find(pid_t pid) {
    static uint64_t kernproc = 0;
    if (kernproc == 0) {
        kernproc = rk64(rk64(offset_kernel_task) + offsetof_bsd_info);
        if (kernproc == 0) {
            DEBUGLOG("failed to find kernproc!");
            return 0;
        }
    }
    
    uint64_t proc = kernproc;
    
    if (pid == 0) {
        return proc;
    }
    
    while (proc) {
        uint32_t found_pid = rk32(proc + offsetof_p_pid);
        
        if (found_pid == pid) {
            return proc;
        }
        
        proc = rk64(proc + offsetof_p_p_list);
    }
    
    return 0;
}

CACHED_FIND(uint64_t, our_task_addr) {
    uint64_t proc = proc_find(getpid());
    if (proc == 0) {
        DEBUGLOG("failed to get proc!");
        return 0;
    }
    uint64_t task_addr = rk64(proc + offsetof_task);
    if (task_addr == 0) {
        DEBUGLOG("failed to get task_addr!");
        return 0;
    }
    return task_addr;
}

uint64_t find_port(mach_port_name_t port) {
    static uint64_t is_table = 0;
    if (is_table == 0) {
        uint64_t task_addr = our_task_addr();
        if (!task_addr) {
            DEBUGLOG("failed to get task_addr!");
            return 0;
        }
        uint64_t itk_space = rk64(task_addr + offsetof_itk_space);
        if (!itk_space) {
            DEBUGLOG("failed to get itk_space!");
            return 0;
        }
        is_table = rk64(itk_space + offsetof_ipc_space_is_table);
        if (!is_table) {
            DEBUGLOG("failed to get is_table!");
            return 0;
        }
    }
  
    uint32_t port_index = port >> 8;
    const int sizeof_ipc_entry_t = 0x18;
    uint64_t port_addr = rk64(is_table + (port_index * sizeof_ipc_entry_t));
    if (port_addr == 0) {
        DEBUGLOG("failed to get port_addr!");
        return 0;
    }
    return port_addr;
}

static void set_csflags(uint64_t proc, uint32_t flags, bool value) {
    uint32_t csflags = rk32(proc + offsetof_p_csflags);

    if (value == true) {
        csflags |= flags;
    } else {
        csflags &= ~flags;
    }

    wk32(proc + offsetof_p_csflags, csflags);
}

const char* abs_path_exceptions[] = {
    "/Library",
    "/private/var/mobile/Library",
    "/System/Library/Caches",
    NULL
};

static uint64_t exception_osarray_cache = 0;
uint64_t get_exception_osarray(void) {

    if (exception_osarray_cache == 0) {
        DEBUGLOG("Generating exception_osarray_cache");
        size_t xmlsize = 0x1000;
        size_t len=0;
        ssize_t written=0;
        char *ents = malloc(xmlsize);
        size_t xmlused = sprintf(ents, "<array>");
        for (const char **exception = abs_path_exceptions; *exception; exception++) {
            len = strlen(*exception);
            len += strlen("<string></string>");
            while (xmlused + len >= xmlsize) {
                xmlsize += 0x1000;
                ents = reallocf(ents, xmlsize);
                if (!ents) {
                    CROAK("Unable to reallocate memory");
                    return 0;
                }
            }
            written = sprintf(ents + xmlused, "<string>%s/</string>", *exception);
            if (written < 0) {
                CROAK("Couldn't write string");
                free(ents);
                return 0;
            }
            xmlused += written;
        }
        len = strlen("</array>");
        if (xmlused + len >= xmlsize) {
            xmlsize += len;
            ents = reallocf(ents, xmlsize);
            if (!ents) {
                return 0;
                CROAK("Unable to reallocate memory");
            }
        }
        written = sprintf(ents + xmlused, "</array>");

        exception_osarray_cache = OSUnserializeXML(ents);
        DEBUGLOG("Exceptions stored at 0x%llx: %s", exception_osarray_cache, ents);
        free(ents);
    }

    return exception_osarray_cache;
}

void release_exception_osarray(void) {
    if (exception_osarray_cache != 0) {
        OSObject_Release(exception_osarray_cache);
        exception_osarray_cache = 0;
    }
}

static const char *exc_key = "com.apple.security.exception.files.absolute-path.read-only";

void set_sandbox_extensions(uint64_t proc) {
    uint64_t proc_ucred = rk64(proc + offsetof_p_ucred);
    if (proc_ucred == 0x0)
    {
        DEBUGLOG("unable to find proc_ucred for proc %llx!", proc);
        return;
    }
    
    uint64_t cr_label =rk64(proc_ucred + 0x78);
    if (cr_label == 0x0)
    {
        DEBUGLOG("unable to find cr_lbael for proc %llx!", proc);
        return;
    }
    
    uint64_t sandbox = rk64(cr_label + 0x10);
    if (sandbox == 0x0)
    {
        DEBUGLOG("no sandbox, skipping (proc: %llx)", proc);
        return;
    }

    uint64_t ext = 0;
    for (const char **exception = abs_path_exceptions; *exception; exception++) {
        if (has_file_extension(sandbox, *exception)) {
            DEBUGLOG("already has '%s', skipping", *exception);
            continue;
        }
        ext = extension_create_file(*exception, ext);
        if (ext == 0) {
            DEBUGLOG("extension_create_file(%s) failed, panic!", *exception);
        }
    }
    
    if (ext != 0) {
        extension_add(ext, sandbox, exc_key);
    }
}

char **copy_amfi_entitlements(uint64_t present) {
    unsigned int itemCount = OSArray_ItemCount(present);
    uint64_t itemBuffer = OSArray_ItemBuffer(present);
    size_t bufferSize = 0x1000;
    size_t bufferUsed = 0;
    size_t arraySize = (itemCount+1) * sizeof(char*);
    char **entitlements = malloc(arraySize + bufferSize);
    entitlements[itemCount] = NULL;

    for (int i=0; i<itemCount; i++) {
        uint64_t item = rk64(itemBuffer + (i * sizeof(void *)));
        char *entitlementString = OSString_CopyString(item);
        size_t len = strlen(entitlementString) + 1;
        while (bufferUsed + len > bufferSize) {
            bufferSize += 0x1000;
            entitlements = realloc(entitlements, arraySize + bufferSize);
            if (!entitlements) {
                CROAK("Unable to reallocate memory");
                return NULL;
            }
        }
        entitlements[i] = (char*)entitlements + arraySize + bufferUsed;
        strcpy(entitlements[i], entitlementString);
        bufferUsed += len;
    }
    return entitlements;
}

void set_amfi_entitlements(uint64_t proc) {
    uint64_t proc_ucred = rk64(proc + offsetof_p_ucred);
    if (proc_ucred == 0x0)
    {
        DEBUGLOG("unable to find proc_ucred for proc %llx!", proc);
        return;
    }
    
    uint64_t cr_label =rk64(proc_ucred + 0x78);
    if (cr_label == 0x0)
    {
        DEBUGLOG("unable to find cr_lbael for proc %llx!", proc);
        return;
    }
    
    uint64_t sandbox = rk64(cr_label + 0x10);
    uint64_t amfi_entitlements = rk64(cr_label + 0x8);
    
    bool rv = false;

    uint64_t key = 0;

    if (amfi_entitlements != 0x0)
    {
        key = OSDictionary_GetItem(amfi_entitlements, "com.apple.private.skip-library-validation");
        if (key != offset_osboolean_true) {
            rv = OSDictionary_SetItem(amfi_entitlements, "com.apple.private.skip-library-validation", offset_osboolean_true);
            if (rv != true) {
                DEBUGLOG("failed to set com.apple.private.skip-library-validation!");
            }
        }
        
        if (OPT(GET_TASK_ALLOW)) {
            key = OSDictionary_GetItem(amfi_entitlements, "get-task-allow");
            if (key != offset_osboolean_true) {
                rv = OSDictionary_SetItem(amfi_entitlements, "get-task-allow", offset_osboolean_true);
                if (rv != true) {
                    DEBUGLOG("failed to set get-task-allow!");
                }
            }
        }
    }

    if (!sandbox) {
        DEBUGLOG("Skipping exceptions because no sandbox");
        return;
    }

    uint64_t present = OSDictionary_GetItem(amfi_entitlements, exc_key);

    if (present == 0) {
        DEBUGLOG("present=NULL; setting to %llx", get_exception_osarray());
        rv = OSDictionary_SetItem(amfi_entitlements, exc_key, get_exception_osarray());
        if (rv != true) {
            DEBUGLOG("failed to set %s", exc_key);
        }
        return;
    } else if (present == get_exception_osarray()) {
        DEBUGLOG("Exceptions already set to our array");
        return;
    }

    char **currentExceptions = copy_amfi_entitlements(present);
    Boolean foundEntitlements = true;

    for (const char **exception = abs_path_exceptions; *exception && foundEntitlements; exception++) {
        DEBUGLOG("Looking for %s", *exception);
        Boolean foundException = false;
        for (char **entitlementString = currentExceptions; *entitlementString && !foundException; entitlementString++) {
            char *ent = strdup(*entitlementString);
            int lastchar = strlen(ent) - 1;
            if (ent[lastchar] == '/') ent[lastchar] = '\0';

            if (strcasecmp(ent, *exception) == 0) {
                DEBUGLOG("found existing exception: %s", *entitlementString);
                foundException = true;
            }
            free(ent);
        }
        if (!foundException) {
            foundEntitlements = false;
            DEBUGLOG("did not find exception: %s", *exception);
        }
    }
    free(currentExceptions);

    if (!foundEntitlements) {
        DEBUGLOG("Merging exceptions");
        // FIXME: This could result in duplicate entries but that seems better than always kexecuting many times
        // When this is fixed, update the loop above to not stop on the first missing exception
        rv = OSArray_Merge(present, get_exception_osarray());
    } else {
        DEBUGLOG("All exceptions present");
        rv = true;
    }

    if (rv != true) {
        DEBUGLOG("Setting exc FAILED! amfi_entitlements: 0x%llx present: 0x%llx", amfi_entitlements, present);
    }
}

void fixup_sandbox(uint64_t proc) {
    set_sandbox_extensions(proc);
}

void fixup_cs_valid(uint64_t proc) {
    set_csflags(proc, CS_VALID, true);
}

void fixup_cs_flags(uint64_t proc) {
    int flags = 0;
    if (OPT(GET_TASK_ALLOW)) {
        DEBUGLOG("adding get-task-allow");
        flags |= CS_GET_TASK_ALLOW;
    }
    if (OPT(CS_DEBUGGED)) {
        DEBUGLOG("setting CS_DEBUGGED :(");
        flags |= CS_DEBUGGED;
    }
    if (flags) {
        set_csflags(proc, flags, true);
    }
}

void fixup(pid_t pid) {
    uint64_t proc = proc_find(pid);
    if (proc == 0) {
        DEBUGLOG("failed to find proc for pid %d!", pid);
        return;
    }
    
    fixup_sandbox(proc);
    fixup_cs_flags(proc);
    set_amfi_entitlements(proc);
}

void kern_utils_cleanup() {
    release_exception_osarray();
}
