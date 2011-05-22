//
//  Turbo_MudAppDelegate.h
//  Turbo Mud
//
//  Created by Samuel Goodwin on 5/15/11.
//  
//

#import <Cocoa/Cocoa.h>

@interface Turbo_MudAppDelegate : NSObject <NSApplicationDelegate, NSTextFieldDelegate> {
@private
    NSWindow *window;
    NSTextField *textField;
    
    NSMutableArray *inputQueue;
}

@property (assign) IBOutlet NSWindow *window;
@property (assign) IBOutlet NSTextField *textField;
@property (retain) NSMutableArray *inputQueue;

- (IBAction)enterKey:(id)sender;
@end
