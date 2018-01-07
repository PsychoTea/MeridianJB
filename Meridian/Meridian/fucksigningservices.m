//
//  fuck-signing-services.m
//  Meridian
//
//  Created by Ben Sparkes on 07/01/2018.
//  Copyright © 2018 Ben Sparkes. All rights reserved.
//

#import <Foundation/Foundation.h>

@class fucksigningservices_class;

@implementation fucksigningservices : fucksigningservices_class

+ (NSMutableDictionary *)provisioningDictionaryFromFilePath:(NSString *)profilePath
{
    NSString *fileContents = [NSString stringWithContentsOfFile:profilePath encoding:NSASCIIStringEncoding error:nil];
    NSUInteger fileLength = [fileContents length];
    if (fileLength == 0)
        fileContents = [NSString stringWithContentsOfFile:profilePath]; //if ascii doesnt work, have to use the deprecated (thankfully not obsolete!) method
        
        fileLength = [fileContents length];
        if (fileLength == 0)
            return nil;
    
    //find NSRange location of <?xml to pass by all the "garbage" data before our plist
    
    NSUInteger startingLocation = [fileContents rangeOfString:@"<?xml"].location;
    
    //find NSRange of the end of the plist (there is "junk" cert data after our plist info as well
    NSRange endingRange = [fileContents rangeOfString:@"</plist>"];
    
    //adjust the location of endingRange to include </plist> into our newly trimmed string.
    NSUInteger endingLocation = endingRange.location + endingRange.length;
    
    //offset the ending location to trim out the "garbage" before <?xml
    NSUInteger endingLocationAdjusted = endingLocation - startingLocation;
    
    //create the final range of the string data from <?xml to </plist>
    
    NSRange plistRange = NSMakeRange(startingLocation, endingLocationAdjusted);
    
    //actually create our string!
    NSString *plistString = [fileContents substringWithRange:plistRange];
    
    //yay categories!! convert the dictionary raw string into an actual NSDictionary
    NSMutableDictionary *dict = [plistString dictionaryFromString];
    
    
    NSString *appID = [dict[@"Entitlements"] objectForKey:@"application-identifier"];
    
    [dict setObject:appID forKey:@"applicationIdentifier"];
    
    //since we will always need this data, best to grab it here and make it part of the dictionary for easy re-use / validity check.
    
    NSString *ourID = [self validIDFromCerts:dict[@"DeveloperCertificates"]];
    
    if (ourID != nil)
    {
        [dict setValue:ourID forKey:@"CODE_SIGN_IDENTITY"];
        //in THEORY should set the profile target to Debug or Release depending on if it finds "Developer:" string.
        if ([ourID rangeOfString:@"Developer:"].location != NSNotFound)
        {
            [dict setValue:@"Debug" forKey:@"Target"];
            
        } else {
            
            [dict setValue:@"Release" forKey:@"Target"];
        }
    }
    
    //grab all the valid certs, for later logging / debugging for why a profile might be invalid
    
    NSArray *validCertIds = [self certIDsFromCerts:dict[@"DeveloperCertificates"]];
    
    [dict setValue:validCertIds forKey:@"CodeSignArray"];
    
    // shouldnt need this frivolous data any longer, we know which ID (if any) we have and have all the valid ones too
    
    [dict removeObjectForKey:@"DeveloperCertificates"];
    
    
    
    //write to file for debug / posterity
    // [dict writeToFile:[[[self pwd] stringByAppendingPathComponent:dict[@"Name"]] stringByAppendingPathExtension:@"plist"] atomically:TRUE];
    
    return dict;
}

@end
