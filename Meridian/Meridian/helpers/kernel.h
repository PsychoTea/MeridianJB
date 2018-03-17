//
//  kernel.h
//  Meridian
//
//  Created by Ben Sparkes on 16/12/2017.
//  Copyright © 2017 Ben Sparkes. All rights reserved.
//

#include <mach/mach.h>

kern_return_t mach_vm_write(vm_map_t target_task,
                            mach_vm_address_t address,
                            vm_offset_t data,
                            mach_msg_type_number_t dataCnt);

kern_return_t mach_vm_read_overwrite(vm_map_t target_task,
                                     mach_vm_address_t address,
                                     mach_vm_size_t size,
                                     mach_vm_address_t data,
                                     mach_vm_size_t *outsize);

kern_return_t mach_vm_allocate(vm_map_t,
                               mach_vm_address_t *,
                               mach_vm_size_t, int);

kern_return_t mach_vm_deallocate(vm_map_t target,
                                 mach_vm_address_t address,
                                 mach_vm_size_t size);

kern_return_t mach_vm_region(vm_map_t target_task,
                             mach_vm_address_t *address,
                             mach_vm_size_t *size,
                             vm_region_flavor_t flavor,
                             vm_region_info_t info,
                             mach_msg_type_number_t *infoCnt,
                             mach_port_t *object_name);

kern_return_t bootstrap_look_up(mach_port_t port, const char *service, mach_port_t *server_port);

void init_kernel(task_t tfp0);
size_t tfp0_kread(uint64_t where, void *p, size_t size);
uint64_t rk64(uint64_t kaddr);
uint32_t rk32(uint64_t kaddr);
void wk64(uint64_t kaddr, uint64_t val);
void wk32(uint64_t kaddr, uint32_t val);
size_t kwrite(uint64_t where, const void *p, size_t size);
size_t kwrite_uint64(uint64_t where, uint64_t value);
uint64_t remote_alloc(mach_port_t task_port, uint64_t size);
uint64_t alloc_and_fill_remote_buffer(mach_port_t task_port,
                                      uint64_t local_address,
                                      uint64_t length);
void remote_free(mach_port_t task_port, uint64_t base, uint64_t size);
void remote_read_overwrite(mach_port_t task_port,
                           uint64_t remote_address,
                           uint64_t local_address,
                           uint64_t length);
uint64_t binary_load_address(mach_port_t tp);
uint64_t ktask_self_addr(void);
mach_port_t task_for_pid_workaround(int pid);
uint64_t find_port_address(mach_port_name_t port);