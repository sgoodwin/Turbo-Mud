//
//  Turbo_MudAppDelegate.h
//  Turbo Mud
//
//  Created by Samuel Goodwin on 5/15/11.
//  Copyright 2011 SNAP Interactive. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class GOWriteDelegate;
@class GOReadDelegate;
@interface Turbo_MudAppDelegate : NSObject <NSApplicationDelegate, NSStreamDelegate> {
@private
    NSWindow *window;
}

@property (strong) IBOutlet NSWindow *window;
@property (strong) IBOutlet NSTextField *inputBox;
@property (strong) NSInputStream *readStream;
@property (strong) NSOutputStream *writeStream;
@property (strong) GOWriteDelegate *writeDelegate;
@property (strong) GOReadDelegate *readDelegate;

void ReadStreamCallback(CFReadStreamRef stream, CFStreamEventType eventType, void *clientCallBackInfo);
@end
