//
//  NSArray+FIFO.m
//  Turbo Mud
//
//  Created by Samuel Goodwin on 5/22/11.
//  Copyright 2011 Goodwinlabs. All rights reserved.
//

#import "NSMutableArray+FIFO.h"

@implementation NSMutableArray (NSMutableArray_FIFO)

- (void)enqueue:(id)obj{
    [self insertObject:obj atIndex:[self count]];
}

- (id)dequeue{
    NSInteger count = [self count];
    if(count < 1){
        return nil;
    }
    
    id obj = [self objectAtIndex:0];
    [self removeObject:obj];
    return obj;
}

@end
