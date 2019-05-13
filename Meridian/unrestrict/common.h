#ifndef _UNRESTRICT_COMMON_H
#define _UNRESTRICT_COMMON_H

#include <stdio.h>
#include <stdbool.h>
#include <stdint.h>
#include <errno.h>
#include <sys/time.h>

extern bool initialized;
extern uint64_t offset_options;
#define OPT(x) (offset_options?((rk64(offset_options) & OPT_ ##x)?true:false):false)
#define SETOPT(x, val) (offset_options?wk64(offset_options, val?(rk64(offset_options) | OPT_ ##x):(rk64(offset_options) & ~OPT_ ##x)):0)
#define OPT_GET_TASK_ALLOW (1<<0)
#define OPT_CS_DEBUGGED (1<<1)

extern FILE *log_file;
struct timeval dl_tv;
#define LOG(fmt, args...) do {                                      \
    if (log_file == NULL) {                                         \
        char *log_path;                                             \
        if (asprintf(&log_path,                                     \
            "/var/log/unrestrict.log") == -1) {                     \
            break;                                                  \
        }                                                           \
        log_file = fopen(log_path, "a");                            \
        free(log_path);                                             \
        if (log_file == NULL) break;                                \
    }                                                               \
    gettimeofday(&dl_tv, NULL);                                     \
    fprintf(log_file, "[%ld.%06d] " fmt "\n", dl_tv.tv_sec,         \
            dl_tv.tv_usec, ##args);                                 \
    fflush(log_file);                                               \
} while(0)
#define CROAK(fmt, args...) LOG("%s:%d:%d:" fmt, __FILE__, __LINE__, errno, ##args)
//#ifdef DEBUG
#define DEBUGLOG(fmt, args...) LOG(fmt, ##args)
//#else
//#define DEBUGLOG(fmt, args...) do {} while (0)
//#endif // ifdef DEBUG

#define CACHED_FIND(type, name)         \
    type __##name(void);                \
    type name(void) {                   \
        type cached = 0;                \
        if (cached == 0) {              \
            cached = __##name();        \
        }                               \
        return cached;                  \
    }                                   \
    type __##name(void)

#endif
