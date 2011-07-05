//
//  NSArray+FIFO.h
//  Turbo Mud
//
//  Created by Samuel Goodwin on 5/22/11.
//  Copyright 2011 Goodwinlabs. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSMutableArray (NSMutableArray_FIFO)
- (void)enqueue:(id)obj;
- (id)dequeue;
@end
