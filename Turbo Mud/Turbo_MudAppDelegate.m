//
//  Turbo_MudAppDelegate.m
//  Turbo Mud
//
//  Created by Samuel Goodwin on 5/15/11.
//  
//

#import "Turbo_MudAppDelegate.h"

#include <netinet/in.h>
#include <sys/socket.h>
#include "signal.h"
#include <netdb.h>
#include <errno.h>

#import "NSMutableArray+FIFO.h"
#import "NSString+ASCIIDebug.h"

const CGFloat kFontSize = 12.0f;
const unichar kIac = 255;
const unichar kDo = 253;
const unichar kDont = 254;


@interface Turbo_MudAppDelegate()
- (void)scrollToBottom:(id)sender;
- (NSAttributedString*)processIncomingStream:(NSString*)string withPreviousAttributes:(NSMutableDictionary **)previousAttributes;
- (id)attributeForCode:(NSInteger)code;
- (NSString*)attributeNameForCode:(NSInteger)code;
- (void)setupDefaults:(NSMutableDictionary*)dict overwrite:(BOOL)overwrite;

- (void)handleServerWill:(NSString*)phrase;

- (void)goAhead;
- (void)stopGoing;
@end

@implementation Turbo_MudAppDelegate

@synthesize window, textField, scrollView, inputQueue, writeSource;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification{
    self.inputQueue = [NSMutableArray arrayWithCapacity:2];
    
    int fd;
    struct addrinfo hints;
    struct addrinfo *result, *rp;
    
    memset(&hints, 0, sizeof(struct addrinfo));
    hints.ai_canonname = NULL;
    hints.ai_addr = NULL;
    hints.ai_next = NULL;
    hints.ai_family = AF_UNSPEC; // This says we don't care if it's ipv4 or ipv6
    hints.ai_socktype = SOCK_STREAM;
    hints.ai_flags = AI_CANONNAME;
    if(getaddrinfo("lusternia.com", "23", &hints, &result) != 0){
        NSLog(@"Getaddrinfo failed: %s", strerror(errno));
    }
    
    for(rp = result; rp != NULL;rp = rp->ai_next){
        fd = socket(rp->ai_family, rp->ai_socktype, rp->ai_protocol);
        if(fd == -1){
            continue;
        }        
        if(connect(fd, rp->ai_addr, rp->ai_addrlen) != -1){
            /*int flags = fcntl(fd, F_GETFL, 0);
            fcntl(fd, F_SETFL, flags | O_NONBLOCK);*/
            break;
        }
        close(fd);
    }
    
    if(rp == NULL){
        NSLog(@"Could not connect on any address :(");
        freeaddrinfo(result);
        return;
    }
    
    dispatch_queue_t writeQueue = dispatch_queue_create("com.goodwinlabs.writing", NULL);
    self.writeSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_WRITE, fd, 0, writeQueue);
    dispatch_source_set_event_handler(writeSource, ^{
        NSString *nextInputLine = [self.inputQueue dequeue];
        if(!nextInputLine){
            return;
        }
        size_t numberOfBytesToWrite = [nextInputLine length];
        //const char *bytesToWrite = [[nextInputLine stringByAppendingString:@"\r\n"] cStringUsingEncoding:NSASCIIStringEncoding];
        const char *bytesToWrite = [nextInputLine cStringUsingEncoding:NSASCIIStringEncoding];
        size_t numberOfBytesActuallyWritten = write(fd, bytesToWrite, numberOfBytesToWrite);
        if(numberOfBytesActuallyWritten <= 0){
            NSLog(@"There was some failure writing %@, %zu bytes were written, %s", nextInputLine, numberOfBytesActuallyWritten, strerror(errno));
        }
    });
    dispatch_source_set_cancel_handler(writeSource, ^{
        NSLog(@"Cancelling Writing handler");
        close(fd);
    });
    
    dispatch_queue_t readQueue = dispatch_queue_create("com.goodwinlabs.reading", NULL);
    NSLog(@"Setting up source and handlers...");
    dispatch_source_t readSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, fd, 0, readQueue);
    dispatch_source_set_event_handler(readSource, ^{
        unsigned long estimatedBytesAvailable = dispatch_source_get_data(readSource);
        char buffer[estimatedBytesAvailable];
        ssize_t bytesRead = read(fd, buffer, estimatedBytesAvailable);
        if(bytesRead < 0){
            NSLog(@"Failed to read :( %s", strerror(errno));
        }
        
        NSString *results = [NSString stringWithCString:buffer encoding:NSASCIIStringEncoding];
        NSArray *lines = [results componentsSeparatedByString:@"\r\n"];
        NSMutableDictionary *previousAttributes = [NSMutableDictionary dictionaryWithCapacity:3];
        for(NSString *line in lines){
            NSLog(@"recv %@", line);
            NSAttributedString *processedLine = [self processIncomingStream:line withPreviousAttributes:&previousAttributes];
            if(processedLine && [processedLine length] > 0){
                dispatch_async(dispatch_get_main_queue(), ^(void) {
                    [[self.textField textStorage] appendAttributedString:processedLine];
                    [self scrollToBottom:nil];
                });
            }
        }

    });
    dispatch_source_set_cancel_handler(readSource, ^{ 
        NSLog(@"Cancelling Reading handler");
        close(fd); 
    });
    dispatch_resume(readSource);
}

