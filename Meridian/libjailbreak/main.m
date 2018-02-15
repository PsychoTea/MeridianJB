#include <unistd.h>
#include "common.h"

void jb_oneshot_entitle(pid_t pid) {
    calljailbreakd(pid, JAILBREAKD_COMMAND_ENTITLE, 0);
    closejailbreakfd();
}

void jb_oneshot_fix_setuid(pid_t pid) {
    calljailbreakd(pid, JAILBREAKD_COMMAND_FIXUP_SETUID, 0);
    closejailbreakfd();
}

void jb_oneshot_entitle_now(pid_t pid) {
    calljailbreakd(pid, JAILBREAKD_COMMAND_ENTITLE, 1);
    closejailbreakfd();
}

void jb_oneshot_fix_setuid_now(pid_t pid) {
    calljailbreakd(pid, JAILBREAKD_COMMAND_FIXUP_SETUID, 1);
    closejailbreakfd();
}
