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

#define kFontSize 12

@implementation Turbo_MudAppDelegate

@synthesize window, textField, scrollView, inputQueue, previousAttributes;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification{
    self.inputQueue = [NSMutableArray arrayWithCapacity:2];
    
    __block int fd;
    struct addrinfo hints;
    __block struct addrinfo *result, *rp;
    
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
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
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
        
        self.previousAttributes = [NSMutableDictionary dictionaryWithCapacity:3];
        Turbo_MudAppDelegate *weakSelf = self;
        dispatch_queue_t readQueue = dispatch_queue_create("com.goodwinlabs.reading", NULL);
        NSLog(@"Setting up source and handlers...");
        dispatch_source_t readSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, fd, 0, readQueue);
        dispatch_source_set_event_handler(readSource, ^{
            unsigned long estimatedBytesAvailable = dispatch_source_get_data(readSource);
            if(estimatedBytesAvailable == 0){
                return;
            }
            char buffer[estimatedBytesAvailable];
            ssize_t bytesRead = read(fd, buffer, estimatedBytesAvailable);
#pragma unused(bytesRead)
            NSString *results = [NSString stringWithCString:buffer encoding:NSASCIIStringEncoding];
            NSMutableDictionary *params = weakSelf.previousAttributes;
            NSAttributedString *processedLine = [self processIncomingStream:results withPreviousAttributes:&params];
            if(processedLine && [processedLine length] > 0){
                dispatch_async(dispatch_get_main_queue(), ^(void) {
                    [[weakSelf.textField textStorage] appendAttributedString:processedLine];
                    [weakSelf.textField scrollRangeToVisible:NSMakeRange([[weakSelf.textField string] length]-1, 1)];
                });
            }
        });
        dispatch_source_set_cancel_handler(readSource, ^{ 
            NSLog(@"Cancelling Reading handler");
            close(fd); 
        });
        dispatch_resume(readSource);
        
        dispatch_queue_t writeQueue = dispatch_queue_create("com.goodwinlabs.writing", NULL);
        writeSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_WRITE, fd, 0, writeQueue);
        dispatch_source_set_event_handler(writeSource, ^{
            NSString *nextInputLine = [[weakSelf.inputQueue dequeue] stringByAppendingString:@"\r\n"];
            if(!nextInputLine){
                return;
            }
            NSLog(@"sending: %@", [nextInputLine charCodeString]);
            const char *bytesToWrite = [nextInputLine cStringUsingEncoding:NSUTF8StringEncoding];
            size_t numberOfBytesToWrite = strlen(bytesToWrite);
            size_t numberOfBytesActuallyWritten = write(fd, bytesToWrite, numberOfBytesToWrite);
            if(numberOfBytesActuallyWritten <= 0){
                NSLog(@"There was some failure writing %@, %zu bytes were written, %s", nextInputLine, numberOfBytesActuallyWritten, strerror(errno));
            }
            dispatch_suspend(weakSelf->writeSource);
        });
        dispatch_source_set_cancel_handler(writeSource, ^{
            NSLog(@"Cancelling Writing handler");
            close(fd);
        });
        //dispatch_resume(writeSource);
    });
}

- (void)textDidChange:(NSNotification *)aNotification{
    NSLog(@"Text changed");
}

- (IBAction)enterKey:(id)sender{
    [self.inputQueue enqueue:[sender stringValue]];
}

