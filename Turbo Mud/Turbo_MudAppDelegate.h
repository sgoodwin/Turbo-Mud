//
//  Turbo_MudAppDelegate.h
//  Turbo Mud
//
//  Created by Samuel Goodwin on 5/15/11.
//  
//

#import <Cocoa/Cocoa.h>

@interface Turbo_MudAppDelegate : NSObject <NSApplicationDelegate, NSTextFieldDelegate, NSTextViewDelegate> {
@private
    NSWindow *window;
    NSTextView *textField;
    NSScrollView *scrollView;
    
    NSMutableArray *inputQueue;
}

@property (assign) IBOutlet NSWindow *window;
@property (assign) IBOutlet NSTextView *textField;
@property (assign) IBOutlet NSScrollView *scrollView;
@property (retain) NSMutableArray *inputQueue;

- (IBAction)enterKey:(id)sender;
@end
