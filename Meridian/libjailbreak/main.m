#include <unistd.h>
#include <mach/mach.h>
#include "mach/jailbreak_daemonUser.h"

#define JAILBREAKD_COMMAND_ENTITLE 1
#define JAILBREAKD_COMMAND_ENTITLE_AND_SIGCONT 2
#define JAILBREAKD_COMMAND_ENTITLE_AND_SIGCONT_FROM_XPCPROXY 3
#define JAILBREAKD_COMMAND_FIXUP_SETUID 4

kern_return_t bootstrap_look_up(mach_port_t port, const char *service, mach_port_t *server_port);

mach_port_t jbd_port = MACH_PORT_NULL;

int jbd_connect() {
    if (bootstrap_look_up(bootstrap_port, "zone.sparkes.jailbreakd", &jbd_port)) {
        // failed :(
        return 1;
    }
    
    return 0;
}

void jb_oneshot_entitle_now(pid_t pid) {
    if (jbd_port == MACH_PORT_NULL) {
        int ret = jbd_connect();
        if (ret != 0) return;
    }
    
    jbd_call(jbd_port, JAILBREAKD_COMMAND_ENTITLE, pid);
}

void jb_oneshot_fix_setuid_now(pid_t pid) {
    if (jbd_port == MACH_PORT_NULL) {
        int ret = jbd_connect();
        if (ret != 0) return;
    }
    
    jbd_call(jbd_port, JAILBREAKD_COMMAND_FIXUP_SETUID, pid);
}
