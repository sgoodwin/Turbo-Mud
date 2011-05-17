//
//  Turbo_MudAppDelegate.m
//  Turbo Mud
//
//  Created by Samuel Goodwin on 5/15/11.
//  Copyright 2011 SNAP Interactive. All rights reserved.
//

#import "Turbo_MudAppDelegate.h"

@implementation Turbo_MudAppDelegate

@synthesize window;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification{
    __block int count = 0;
    
    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER,0, 0, dispatch_get_main_queue());
    if (timer){
        dispatch_source_set_timer(timer, dispatch_walltime(NULL, 0), 10000000000, 1);
        dispatch_source_set_event_handler(timer, ^{
            count++;
            NSLog(@"Tick %i, %@", count, [NSDate date]);
        });
        dispatch_resume(timer);
    }
}

@end