- (void)goAhead{
    dispatch_resume(self.writeSource);
}

- (void)stopGoing{
    dispatch_suspend(self.writeSource);
}


- (IBAction)enterKey:(id)sender{
    if([sender stringValue] && [[sender stringValue] length]){
        [self.inputQueue enqueue:[sender stringValue]];
        [sender setStringValue:@""];
    }
}

- (NSAttributedString*)processIncomingStream:(NSString*)string withPreviousAttributes:(NSMutableDictionary **)previousAttributes{   
    Turbo_MudAppDelegate *weakSelf = self;
    [self setupDefaults:*previousAttributes overwrite:NO];
    if([string length] == 0){
        NSMutableAttributedString *attributedResult = [[NSMutableAttributedString alloc] init];
        [attributedResult addAttributes:*previousAttributes range:NSMakeRange(0, [string length])];
        return [attributedResult autorelease];
    }
    
    NSError *error = nil;
    NSRegularExpression *serverCommandRegex = [NSRegularExpression regularExpressionWithPattern:@"\\xFF(..?)" options:NSRegularExpressionUseUnixLineSeparators error:&error];
    if(error){
        NSLog(@"error: %@", [error localizedDescription]);
    }
    [serverCommandRegex enumerateMatchesInString:string options:NSMatchingReportProgress range:NSMakeRange(0, [string length]) usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
        if(!result){
            return;
        }
        NSRange rangeToHandle = NSMakeRange([result rangeAtIndex:1].location-1, [result rangeAtIndex:1].length+1);
        NSString *subString = [string substringWithRange:rangeToHandle];
        NSLog(@"%@", [subString charCodeString]);
        unichar commandLetter = [subString characterAtIndex:1];
        switch(commandLetter){
            case 249:
                [weakSelf goAhead];
                break;
            case 251:
                NSLog(@"will");
                [weakSelf handleServerWill:subString];
                break;
            case 252:
                NSLog(@"won't");
                break;
            case 253:
                NSLog(@"do");
                break;
            case 254:
                NSLog(@"dont'");
                break;
        }
    }];
    NSString *commandStrippedString = [serverCommandRegex stringByReplacingMatchesInString:string options:NSRegularExpressionUseUnixLineSeparators range:NSMakeRange(0,[string length]) withTemplate:@""];
    
    
    error = nil;
    NSRegularExpression *colorRegex = [NSRegularExpression regularExpressionWithPattern:@"\\e.(\\d{1,1};)??(\\d{1,2}m)" options:NSRegularExpressionUseUnixLineSeparators error:&error];
    if(error){
        NSLog(@"error: %@", [error localizedDescription]);
    }
    NSArray *matches = [colorRegex matchesInString:commandStrippedString options:NSMatchingReportProgress range:NSMakeRange(0, [commandStrippedString length])];
    NSString *colorStrippedString = [colorRegex stringByReplacingMatchesInString:commandStrippedString options:NSRegularExpressionUseUnixLineSeparators range:NSMakeRange(0,[commandStrippedString length]) withTemplate:@""];
    NSMutableAttributedString *attributedResult = [[NSMutableAttributedString alloc] initWithString:[colorStrippedString stringByAppendingString:@"\r\n"]];
    [attributedResult addAttributes:*previousAttributes range:NSMakeRange(0, [colorStrippedString length])];
    
    NSInteger offset = 2;
    for(int i=0;i<[matches count];i++){
        NSTextCheckingResult *result = [matches objectAtIndex:i];
        NSRange firstRange = [result rangeAtIndex:1];
        if(firstRange.location != NSNotFound){
            NSString *firstString = [commandStrippedString substringWithRange:firstRange];
            firstRange.location = firstRange.location - offset;
            NSInteger code = [firstString integerValue];
            if(code == 0){
                [self setupDefaults:*previousAttributes overwrite:YES];
            }else{
                [*previousAttributes setObject:[self attributeForCode:code] forKey:[self attributeNameForCode:code]];
            }
            [attributedResult addAttributes:*previousAttributes range:NSMakeRange(firstRange.location,[attributedResult length]-firstRange.location)];
            offset+=2;
        }
        NSRange secondRange = [result rangeAtIndex:2];
        if(secondRange.location != NSNotFound){
            NSString *secondString = [commandStrippedString substringWithRange:secondRange];
            secondRange.location = secondRange.location - offset;
            NSInteger code = [secondString integerValue];
            if(code == 0){
                [self setupDefaults:*previousAttributes overwrite:YES];
            }else{
                [*previousAttributes setObject:[self attributeForCode:code] forKey:[self attributeNameForCode:code]];
            }
            [attributedResult addAttributes:*previousAttributes range:NSMakeRange(secondRange.location,[attributedResult length]-secondRange.location)];
            offset+=5;
        }
    }
    return [attributedResult autorelease];
}

