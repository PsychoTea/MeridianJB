#include <mach/mach.h>

void remote_read_overwrite(mach_port_t task_port,
                           uint64_t remote_address,
                           uint64_t local_address,
                           uint64_t length);
void remote_write(mach_port_t remote_task_port,
                  uint64_t remote_address,
                  uint64_t local_address,
                  uint64_t length);
uint64_t binary_load_address();

uint64_t kalloc(vm_size_t size);
void kfree(mach_vm_address_t address, vm_size_t size);

size_t kread(uint64_t where, void *p, size_t size);
uint16_t rk16(uint64_t kaddr);
uint32_t rk32(uint64_t kaddr);
uint64_t rk64(uint64_t kaddr);

size_t kwrite(uint64_t where, const void *p, size_t size);
void wk16(uint64_t kaddr, uint16_t val);
void wk32(uint64_t kaddr, uint32_t val);
void wk64(uint64_t kaddr, uint64_t val);

uint64_t zm_fix_addr(uint64_t addr);

int kstrcmp(uint64_t kstr, const char* str);
