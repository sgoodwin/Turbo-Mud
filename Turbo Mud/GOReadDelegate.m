//
//  GOReadDelegate.m
//  Turbo Mud
//
//  Created by Samuel Goodwin on 6/9/11.
//  Copyright 2011 SNAP Interactive. All rights reserved.
//

#import "GOReadDelegate.h"

#define kByteBufferSize 512

@implementation GOReadDelegate
- (NSMutableData *)data{
    if(_data){
        return _data;
    }
    _data = [[NSMutableData alloc] init];
    return _data;
}

- (void)stream:(NSStream *)theStream handleEvent:(NSStreamEvent)streamEvent{
    NSLog(@"Delegate method executing for reading");
    NSInputStream *inputStream = (NSInputStream*)theStream;
    NSInteger result = 0;
    NSUInteger length = kByteBufferSize;
    uint8_t buffer[length];
    memset(buffer, 0, length);
    switch(streamEvent) {
        case NSStreamEventHasBytesAvailable:
            result = [inputStream read:buffer maxLength:length];
            NSLog(@"%@ has %ld bytes available to read", theStream, result);
            if(result > 0){
                [self.data appendBytes:buffer length:length];                
                NSString *resultString = [[NSString alloc] initWithData:self.data encoding:NSASCIIStringEncoding];
                //NSLog(@"resultS: %@", [self charCodeString:resultString]);
                NSLog(@"Results: %@", resultString);
            }
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
    }
}

- (NSString*)charCodeString:(NSString*)orignal{
    NSMutableString *toBeReturned = [NSMutableString stringWithCapacity:[orignal length]*3];
    [toBeReturned appendFormat:@"%i", [orignal characterAtIndex:0]];
    for(int i=1;i<[orignal length];i++){
        [toBeReturned appendFormat:@" %i", [orignal characterAtIndex:i]];
    }
    return toBeReturned;
}



@end
