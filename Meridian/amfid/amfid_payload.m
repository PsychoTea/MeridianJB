// xcrun -sdk iphoneos gcc -dynamiclib -arch arm64 -framework Foundation -o amfid_payload.dylib amfid_payload.m
// jtool --sign --inplace amfid_payload.dylib

// Massive creds to @theninjaprawn for his async_wake fork & help getting this patch to work :)

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
#import <Foundation/Foundation.h>
#include <CommonCrypto/CommonDigest.h>

typedef struct __CodeDirectory {
    uint32_t magic;             /* magic number (CSMAGIC_CODEDIRECTORY) */
    uint32_t length;            /* total length of CodeDirectory blob */
    uint32_t version;           /* compatibility version */
    uint32_t flags;             /* setup and mode flags */
    uint32_t hashOffset;        /* offset of hash slot element at index zero */
    uint32_t identOffset;       /* offset of identifier string */
    uint32_t nSpecialSlots;     /* number of special hash slots */
    uint32_t nCodeSlots;        /* number of ordinary (code) hash slots */
    uint32_t codeLimit;         /* limit to main image signature range */
    uint8_t hashSize;           /* size of each hash in bytes */
    uint8_t hashType;           /* type of hash (cdHashType* constants) */
    uint8_t spare1;             /* unused (must be zero) */
    uint8_t pageSize;           /* log2(page size in bytes); 0 => infinite */
    uint32_t spare2;            /* unused (must be zero) */
    /* followed by dynamic content as located by offset fields above */
} CS_CodeDirectory;

typedef struct __BlobIndex {
    uint32_t type;      /* type of entry */
    uint32_t offset;    /* offset of entry */
} CS_BlobIndex;

typedef struct __SuperBlob {
    uint32_t magic;             /* magic number */
    uint32_t length;            /* total length of SuperBlob */
    uint32_t count;             /* number of index entries following */
    CS_BlobIndex index[];       /* (count) entries */
    /* followed by Blobs in no particular order as indicated by offsets in index */
} CS_SuperBlob;

enum {
    CSMAGIC_REQUIREMENT         = 0xfade0c00,   /* single Requirement blob */
    CSMAGIC_REQUIREMENTS        = 0xfade0c01,   /* Requirements vector (internal requirements) */
    CSMAGIC_CODEDIRECTORY       = 0xfade0c02,   /* CodeDirectory blob */
    CSMAGIC_EMBEDDED_SIGNATURE  = 0xfade0cc0,   /* embedded form of signature data */
    CSMAGIC_DETACHED_SIGNATURE  = 0xfade0cc1,   /* multi-arch collection of embedded signatures */
    
    CSSLOT_CODEDIRECTORY        = 0,            /* slot index for CodeDirectory */
    CSSLOT_ENTITLEMENTS         = 5,
};

kern_return_t mach_vm_allocate(vm_map_t target,
                               mach_vm_address_t *address,
                               mach_vm_size_t size,
                               int flags);

kern_return_t mach_vm_write(vm_map_t target_task,
                            mach_vm_address_t address,
                            vm_offset_t data,
                            mach_msg_type_number_t dataCnt);

extern kern_return_t mach_vm_deallocate(vm_map_t target,
                                        mach_vm_address_t address,
                                        mach_vm_size_t size);

kern_return_t mach_vm_read_overwrite(vm_map_t target_task, mach_vm_address_t address, mach_vm_size_t size, mach_vm_address_t data, mach_vm_size_t *outsize);
kern_return_t mach_vm_region(vm_map_t target_task, mach_vm_address_t *address, mach_vm_size_t *size, vm_region_flavor_t flavor, vm_region_info_t info, mach_msg_type_number_t *infoCnt, mach_port_t *object_name);

mach_port_t tfpzero = 0;

uint64_t kalloc(vm_size_t size) {
	mach_vm_address_t address = 0;
	mach_vm_allocate(tfpzero, (mach_vm_address_t *)&address, size, VM_FLAGS_ANYWHERE);
	return address;
}

size_t kread(uint64_t where, void *p, size_t size) {
	int rv;
	size_t offset = 0;
	while (offset < size) {
		mach_vm_size_t sz, chunk = 2048;
		if (chunk > size - offset) {
			chunk = size - offset;
		}
		rv = mach_vm_read_overwrite(mach_task_self(), where + offset, chunk, (mach_vm_address_t)p + offset, &sz);
		if (rv || sz == 0) {
			printf("[amfid_payload] error on kread(0x%016llx)\n", (offset + where));
			break;
		}
		offset += sz;
	}
	return offset;
}

uint32_t kread32(uint64_t where) {
	uint32_t out;
	kread(where, &out, sizeof(uint32_t));
	return out;
}

