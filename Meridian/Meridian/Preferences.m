//
//  Preferences.m
//  Meridian
//
//  Created by Ben Sparkes on 28/07/2018.
//

#import <Foundation/Foundation.h>
#import "Preferences.h"

#define TweaksKey @"tweaksAreEnabled"
#define StartLaunchDaemonsKey @"startLaunchDaemonsEnabled"
#define StartDropbearKey @"startDropbearEnabled"
#define PortKey @"listenPortOption"

void setTweaksEnabled(BOOL enabled)
{
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:TweaksKey];
}

BOOL tweaksAreEnabled(void)
{
    NSNumber *enabled = [[NSUserDefaults standardUserDefaults] objectForKey:TweaksKey];
    if (enabled)
        return [enabled boolValue];
    return true;
}

void setStartLaunchDaemonsEnabled(BOOL enabled)
{
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:StartLaunchDaemonsKey];
}

BOOL startLaunchDaemonsIsEnabled(void)
{
    NSNumber *enabled = [[NSUserDefaults standardUserDefaults] objectForKey:StartLaunchDaemonsKey];
    if (enabled)
        return [enabled boolValue];
    return true;
}

void setStartDropbearEnabled(BOOL enabled)
{
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:StartDropbearKey];
}

BOOL startDropbearIsEnabled(void)
{
    NSNumber *enabled = [[NSUserDefaults standardUserDefaults] objectForKey:StartDropbearKey];
    if (enabled)
        return [enabled boolValue];
    return true;
}

void setListenPort(NSInteger portOption)
{
    [[NSUserDefaults standardUserDefaults] setInteger:portOption forKey:PortKey];
}

NSInteger listenPort(void)
{
    NSNumber *portOption = [[NSUserDefaults standardUserDefaults] objectForKey:PortKey];
    if (portOption)
        return portOption.integerValue;
    
    return Port222222;
}