- (NSAttributedString*)processIncomingStream:(NSString*)string withPreviousAttributes:(NSMutableDictionary **)attrs{   
    [self setupDefaults:*attrs overwrite:NO];
    if([string length] == 0){
        NSMutableAttributedString *attributedResult = [[NSMutableAttributedString alloc] init];
        [attributedResult addAttributes:*attrs range:NSMakeRange(0, [string length])];
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
        [self processServerCommand:subString];
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
    [attributedResult addAttributes:*attrs range:NSMakeRange(0, [colorStrippedString length])];
    
    NSInteger offset = 2;
    for(int i=0;i<[matches count];i++){
        NSTextCheckingResult *result = [matches objectAtIndex:i];
        NSRange firstRange = [result rangeAtIndex:1];
        if(firstRange.location != NSNotFound){
            NSString *firstString = [commandStrippedString substringWithRange:firstRange];
            firstRange.location = firstRange.location - offset;
            NSInteger code = [firstString integerValue];
            if(code == 0){
                [self setupDefaults:*attrs overwrite:YES];
            }else{
                [*attrs setObject:[self attributeForCode:code] forKey:[self attributeNameForCode:code]];
            }
            [attributedResult addAttributes:*attrs range:NSMakeRange(firstRange.location,[attributedResult length]-firstRange.location)];
            offset+=2;
        }
        NSRange secondRange = [result rangeAtIndex:2];
        if(secondRange.location != NSNotFound){
            NSString *secondString = [commandStrippedString substringWithRange:secondRange];
            secondRange.location = secondRange.location - offset;
            NSInteger code = [secondString integerValue];
            if(code == 0){
                [self setupDefaults:*attrs overwrite:YES];
            }else{
                [*attrs setObject:[self attributeForCode:code] forKey:[self attributeNameForCode:code]];
            }
            [attributedResult addAttributes:*attrs range:NSMakeRange(secondRange.location,[attributedResult length]-secondRange.location)];
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

- (void)processServerCommand:(NSString*)string{
    GOServerCommand serverCommand = [string characterAtIndex:1];
    NSLog(@"processing chars: %@", [string charCodeString]);
    switch(serverCommand){
        case WILL:
            NSLog(@"WILL");
            [self processServerOptionForWill:string];
            break;
        case GO_AHEAD:
            NSLog(@"GO AHEAD");
            dispatch_resume(writeSource);
            break;
        case WONT:
            NSLog(@"WON'T");
            break;
        case DO:
            NSLog(@"DO");
            break;
        case DONT:
            NSLog(@"DON'T");
            break;
    }
}

- (void)processServerOptionForWill:(NSString*)string{
    GOServerOption serverOption = [string characterAtIndex:2];
    switch(serverOption){
        case ECHO:
            NSLog(@"echo");
            [self sendCommand:DONT withOption:ECHO];
            break;
        case SUPPRESS_GO_AHEAD:
            NSLog(@"suppress go ahead");
            [self sendCommand:DONT withOption:SUPPRESS_GO_AHEAD];
            break;
        case END_OF_RECORD:
            NSLog(@"end of record");
            [self sendCommand:DO withOption:END_OF_RECORD];
            break;
        case TERMINAL_TYPE:
            NSLog(@"terminal type");
            [self sendCommand:DONT withOption:TERMINAL_TYPE];
            break;
        case CHARACTER_ENCODING:
            NSLog(@"character encoding");
            [self sendCommand:DONT withOption:CHARACTER_ENCODING];
            break;
        case MUD_SOUND_PROTOCOL:
            NSLog(@"mud sound protocol");
            [self sendCommand:DONT withOption:MUD_SOUND_PROTOCOL];
            break;
        case ZENITH_MUD_PROTOCOL:
            NSLog(@"zenith mud protocol");
            [self sendCommand:DONT withOption:ZENITH_MUD_PROTOCOL];
            break;
        case MUD_EXTERNSION_PROTOCOL:
            NSLog(@"mud extension protocol");
            [self sendCommand:DONT withOption:MUD_EXTERNSION_PROTOCOL];
            break;
        case MUD_SERVER_DATA_PROTOCOL:
            NSLog(@"mud server data protocol");
            [self sendCommand:DONT withOption:MUD_SERVER_DATA_PROTOCOL];
            break;
        case MUD_SERVER_STATUS_PROTOCOL:
            NSLog(@"mud server status protocol");
            [self sendCommand:DONT withOption:MUD_SERVER_STATUS_PROTOCOL];
            break;
        case NEGOTIATE_ABOUT_WINDOW_SIZE:
            NSLog(@"negotiate window size");
            [self sendCommand:DONT withOption:NEGOTIATE_ABOUT_WINDOW_SIZE];
            break;
        case ACHAEA_TELNET_CLIENT_PROTOCOL:
            NSLog(@"atcp");
            [self sendCommand:DONT withOption:ACHAEA_TELNET_CLIENT_PROTOCOL];
            break;
        case AARDWOLF_TELNET_CLIENT_PROTOCOL:
            NSLog(@"aardwolf");
            [self sendCommand:DONT withOption:AARDWOLF_TELNET_CLIENT_PROTOCOL];
            break;
        case MUD_CLIENT_COMPRESSION_PROTOCOL:
            NSLog(@"mud client compression protocol");
            [self sendCommand:DONT withOption:MUD_CLIENT_COMPRESSION_PROTOCOL];
            break;
        case MUD_CLIENT_COMPRESSION_PROTOCOL_2:
            NSLog(@"mud client ocmpression protocol 2");
            [self sendCommand:DONT withOption:MUD_CLIENT_COMPRESSION_PROTOCOL_2];
            break;
        case GENERIC_MUD_COMMUNICATION_PROTOCOL:
            NSLog(@"GMCP");
            [self sendCommand:DONT withOption:GENERIC_MUD_COMMUNICATION_PROTOCOL];
            break;
    }
}

- (void)sendCommand:(GOServerCommand)command withOption:(GOServerOption)option{
    char message[3];
    message[0] = IAC;
    message[1] = command;
    message[2] = option;
    NSString *commandToSend = [NSString stringWithCString:message encoding:NSASCIIStringEncoding];
    [[self inputQueue] enqueue:commandToSend];
}
@end