uint64_t kread64(uint64_t where) {
	uint64_t out;
	kread(where, &out, sizeof(uint64_t));
	return out;
}

size_t kwrite(uint64_t where, const void *p, size_t size) {
	int rv;
	size_t offset = 0;
	while (offset < size) {
		size_t chunk = 2048;
		if (chunk > size - offset) {
			chunk = size - offset;
		}
		rv = mach_vm_write(tfpzero, where + offset, (mach_vm_offset_t)p + offset, chunk);
		if (rv) {
			printf("[amfid_payload] error on kwrite(0x%016llx)\n", (offset + where));
			break;
		}
		offset += chunk;
	}
	return offset;
}

void kwrite32(uint64_t where, uint32_t what) {
	uint32_t _what = what;
	kwrite(where, &_what, sizeof(uint32_t));
}

void kwrite64(uint64_t where, uint64_t what) {
	uint64_t _what = what;
	kwrite(where, &_what, sizeof(uint64_t));
}

uint64_t remote_alloc(mach_port_t task_port, uint64_t size)
{
    kern_return_t err;

    mach_vm_offset_t remote_addr = 0;
    mach_vm_size_t remote_size = (mach_vm_size_t)size;
    err = mach_vm_allocate(task_port, &remote_addr, remote_size, 1);
    if (err != KERN_SUCCESS){
    NSLog(@"[amfid_payload] unable to allocate buffer in remote process\n");
    return 0;
    }
    return (uint64_t)remote_addr;
}

void remote_free(mach_port_t task_port, uint64_t base, uint64_t size)
{
    kern_return_t err;

    err = mach_vm_deallocate(task_port, (mach_vm_address_t)base, (mach_vm_size_t)size);
    if (err !=  KERN_SUCCESS) {
        NSLog(@"[amfid_payload] unabble to deallocate remote buffer\n");
        return;
    }
    
    return;
}

uint64_t alloc_and_fill_remote_buffer(mach_port_t task_port, uint64_t local_address, uint64_t length)
{
    kern_return_t err;

    uint64_t remote_address = remote_alloc(task_port, length);

    err = mach_vm_write(task_port, remote_address, (mach_vm_offset_t)local_address, (mach_msg_type_number_t)length);
    if (err != KERN_SUCCESS) {
        NSLog(@"[amfid_payload] unable to write to remote memory\n");
        return 0;
    }

    return remote_address;
}

void remote_read_overwrite(mach_port_t task_port,
                           uint64_t remote_address,
                           uint64_t local_address,
                           uint64_t length)
{
    kern_return_t err;

    mach_vm_size_t outsize = 0;
    err = mach_vm_read_overwrite(task_port, (mach_vm_address_t)remote_address, (mach_vm_size_t)length, (mach_vm_address_t)local_address, &outsize);
    if (err != KERN_SUCCESS){
        NSLog(@"[amfid_payload] remote read failed\n");
        return;
    }

    if (outsize != length){
        NSLog(@"[amfid_payload] remote read was short (expected %llx, got %llx\n", length, outsize);
        return;
    }
}

void remote_write(mach_port_t remote_task_port,
                  uint64_t remote_address,
                  uint64_t local_address,
                  uint64_t length)
{
    kern_return_t err = mach_vm_write(remote_task_port,
                                      (mach_vm_address_t)remote_address,
                                      (vm_offset_t)local_address,
                                      (mach_msg_type_number_t)length);
    if (err != KERN_SUCCESS) {
        NSLog(@"[amfid_payload] remote write failed: %s %x\n", mach_error_string(err), err);
        return;
    }
}

uint64_t binary_load_address() {
    kern_return_t err;
    mach_msg_type_number_t region_count = VM_REGION_BASIC_INFO_COUNT_64;
    memory_object_name_t object_name = MACH_PORT_NULL;
    mach_vm_size_t target_first_size = 0x1000;
    mach_vm_address_t target_first_addr = 0x0;
    struct vm_region_basic_info_64 region = {0};
    err = mach_vm_region(mach_task_self(), &target_first_addr, &target_first_size, VM_REGION_BASIC_INFO_64, (vm_region_info_t)&region, &region_count, &object_name);

    if (err != KERN_SUCCESS) {
        printf("[amfid_payload] failed to get the region\n");
        return -1;
    }

    return target_first_addr;
}


uint32_t swap_uint32(uint32_t val) {
	val = ((val << 8) & 0xFF00FF00 ) | ((val >> 8) & 0xFF00FF);
	return (val << 16) | (val >> 16);
}

