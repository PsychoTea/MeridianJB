//
//  fuck-signing-services.m
//  Meridian
//
//  Created by Ben Sparkes on 07/01/2018.
//  Copyright © 2018 Ben Sparkes. All rights reserved.
//

#import "fucksigningservices.h"

@interface NSString (profileHelper)
- (id)dictionaryFromString;
@end

@implementation NSString (profileHelper)

// convert basic XML plist string from the profile and convert it into a mutable nsdictionary
- (id)dictionaryFromString
{
    NSData *theData = [self dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];
    id theDict = [NSPropertyListSerialization propertyListWithData:theData
                                                           options:NSPropertyListMutableContainersAndLeaves
                                                            format:nil
                                                             error:nil];
    return theDict;
}

@end

@implementation fucksigningservices : NSObject

// creds @nitoTV/lechium the fuckin' madman
// https://github.com/lechium/ProvisioningProfileCleaner/blob/master/ProvisioningProfileCleaner/KBProfileHelper.m#L648
+ (Boolean)appIsPirated:(NSString *)profilePath
{
    NSString *fileContents = [NSString stringWithContentsOfFile:profilePath
                                                       encoding:NSASCIIStringEncoding
                                                          error:nil];
    NSUInteger fileLength = [fileContents length];
    if (fileLength == 0)
    {
        fileContents = [NSString stringWithContentsOfFile:profilePath];
        fileLength = [fileContents length];
    }
    
    if (fileLength == 0) return false;
    
    // find NSRange location of <?xml to pass by all the "garbage" data before our plist
    NSUInteger startingLocation = [fileContents rangeOfString:@"<?xml"].location;
    // find NSRange of the end of the plist (there is "junk" cert data after our plist info as well
    NSRange endingRange = [fileContents rangeOfString:@"</plist>"];
    
    // adjust the location of endingRange to include </plist> into our newly trimmed string.
    NSUInteger endingLocation = endingRange.location + endingRange.length;
    
    // offset the ending location to trim out the "garbage" before <?xml
    NSUInteger endingLocationAdjusted = endingLocation - startingLocation;
    
    // create the final range of the string data from <?xml to </plist>
    NSRange plistRange = NSMakeRange(startingLocation, endingLocationAdjusted);
    
    NSString *plistString = [fileContents substringWithRange:plistRange];
    
    NSMutableDictionary *dict = [plistString dictionaryFromString];
    
    // Grab provisioning entries
    NSObject *provisionsAllDevices = [dict objectForKey:@"ProvisionsAllDevices"];
    NSArray *provisionedDevices = [dict objectForKey:@"ProvisionedDevices"];
    
    // Check whether keys are present & evaluate
    return (provisionsAllDevices != nil &&
            provisionedDevices == nil);
}

@end
