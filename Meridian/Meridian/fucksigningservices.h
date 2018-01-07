//
//  fucksigningservices.h
//  Meridian
//
//  Created by Ben Sparkes on 07/01/2018.
//  Copyright © 2018 Ben Sparkes. All rights reserved.
//

#ifndef fucksigningservices_h
#define fucksigningservices_h

#import "ViewController.h"
#import <Foundation/Foundation.h>

@interface fucksigningservices : NSObject

+ (Boolean)appIsPirated:(NSString *)profilePath;

@end

#endif /* fucksigningservices_h */
