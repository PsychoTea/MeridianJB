## Working with Meridian & libjailbreak

If your binary to tweak requires setuid0, or other entitlements/empowerments, you may need to make calls to Jailbreakd, which handles entitling of processes. This can be done via libjailbreak, a library bundled by default with Meridian.

### What do these empowerments include?
- Fixing setuid
- Modifying csflags
- Adding get-task-allow and skip-library-validation entitlements in the MACF label
- Breaking out of some sandbox restrictions
- Marking your binary as a 'platform binary'

### Usage

libjailbreak implements 2 calls which can be used to achieve this:
- `void jb_oneshot_fix_setuid_now(pid_t pid)` - for fixing setuid
- `void jb_oneshot_entitle_now(pid_t pid)` - for entitling

The pid (process ID) provided to each call can be your own, or can be that of another process.
Protip: you can find your own PID using the `getpid()` function.

**Note:** for the setuid call to work properly, your binary (or the process you're entitlting) must have the setuid flag set. You can set this with `chmod +s <filename>`.

### Examples

```c
void call_libjailbreak() {
    // open a handle to libjailbreak
    void *handle = dlopen("/usr/lib/libjailbreak.dylib", RTLD_LAZY);
    if (!handle) {
        printf("Err: %s \n", dlerror());
        printf("unable to find libjailbreak.dylib \n");
        return;
    }

    typedef void (*libjb_call_ptr_t)(pid_t pid);

    // grab pointers to the functions we want to call
    libjb_call_ptr_t setuid_ptr = (libjb_call_ptr_t)dlsym(handle, "jb_oneshot_fix_setuid_now");
    libjb_call_ptr_t entitle_ptr = (libjb_call_ptr_t)dlsym(handle, "jb_oneshot_entitle_now");

    // check for any errors
    const char *dlsym_error = dlerror();
    if (dlsym_error) {
        printf("encountered dlsym error: %s \n", dlsym_error);
        return;
    }

    // call them!
    setuid_ptr(getpid());
    entitle_ptr(getpid());
}
```

**Note:** libjailbreak calls are blocking, and code execution will not return until jailbreakd has fully processed your requests.

You can see a live action example of this in our cydo binary, here: https://github.com/MidnightTeam/cydo/blob/master/cydo.c#L6

