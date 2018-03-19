//
//  jailbreak.h
//  Meridian
//
//  Created by Ben Sparkes on 16/02/2018.
//  Copyright © 2018 Ben Sparkes. All rights reserved.
//

#ifndef jailbreak_h
#define jailbreak_h

int makeShitHappen(id view);
int runV0rtex(void);
int patchContainermanagerd(void);
int remountRootFs(void);
int extractMeridianData(void);
void setUpSymLinks(void);
int extractBootstrap(void);
int launchDropbear(void);
void setUpSubstitute(void);
int startJailbreakd(void);
int loadLaunchDaemons(void);
void enableHiddenApps(void);

#endif /* jailbreak_h */
