//
//  Preferences.h
//  Meridian
//
//  Created by Ben Sparkes on 28/07/2018.
//

#ifndef Preferences_h
#define Preferences_h

enum {
    Port22 = 0,
    Port2222,
    Port222222
};

void setTweaksEnabled(BOOL enabled);
BOOL tweaksAreEnabled(void);
void setStartLaunchDaemonsEnabled(BOOL enabled);
BOOL startLaunchDaemonsIsEnabled(void);
void setBootNonceValue(uint64_t bootNonce);
uint64_t getBootNonceValue(void);
void setStartDropbearEnabled(BOOL enabled);
BOOL startDropbearIsEnabled(void);
void setListenPort(NSInteger portOption);
NSInteger listenPort(void);

#endif /* Preferences_h */
