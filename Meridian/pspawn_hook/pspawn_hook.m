#import <Foundation/Foundation.h>

__attribute__ ((constructor))
static void ctor(void) {
    NSLog(@"[pspawn_hook] the hook payload is here: %d", getpid());
}
