//
//  Turbo_MudAppDelegate.h
//  Turbo Mud
//
//  Created by Samuel Goodwin on 5/15/11.
//  Copyright 2011 SNAP Interactive. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface Turbo_MudAppDelegate : NSObject <NSApplicationDelegate> {
@private
    NSWindow *window;
}

@property (assign) IBOutlet NSWindow *window;

@end
