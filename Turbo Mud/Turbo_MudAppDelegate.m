//
//  Turbo_MudAppDelegate.m
//  Turbo Mud
//
//  Created by Samuel Goodwin on 5/15/11.
//  Copyright 2011 SNAP Interactive. All rights reserved.
//

#import "Turbo_MudAppDelegate.h"
#import <CoreServices/CoreServices.h>
#import "GOWriteDelegate.h"
#import "GOReadDelegate.h"

@implementation Turbo_MudAppDelegate

@synthesize window, readStream, writeStream, writeDelegate, readDelegate, inputBox;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification{
    self.writeDelegate = [[GOWriteDelegate alloc] init];
    self.readDelegate = [[GOReadDelegate alloc] init];
    
    //NSHost *host = [NSHost hostWithName:@"lusternia.com"];
    NSHost *host = [NSHost hostWithAddress:@"0.0.0.0"];
    NSInputStream *newRead = nil;
    NSOutputStream *newWrite = nil;
    [NSStream getStreamsToHost:host port:23 inputStream:&newRead outputStream:&newWrite];
    [newRead setDelegate:self.readDelegate];
    [newWrite setDelegate:self.writeDelegate];
    [newRead scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [newWrite scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [newRead open];
    [newWrite open];
    self.readStream = newRead;
    self.writeStream = newWrite;
}

- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)command{
    if(command == @selector(insertNewline:)){
        [self.writeDelegate write:[[textView textStorage] string]];
        [textView setString:@""];
    }else{
        return NO;
    }
    return YES;
}
@end