uint8_t *get_sha256(uint8_t* code_dir) {
	uint8_t *out = malloc(CC_SHA256_DIGEST_LENGTH);

	uint32_t* code_dir_int = (uint32_t*)code_dir;

    int cd_off = 0;
    while (code_dir_int[cd_off] != 0) {
        cd_off += 1;
    }
    cd_off += 1;
    int actual_off = swap_uint32(code_dir_int[cd_off]);

    code_dir_int = (uint32_t*)(code_dir+actual_off);
    uint32_t realsize = swap_uint32(code_dir_int[1]);
    
	CC_SHA256(code_dir_int, realsize, out);

	return out;
}

uint8_t *get_sha1(uint8_t* code_dir) {
    uint8_t *out = malloc(CC_SHA1_DIGEST_LENGTH);
    
    uint32_t* code_dir_int = (uint32_t*)code_dir;
    
    uint32_t realsize = 0;
    for (int j = 0; j < 10; j++) {
        if (swap_uint32(code_dir_int[j]) == 0xfade0c02) {
            realsize = swap_uint32(code_dir_int[j + 1]);
            code_dir += 4 * j;
        }
    }
    
    CC_SHA1(code_dir, realsize, out);
    
    return out;
}

// creds to @xerub on this one, code taken from libjb (and modified slightly)
// https://github.com/xerub/async_wake_ios/blob/master/async_wake_ios/libjb/trav.c#L194
// this is kinda unecessary since I could just sign everything as SHA1 and have done with
// however it was pretty fun and will make life easier :)
int is_sha1(uint8_t *code_dir) {
    const CS_SuperBlob *super = (CS_SuperBlob *)(code_dir);
    uint32_t count = swap_uint32(super->count);
    
    const CS_BlobIndex *index;
    uint32_t i;
    for (index = super->index, i = 0; i < count; i++, index++) {
        if (swap_uint32(index->type) != CSSLOT_CODEDIRECTORY) {
            continue;
        }
        
        const CS_CodeDirectory *directory = (CS_CodeDirectory *)((uint8_t *)super + swap_uint32(index->offset));
        
        return (directory->hashType == 1 ||
                directory->hashSize == 20);
    }
    
    // wasn't found
    NSLog(@"[amfid_payload] error: unable to find hash type for given code dir");
    return FALSE;
}

// original get_code_directory code worked for most binaries,
// unless they were FAT. this works perfectly :-)
// creds: https://github.com/coolstar/electra/blob/master/basebinaries/amfid_payload/amfid_payload.m#L95
// also added support for 32 bit binaries (check 32bit mach_header)
uint8_t *get_code_directory(const char* file_path, uint64_t file_off) {
    FILE* fd = fopen(file_path, "r");
    
    if (fd == NULL) {
        NSLog(@"[amfid_payload] couldn't open file %s", file_path);
        return NULL;
    }
    
    fseek(fd, 0L, SEEK_END);
    uint64_t file_len = ftell(fd);
    fseek(fd, 0L, SEEK_SET);
    
    if (file_off > file_len){
        NSLog(@"[amfid_payload] file offset greater than length");
        return NULL;
    }
    
    uint32_t magic;
    fread(&magic, sizeof(magic), 1, fd);
    fseek(fd, 0, SEEK_SET);
    
    uint64_t off = file_off;
    int ncmds;
    
    if (magic == MH_MAGIC_64) {
        struct mach_header_64 mh64;
        fread(&mh64, sizeof(mh64), 1, fd);
        off += sizeof(mh64);
        ncmds = mh64.ncmds;
    } else if (magic == MH_MAGIC) {
        struct mach_header mh;
        fread(&mh, sizeof(mh), 1, fd);
        off += sizeof(mh);
        ncmds = mh.ncmds;
    } else if (magic == FAT_CIGAM) { /* FAT bins can be treated with mach_header_64 */
        struct mach_header_64 mh64;
        fread(&mh64, sizeof(mh64), 1, fd);
        off += sizeof(mh64);
        ncmds = mh64.ncmds;
    } else {
        NSLog(@"[amfid_payload] your magic is not valid in these lands! %ux", magic);
        return NULL;
    }
    
    if (off > file_len) {
        NSLog(@"[amfid_payload] unexpected end of file");
        return NULL;
    }
    
    fseek(fd, off, SEEK_SET);
    
    for (int i = 0; i < ncmds; i++) {
        if (off + sizeof(struct load_command) > file_len) {
            NSLog(@"[amfid_payload] unexpected end of file");
            return NULL;
        }
        
        const struct load_command cmd;
        fseek(fd, off, SEEK_SET);
        fread((void*)&cmd, sizeof(struct load_command), 1, fd);
        if (cmd.cmd == LC_CODE_SIGNATURE) {
            uint32_t off_cs;
            fread(&off_cs, sizeof(uint32_t), 1, fd);
            uint32_t size_cs;
            fread(&size_cs, sizeof(uint32_t), 1, fd);
            
            if (off_cs + file_off + size_cs > file_len) {
                NSLog(@"[amfid_payload] unexpected end of file");
                return NULL;
            }
            
            uint8_t *cd = malloc(size_cs);
            fseek(fd, off_cs + file_off, SEEK_SET);
            fread(cd, size_cs, 1, fd);
            return cd;
        } else {
            off += cmd.cmdsize;
            if (off > file_len) {
                NSLog(@"[amfid_payload] unexpected end of file");
                return NULL;
            }
        }
    }
    
    NSLog(@"[amfid_payload] couldn't find the code sig for %s", file_path);
    return NULL;
}

