
#define DEBUGLOG(syslog, fmt, args ...)     \
    fprintf(stdout, fmt "\n", ##args);      \
    fflush(stdout);                         \
    if (syslog) NSLog(@fmt, ##args)

#define CACHED_FIND(type, name) \
    type __##name(void);                \
    type name(void) {                   \
        type cached = 0;                \
        if (cached == 0) {              \
            cached = __##name();        \
        }                               \
        return cached;                  \
    }                                   \
    type __##name(void)