- (void)setupDefaults:(NSMutableDictionary*)dict overwrite:(BOOL)overwrite{
    // Setup defaults...
    if(nil == [dict objectForKey:NSForegroundColorAttributeName] || overwrite){
        [dict setObject:[NSColor whiteColor] forKey:NSForegroundColorAttributeName];
    }
    if(nil == [dict objectForKey:NSBackgroundColorAttributeName] || overwrite){
        [dict setObject:[NSColor blackColor] forKey:NSBackgroundColorAttributeName];
    }
    if(nil == [dict objectForKey:NSFontAttributeName] || overwrite){
        [dict setObject:[NSFont fontWithName:@"Menlo" size:kFontSize] forKey:NSFontAttributeName];
    }
}

- (void)scrollToBottom:(id)sender{
    NSPoint newScrollOrigin;
    
    // assume that the scrollview is an existing variable
    if ([[self.scrollView documentView] isFlipped]) {
        newScrollOrigin=NSMakePoint(0.0,NSMaxY([[self.scrollView documentView] frame])-NSHeight([[self.scrollView contentView] bounds]));
    } else {
        newScrollOrigin=NSMakePoint(0.0,0.0);
    }
    [[self.scrollView documentView] scrollPoint:newScrollOrigin];
    
}


/* color codes taken from http://pueblo.sourceforge.net/doc/manual/ansi_color_codes.html */
- (NSString*)attributeNameForCode:(NSInteger)code{
    if(code == 1){
        return NSFontAttributeName;
    }
    if(code >= 2 && code <=29){
        return nil;
    }
    if(code >= 30 && code <= 39){
        return NSForegroundColorAttributeName;
    }
    return NSBackgroundColorAttributeName;
}

- (id)attributeForCode:(NSInteger)code{
    switch(code){
        case 1:
            return [NSFont fontWithName:@"Menlo Bold" size:kFontSize];
        case 30:
            return [NSColor blackColor];
            break;
        case 31:
            return [NSColor redColor];
            break;
        case 32:
            return [NSColor greenColor];
            break;
        case 33:
            return [NSColor yellowColor];
            break;
        case 34:
            return [NSColor blueColor];
            break;
        case 35:
            return [NSColor magentaColor];
            break;
        case 36:
            return [NSColor cyanColor];
            break;
        case 37:
            return [NSColor whiteColor];
            break;
        case 39:
            return [NSColor whiteColor];
            break;
        default:
            return [NSColor whiteColor];
            break;
    }
}

- (void)handleServerWill:(NSString*)phrase{
    unichar optionChar = [phrase characterAtIndex:2];
    NSString *response = nil;
    switch(optionChar){
        case 25:
            NSLog(@"end of record");
            unichar eor[3] = {kIac,kDo,25};
            response = [NSString stringWithCharacters:eor length:3];
            break;
        case 86:
            NSLog(@"mccp2");
            unichar nomccp2[3] = {kIac,kDont,86};
            response = [NSString stringWithCharacters:nomccp2 length:3];
            break;
        case 200:
            NSLog(@"atcp");
            unichar noatcp[3] = {kIac,kDont,200};
            response = [NSString stringWithCharacters:noatcp length:3];
            break;
        case 201:
            NSLog(@"gmcp aka atcp2");
            unichar noatcp2[3] = {kIac,kDont,201};
            response = [NSString stringWithCharacters:noatcp2 length:3];
            break;
    }
    [self.inputQueue enqueue:response];
}
@end
