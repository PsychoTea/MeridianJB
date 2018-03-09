
/* Wait for xpcproxy to exec before continuing  */
/* Unused in Meridian                           */
#define FLAG_WAIT_EXEC   (1 << 5)
/* Wait for 0.5 sec after acting                */
/* Unused in Meridian                           */
#define FLAG_DELAY       (1 << 4)
/* Send SIGCONT after acting                    */
/* Unused in Meridian                           */
#define FLAG_SIGCONT     (1 << 3)
/* Set sandbox exception                        */
#define FLAG_SANDBOX     (1 << 2)
/* Set platform binary flag                     */
#define FLAG_PLATFORMIZE (1 << 1)
/* Set basic entitlements                       */
#define FLAG_ENTITLE     (1)

typedef void *jb_connection_t;

#if __BLOCKS__
/* Result: 1 = success, 0 = failure             */
typedef void (^jb_callback_t)(int result);
#endif

/*
    == Terminology ==
    'entitle'       = entilement functionality
    'fix_setuid'    = fix setuid for your binary
    'now'           = calls are blocking
    'oneshot'       = jb_connect/jb_disconnect is handled for you
 */

extern jb_connection_t  jb_connect                  (void);
extern void             jb_disconnect               (jb_connection_t connection);

#if __BLOCKS__
extern void             jb_entitle                  (jb_connection_t connection, pid_t pid, uint32_t flags, jb_callback_t callback);
extern void             jb_fix_setuid               (jb_connection_t connection, pid_t pid,                 jb_callback_t callback);
#endif

extern int              jb_entitle_now              (jb_connection_t connection, pid_t pid, uint32_t flags);
extern int              jb_fix_setuid_now           (jb_connection_t connection, pid_t pid);

#if __BLOCKS__
extern void             jb_oneshot_entitle          (pid_t pid, uint32_t flags, jb_callback_t callback);
extern void             jb_oneshot_fix_setuid       (pid_t pid,                 jb_callback_t callback);
#endif

extern int              jb_oneshot_entitle_now      (pid_t pid, uint32_t flags);
extern int              jb_oneshot_fix_setuid_now   (pid_t pid);