uint64_t real_func = 0;

typedef int (*t)(NSString* file, NSDictionary* options, NSMutableDictionary** info);

int fake_MISValidateSignatureAndCopyInfo(NSString* file, NSDictionary* options, NSMutableDictionary** info) {
    const char* file_path = [file UTF8String];
    NSLog(@"[amfid_payload] Called for file %s", file_path);
    
    *info = [[NSMutableDictionary alloc] init];
    
    // Call the original func
    t actual_func = (t)real_func;
    actual_func(file, options, info);
    
    if (![*info objectForKey:@"CdHash"]) {
        NSLog(@"[amfid_payload] Binary is unsigned - doing some magic");
        
        NSNumber* file_offset = [options objectForKey:@"UniversalFileOffset"];
        uint64_t file_off = [file_offset unsignedLongLongValue];
        
        uint8_t* code_dir = get_code_directory(file_path, file_off);
        
        if (code_dir == NULL) {
            NSLog(@"[amfid_payload] Not patching file - missing code directory (file: %s)", file_path);
            return 0;
        }
        
        uint8_t* cd_hash; // cd_hash size will always be 20 - it gets shortened
        int length; // however DIGEST_LENGTH may be longer, so we can differentiate between sha1 & sha256
        if (is_sha1(code_dir)) {
            /* CdHash is SHA1 */
            cd_hash = get_sha1(code_dir);
            length = CC_SHA1_DIGEST_LENGTH;
        } else {
            /* CdHash is SHA256 */
            cd_hash = get_sha256(code_dir);
            length = CC_SHA256_DIGEST_LENGTH;
        }
        
        NSLog(@"[amfid_payload] Got cd_hash of length %d (SHA%s - size %lu)",
              length,
              (length == 20 ? "1" : "256"),
              sizeof(cd_hash));
        
        [*info setValue:[[NSData alloc] initWithBytes:cd_hash length:length]
                 forKey:@"CdHash"];
        
        NSLog(@"[amfid_payload] Patched in CdHash for %s", file_path);
    } else {
        NSLog(@"[amfid_payload] Ignoring %s (already signed)", file_path);
    }

    return 0;
}

void* hook_funcs(void* arg) {
    if (binary_load_address() == -1) {
        return NULL;
    }

    /* Finding the location of MISValidateSignatureAndCopyInfo from Ian Beer's triple_fetch */
    void* libmis_handle = dlopen("libmis.dylib", RTLD_NOW);
    if (libmis_handle == NULL) {
        NSLog(@"Failed to open the dylib!");
        return NULL;
    }
    
    void* sym = dlsym(libmis_handle, "MISValidateSignatureAndCopyInfo");
    if (sym == NULL) {
        NSLog(@"[amfid_payload] unable to resolve MISValidateSignatureAndCopyInfo\n");
        return NULL;
    }
    
    uint64_t buf_size = 0x8000;
    uint8_t* buf = malloc(buf_size);

    remote_read_overwrite(mach_task_self(), binary_load_address(), (uint64_t)buf, buf_size);
    uint8_t* found_at = memmem(buf, buf_size, &sym, sizeof(sym));
    
    if (found_at == NULL) {
        NSLog(@"[amfid_payload] unable to find MISValidateSignatureAndCopyInfo in __la_symbol_ptr\n");
        return NULL;
    }
    
    uint64_t patch_offset = found_at - buf;

    uint64_t fake_func_addr = (uint64_t)&fake_MISValidateSignatureAndCopyInfo;

    real_func = kread64(binary_load_address() + patch_offset);
    
    // Replace it with our version
    remote_write(mach_task_self(), binary_load_address()+patch_offset, (uint64_t)&fake_func_addr, 8);

    NSLog(@"[amfid_payload] The MISValidateSignatureAndCopyInfo function has been successfully hooked!");
    
    fclose(fopen("/var/tmp/amfid_payload.alive", "w+"));
    
    return NULL;
}

__attribute__ ((constructor))
static void ctor(void) {
    NSLog(@"[amfid_payload] Preparing to fuck up amfid :)");
    pthread_t thread;
    pthread_create(&thread, NULL, hook_funcs, NULL);
}
