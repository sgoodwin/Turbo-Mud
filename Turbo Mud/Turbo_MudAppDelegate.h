//
//  Turbo_MudAppDelegate.h
//  Turbo Mud
//
//  Created by Samuel Goodwin on 5/15/11.
//  
//

#import <Cocoa/Cocoa.h>

@interface Turbo_MudAppDelegate : NSObject <NSApplicationDelegate> {
@private
    NSWindow *window;
    NSTextField *textField;
}

@property (assign) IBOutlet NSWindow *window;
@property (assign) IBOutlet NSTextField *textField;
@end
