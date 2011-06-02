//
//  NSString+ASCIIDebug.m
//  Turbo Mud
//
//  Created by Samuel Goodwin on 5/28/11.
//  Copyright 2011 SNAP Interactive. All rights reserved.
//

#import "NSString+ASCIIDebug.h"

@implementation NSString (NSString_ASCIIDebug)
- (NSString*)charCodeString{
    NSMutableString *toBeReturned = [NSMutableString stringWithCapacity:[self length]*3];
    for(int i=0;i<[self length];i++){
        [toBeReturned appendFormat:@" %i", [self characterAtIndex:i]];
    }
    return toBeReturned;
}
@end
