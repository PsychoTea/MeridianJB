//
//  Preferences.m
//  Meridian
//
//  Created by Ben Sparkes on 28/07/2018.
//

#import <Foundation/Foundation.h>
#import "preferences.h"

#define TweaksKey               @"tweaksAreEnabled"
#define StartLaunchDaemonsKey   @"startLaunchDaemonsEnabled"
#define StartDropbearKey        @"startDropbearEnabled"
#define PortKey                 @"listenPortOption"

void setTweaksEnabled(BOOL enabled) {
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:TweaksKey];
}

BOOL tweaksAreEnabled() {
    NSNumber *enabled = [[NSUserDefaults standardUserDefaults] objectForKey:TweaksKey];
    
    return (enabled) ? [enabled boolValue] : true;
}

void setStartLaunchDaemonsEnabled(BOOL enabled) {
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:StartLaunchDaemonsKey];
}

BOOL startLaunchDaemonsIsEnabled() {
    NSNumber *enabled = [[NSUserDefaults standardUserDefaults] objectForKey:StartLaunchDaemonsKey];
    
    return (enabled) ? [enabled boolValue] : true;
}

void setStartDropbearEnabled(BOOL enabled) {
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:StartDropbearKey];
}

BOOL startDropbearIsEnabled() {
    NSNumber *enabled = [[NSUserDefaults standardUserDefaults] objectForKey:StartDropbearKey];
    
    return (enabled) ? [enabled boolValue] : false;
}

void setListenPort(NSInteger portOption) {
    [[NSUserDefaults standardUserDefaults] setInteger:portOption forKey:PortKey];
}

NSInteger listenPort(void) {
    NSNumber *portOption = [[NSUserDefaults standardUserDefaults] objectForKey:PortKey];
    
    return (portOption) ? portOption.integerValue : Port222222;
}
