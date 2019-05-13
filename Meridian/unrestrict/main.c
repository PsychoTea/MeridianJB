#include <sys/param.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

#include <mach/mach.h>
#include <mach/error.h>

#include "common.h"
#include "kern_utils.h"
#include "kexecute.h"
#include "kmem.h"

bool initialized = false;
uint64_t offset_options = 0;

__attribute__((constructor))
void ctor() {
    bool found_offsets = false;
    kern_return_t err;
    
    DEBUGLOG("the fun and games shall begin! (applying lube...)");
    
    // tfp0, kexecute
    err = host_get_special_port(mach_host_self(), HOST_LOCAL_NODE, 4, &tfp0);
    if (err != KERN_SUCCESS) {
        DEBUGLOG("host_get_special_port 4: %s", mach_error_string(err));
        tfp0 = KERN_INVALID_TASK;
        return;
    }
    DEBUGLOG("tfp0: %x", tfp0);
    
    CFURLRef fileURL = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, CFSTR("/meridian/offsets.plist"), kCFURLPOSIXPathStyle, false);
    if (fileURL == NULL) {
        DEBUGLOG("Unable to create URL");
        return;
    }
    CFDataRef off_file_data;
    SInt32 errorCode;
    Boolean status = CFURLCreateDataAndPropertiesFromResource(
                                                              kCFAllocatorDefault, fileURL, &off_file_data,
                                                              NULL, NULL, &errorCode);
    
    CFRelease(fileURL);
    if (!status) {
        DEBUGLOG("Unable to read /meridian/offsets.plist");
        return;
    }
    
    DEBUGLOG("off_file_data: %p", off_file_data);
    CFPropertyListRef offsets = CFPropertyListCreateWithData(kCFAllocatorDefault, (CFDataRef)off_file_data, kCFPropertyListImmutable, NULL, NULL);
    CFRelease(off_file_data);
    if (offsets == NULL) {
        DEBUGLOG("Unable to convert /meridian/offsets.plist to property list");
        return;
    }
    
    if (CFGetTypeID(offsets) != CFDictionaryGetTypeID()) {
        DEBUGLOG("/meridian/offsets.plist did not convert to a dictionary");
        CFRelease(offsets);
        return;
    }
    
    // TODO: CFStringGetCStringPtr is not to be relied upon like this... bad things will happen if this is not fixed
    kernel_base             = strtoull(CFStringGetCStringPtr(CFDictionaryGetValue(offsets, CFSTR("KernelBase")), kCFStringEncodingUTF8), NULL, 16);
    kernel_slide            = strtoull(CFStringGetCStringPtr(CFDictionaryGetValue(offsets, CFSTR("KernelSlide")), kCFStringEncodingUTF8), NULL, 16);
    DEBUGLOG("kern base: %llx, slide: %llx", kernel_base, kernel_slide);
    
    offset_kernel_task      = strtoull(CFStringGetCStringPtr(CFDictionaryGetValue(offsets, CFSTR("KernelTask")), kCFStringEncodingUTF8), NULL, 16) + kernel_slide;
    DEBUGLOG("offset_kernel_task: %llx", offset_kernel_task);
    offset_zonemap          = strtoull(CFStringGetCStringPtr(CFDictionaryGetValue(offsets, CFSTR("ZoneMap")), kCFStringEncodingUTF8), NULL, 16) + kernel_slide;
    DEBUGLOG("offset_zonemap: %llx", offset_zonemap);
    
    offset_add_ret_gadget   = strtoull(CFStringGetCStringPtr(CFDictionaryGetValue(offsets, CFSTR("AddGadgetRet")), kCFStringEncodingUTF8), NULL, 16);
    DEBUGLOG("offset_add_ret_gadget: %llx", offset_add_ret_gadget);
    offset_osboolean_true   = strtoull(CFStringGetCStringPtr(CFDictionaryGetValue(offsets, CFSTR("OSBooleanTrue")), kCFStringEncodingUTF8), NULL, 16);
    DEBUGLOG("offset_osboolean_true: %llx", offset_osboolean_true);
    offset_osboolean_false  = strtoull(CFStringGetCStringPtr(CFDictionaryGetValue(offsets, CFSTR("OSBooleanFalse")), kCFStringEncodingUTF8), NULL, 16);
    DEBUGLOG("offset_osboolean_false: %llx", offset_osboolean_false);
    offset_osunserializexml = strtoull(CFStringGetCStringPtr(CFDictionaryGetValue(offsets, CFSTR("OSUnserializeXML")), kCFStringEncodingUTF8), NULL, 16);
    DEBUGLOG("offset_osunserializexml: %llx", offset_osunserializexml);
    offset_smalloc          = strtoull(CFStringGetCStringPtr(CFDictionaryGetValue(offsets, CFSTR("Smalloc")), kCFStringEncodingUTF8), NULL, 16);
    DEBUGLOG("offset_smalloc: %llx", offset_smalloc);
    
    CFRelease(offsets);
    found_offsets = true;
    
    if (found_offsets && init_kexecute()) {
        DEBUGLOG("Initialized successfully!");
        initialized = true;
    } else {
        DEBUGLOG("Failed to initialize kexecute :(");
    }
}

__attribute__((destructor))
void dtor() {
    DEBUGLOG("Terminating kexecute");
    kern_utils_cleanup();
    term_kexecute();
}
