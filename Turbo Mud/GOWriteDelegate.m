//
//  GOWriteDelegate.m
//  Turbo Mud
//
//  Created by Samuel Goodwin on 6/9/11.
//  Copyright 2011 SNAP Interactive. All rights reserved.
//

#import "GOWriteDelegate.h"

@implementation GOWriteDelegate
@synthesize stringsToSend;

- (id)init{
    if((self = [super init])){
        self.stringsToSend = [[NSMutableArray alloc] initWithCapacity:2];
    }
    return self;
}

- (void)stream:(NSStream *)theStream handleEvent:(NSStreamEvent)streamEvent{
    NSLog(@"delegate method executed for writing");
    NSOutputStream *outputStream = (NSOutputStream*)theStream;
    NSString *nextString = nil;
    if([self.stringsToSend count] > 0){
        nextString = [self.stringsToSend objectAtIndex:0];
    }
    switch(streamEvent) {
        case NSStreamEventHasSpaceAvailable:
            NSLog(@"Write has space available");
            if(!nextString){
                return;
            }
            NSInteger count = [outputStream write:(const uint8_t*)[nextString UTF8String] maxLength:[nextString length]];
            NSLog(@"Wrote %ld bytes of %@", count, nextString);
            break;
        case NSStreamEventErrorOccurred:
            NSLog(@"Event error occured");
            break;
        case NSStreamEventEndEncountered:
            NSLog(@"End encountered");
            [theStream close];
            [theStream removeFromRunLoop:[NSRunLoop currentRunLoop]
                                 forMode:NSDefaultRunLoopMode];
            break;
        case NSStreamEventOpenCompleted:
            NSLog(@"open completed");
            break;
        case NSStreamEventNone:
            NSLog(@"no event");
            break;
    }
}

- (void)write:(NSString*)string{
    [[self stringsToSend] addObject:string];
    NSLog(@"strings: %@", [self stringsToSend]);
}
@end
