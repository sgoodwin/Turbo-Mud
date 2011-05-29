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

const unichar iac = 255;

@interface Turbo_MudAppDelegate()
- (void)scrollToBottom:(id)sender;
- (NSAttributedString *)processIncomingStream:(NSString*)string;
@end

@implementation Turbo_MudAppDelegate

@synthesize window, textField, scrollView, inputQueue;

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
        Turbo_MudAppDelegate *weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            [results enumerateLinesUsingBlock:^(NSString *line, BOOL *stop) {
                NSAttributedString *processedLine = [weakSelf processIncomingStream:line];
                [[weakSelf.textField textStorage] appendAttributedString:processedLine];
                [weakSelf scrollToBottom:nil];
            }];
        });
    });
    dispatch_source_set_cancel_handler(readSource, ^{ 
        NSLog(@"Cancelling Reading handler");
        close(fd); 
    });
    dispatch_resume(readSource);
    
    dispatch_queue_t writeQueue = dispatch_queue_create("com.goodwinlabs.writing", NULL);
    dispatch_source_t writeSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_WRITE, fd, 0, writeQueue);
    dispatch_source_set_event_handler(writeSource, ^{
        NSString *nextInputLine = [self.inputQueue dequeue];
        if(!nextInputLine){
            return;
        }
        NSLog(@"Queue has %@ left", self.inputQueue);
        size_t numberOfBytesToWrite = [nextInputLine length];
        const char *bytesToWrite = [[nextInputLine stringByAppendingString:@"\r\n"] cStringUsingEncoding:NSASCIIStringEncoding];
        size_t numberOfBytesActuallyWritten = write(fd, bytesToWrite, numberOfBytesToWrite);
        if(numberOfBytesActuallyWritten <= 0){
            NSLog(@"There was some failure writing %@, %zu bytes were written, %s", nextInputLine, numberOfBytesActuallyWritten, strerror(errno));
        }
    });
    dispatch_source_set_cancel_handler(writeSource, ^{
        NSLog(@"Cancelling Writing handler");
        close(fd);
    });
    dispatch_resume(writeSource);
}

- (void)textDidChange:(NSNotification *)aNotification{
    NSLog(@"Text changed");
}

- (IBAction)enterKey:(id)sender{
    [self.inputQueue enqueue:[sender stringValue]];
}

- (NSAttributedString*)processIncomingStream:(NSString*)string{
    if([string length] == 0){
        NSMutableAttributedString *attributedResult = [[NSMutableAttributedString alloc] init];
        [attributedResult addAttribute:NSForegroundColorAttributeName value:[NSColor whiteColor] range:NSMakeRange(0, [string length])];
        return attributedResult;
    }
    
    NSError *error = nil;
    NSRegularExpression *serverCommandRegex = [NSRegularExpression regularExpressionWithPattern:@"\\xFF(..)" options:NSRegularExpressionUseUnixLineSeparators error:&error];
    if(error){
        NSLog(@"error: %@", [error localizedDescription]);
    }
    [serverCommandRegex enumerateMatchesInString:string options:NSMatchingReportProgress range:NSMakeRange(0, [string length]) usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
        if(!result){
            return;
        }
        //NSRange rangeToHandle = NSMakeRange([result rangeAtIndex:1].location-1, [result rangeAtIndex:1].length+1);
        //NSString *subString = [string substringWithRange:rangeToHandle];
        // respond according to the matched server message;
    }];
    NSString *commandStrippedString = [serverCommandRegex stringByReplacingMatchesInString:string options:NSRegularExpressionUseUnixLineSeparators range:NSMakeRange(0,[string length]) withTemplate:@""];
    
    
    error = nil;
    NSRegularExpression *colorRegex = [NSRegularExpression regularExpressionWithPattern:@"\\e.(\\d{1,1};)??(\\d{1,2}m)" options:NSRegularExpressionUseUnixLineSeparators error:&error];
    if(error){
        NSLog(@"error: %@", [error localizedDescription]);
    }
    [colorRegex enumerateMatchesInString:commandStrippedString options:NSMatchingReportProgress range:NSMakeRange(0, [commandStrippedString length]) usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
        if(!result){
            return;
        }
        NSLog(@"original string: %@", commandStrippedString);
        NSRange firstRange = [result rangeAtIndex:1];
        if(firstRange.location != NSNotFound){
            
        }
        
        NSRange secondRange = [result rangeAtIndex:2];
        if(secondRange.location != NSNotFound){
           
        }
    }];
    
    NSString *colorStrippedString = [colorRegex stringByReplacingMatchesInString:commandStrippedString options:NSRegularExpressionUseUnixLineSeparators range:NSMakeRange(0,[commandStrippedString length]) withTemplate:@""];
    NSMutableAttributedString *attributedResult = [[NSMutableAttributedString alloc] initWithString:[colorStrippedString stringByAppendingString:@"\r\n"]];
    [attributedResult addAttribute:NSForegroundColorAttributeName value:[NSColor whiteColor] range:NSMakeRange(0, [colorStrippedString length])];
    return attributedResult;
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
@end
