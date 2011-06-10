//
//  GOWriteDelegate.h
//  Turbo Mud
//
//  Created by Samuel Goodwin on 6/9/11.
//  Copyright 2011 SNAP Interactive. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface GOWriteDelegate : NSObject<NSStreamDelegate>{
}
@property(strong) NSMutableArray *stringsToSend;
- (void)write:(NSString*)string;
@end