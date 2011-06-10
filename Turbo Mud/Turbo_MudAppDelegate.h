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
    NSMutableArray *inputQueue;
}

@property (weak) IBOutlet NSWindow *window;
@property (weak) IBOutlet NSTextView *textField;
@property (weak) IBOutlet NSScrollView *scrollView;
@property (strong) NSMutableArray *inputQueue;
@property (strong) NSMutableDictionary *previousAttributes;

- (IBAction)enterKey:(id)sender;
- (NSAttributedString*)processIncomingStream:(NSString*)string withPreviousAttributes:(NSMutableDictionary **)previousAttributes;
- (void)setupDefaults:(NSMutableDictionary*)dict overwrite:(BOOL)overwrite;
- (NSString*)attributeNameForCode:(NSInteger)code;
- (id)attributeForCode:(NSInteger)code;
@end
