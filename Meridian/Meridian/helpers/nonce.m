//
//  nonce.m
//  Meridian
//
//  Created by Ben on 29/07/2018.
//

#import <Foundation/Foundation.h>
#include "iokit.h"

#define kIONVRAMDeletePropertyKey       "IONVRAM-DELETE-PROPERTY"
#define kIONVRAMForceSyncNowPropertyKey "IONVRAM-FORCESYNCNOW-PROPERTY"
#define kNonceKey                       "com.apple.System.boot-nonce"

CFMutableDictionaryRef makeDict(const char *key, const char *val) {
    CFStringRef cfKey = CFStringCreateWithCStringNoCopy(NULL, key, kCFStringEncodingUTF8, kCFAllocatorNull);
    CFStringRef cfVal = CFStringCreateWithCStringNoCopy(NULL, val, kCFStringEncodingUTF8, kCFAllocatorNull);
    
    CFMutableDictionaryRef dict = CFDictionaryCreateMutable(NULL,
                                                            0,
                                                            &kCFCopyStringDictionaryKeyCallBacks,
                                                            &kCFTypeDictionaryValueCallBacks);
    if (!cfKey || !dict || !cfVal) {
        return NULL;
    }
    
    CFDictionarySetValue(dict, cfKey, cfVal);
    
    CFRelease(cfKey);
    CFRelease(cfVal);
    return dict;
}

int applyDict(CFMutableDictionaryRef dict) {
    io_service_t nvram = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("IODTNVRAM"));
    if (!MACH_PORT_VALID(nvram)) {
        return 1;
    }
    
    kern_return_t kret = IORegistryEntrySetCFProperties(nvram, dict);
    if (kret != KERN_SUCCESS) {
        return 1;
    }
    
    return 0;
}

int applyToNvram(const char *key, const char *val) {
    CFMutableDictionaryRef dict = makeDict(key, val);
    if (!dict) {
        return 1;
    }
    
    int ret = applyDict(dict);
    
    CFRelease(dict);
    return ret;
}

int set_boot_nonce(const char *gen) {
    int ret = applyToNvram(kIONVRAMDeletePropertyKey, kNonceKey);
    
    // set even if deletion failed
    ret =        applyToNvram(kNonceKey, gen);
    ret = ret || applyToNvram(kIONVRAMForceSyncNowPropertyKey, kNonceKey);
    
    return ret;
}

const char *copy_boot_nonce() {
    uint32_t length = 1024;
    char buf[length];
    
    mach_port_t nvram = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("IODTNVRAM"));
    if (!MACH_PORT_VALID(nvram)) {
        return NULL;
    }
    
    kern_return_t err = IORegistryEntryGetProperty(nvram, "com.apple.System.boot-nonce", (void *)buf, &length);
    if (err != KERN_SUCCESS) {
        return NULL;
    }
    
    buf[length] = '\0';
    return strdup(buf);
}
