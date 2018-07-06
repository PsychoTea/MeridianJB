#import <stdio.h>

#import <mach/mach.h>
#import <mach/error.h>
#import <mach/message.h>

#import <CoreFoundation/CoreFoundation.h>

/****** IOKit/IOKitLib.h *****/
typedef mach_port_t io_service_t;
typedef mach_port_t io_connect_t;

extern const mach_port_t kIOMasterPortDefault;
#define IO_OBJECT_NULL (0)

kern_return_t
IOConnectCallAsyncMethod(
						 mach_port_t     connection,
						 uint32_t        selector,
						 mach_port_t     wakePort,
						 uint64_t*       reference,
						 uint32_t        referenceCnt,
						 const uint64_t* input,
						 uint32_t        inputCnt,
						 const void*     inputStruct,
						 size_t          inputStructCnt,
						 uint64_t*       output,
						 uint32_t*       outputCnt,
						 void*           outputStruct,
						 size_t*         outputStructCntP);

kern_return_t
IOConnectCallMethod(
					mach_port_t     connection,
					uint32_t        selector,
					const uint64_t* input,
					uint32_t        inputCnt,
					const void*     inputStruct,
					size_t          inputStructCnt,
					uint64_t*       output,
					uint32_t*       outputCnt,
					void*           outputStruct,
					size_t*         outputStructCntP);

io_service_t
IOServiceGetMatchingService(
							mach_port_t  _masterPort,
							CFDictionaryRef  matching);

CFMutableDictionaryRef
IOServiceMatching(
				  const char* name);

kern_return_t
IOServiceOpen(
			  io_service_t  service,
			  task_port_t   owningTask,
			  uint32_t      type,
			  io_connect_t* connect );

kern_return_t IOConnectTrap6(io_connect_t connect, uint32_t index, uintptr_t p1, uintptr_t p2, uintptr_t p3, uintptr_t p4, uintptr_t p5, uintptr_t p6);
kern_return_t mach_vm_read(vm_map_t target_task, mach_vm_address_t address, mach_vm_size_t size, vm_offset_t *data, mach_msg_type_number_t *dataCnt);
kern_return_t mach_vm_read_overwrite(vm_map_t target_task, mach_vm_address_t address, mach_vm_size_t size, mach_vm_address_t data, mach_vm_size_t *outsize);
kern_return_t mach_vm_write(vm_map_t target_task, mach_vm_address_t address, vm_offset_t data, mach_msg_type_number_t dataCnt);
kern_return_t mach_vm_allocate(vm_map_t target, mach_vm_address_t *address, mach_vm_size_t size, int flags);
kern_return_t mach_vm_deallocate(vm_map_t target, mach_vm_address_t address, mach_vm_size_t size);

#define CS_VALID                        0x0000001    /* dynamically valid */
#define CS_ADHOC                        0x0000002    /* ad hoc signed */
#define CS_GET_TASK_ALLOW               0x0000004    /* has get-task-allow entitlement */
#define CS_INSTALLER                    0x0000008    /* has installer entitlement */

#define CS_HARD                         0x0000100    /* don't load invalid pages */
#define CS_KILL                         0x0000200    /* kill process if it becomes invalid */
#define CS_CHECK_EXPIRATION             0x0000400    /* force expiration checking */
#define CS_RESTRICT                     0x0000800    /* tell dyld to treat restricted */
#define CS_ENFORCEMENT                  0x0001000    /* require enforcement */
#define CS_REQUIRE_LV                   0x0002000    /* require library validation */
#define CS_ENTITLEMENTS_VALIDATED       0x0004000

#define CS_ALLOWED_MACHO                0x00ffffe

#define CS_EXEC_SET_HARD                0x0100000    /* set CS_HARD on any exec'ed process */
#define CS_EXEC_SET_KILL                0x0200000    /* set CS_KILL on any exec'ed process */
#define CS_EXEC_SET_ENFORCEMENT         0x0400000    /* set CS_ENFORCEMENT on any exec'ed process */
#define CS_EXEC_SET_INSTALLER           0x0800000    /* set CS_INSTALLER on any exec'ed process */

#define CS_KILLED                       0x1000000    /* was killed by kernel for invalidity */
#define CS_DYLD_PLATFORM                0x2000000    /* dyld used to load this is a platform binary */
#define CS_PLATFORM_BINARY              0x4000000    /* this is a platform binary */
#define CS_PLATFORM_PATH                0x8000000    /* platform binary by the fact of path (osx only) */

#define CS_DEBUGGED                     0x10000000  /* process is currently or has previously been debugged and allowed to run with invalid pages */
#define CS_SIGNED                       0x20000000  /* process has a signature (may have gone invalid) */
#define CS_DEV_CODE                     0x40000000  /* code is dev signed, cannot be loaded into prod signed code */

mach_port_t tfp0;
uint64_t kernel_base;
uint64_t kernel_slide;

uint64_t kernprocaddr;
uint64_t offset_zonemap;

uint64_t offset_proc_find;
uint64_t offset_proc_name;
uint64_t offset_proc_rele;

uint64_t find_port(mach_port_name_t port);

uint64_t proc_find(int pd);
char *proc_name(int pd);
void proc_release(uint64_t proc);

void platformize(int pd);
