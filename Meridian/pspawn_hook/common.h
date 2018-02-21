#ifndef PAYLOADS_COMMON_H
#define PAYLOADS_COMMON_H

#include <inttypes.h>

#define JAILBREAKD_CLOSE_CONNECTION 0

#define JAILBREAKD_COMMAND_ENTITLE 1
#define JAILBREAKD_COMMAND_ENTITLE_AND_SIGCONT 2
#define JAILBREAKD_COMMAND_ENTITLE_AND_SIGCONT_FROM_XPCPROXY 3
#define JAILBREAKD_COMMAND_FIXUP_SETUID 4

void calljailbreakd(pid_t pid, uint8_t command, int wait);
void closejailbreakfd(pid_t pid);

#endif

