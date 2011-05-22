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

@implementation Turbo_MudAppDelegate

@synthesize window, textField, inputQueue;

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
        NSString *results = [NSString stringWithCString:buffer encoding:NSASCIIStringEncoding];
        NSLog(@"Results: %@, %zu", results, bytesRead);
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
        
        size_t numberOfBytesToWrite = [nextInputLine length];
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
    dispatch_resume(writeSource);
}


- (IBAction)enterKey:(id)sender{
    [self.inputQueue enqueue:[sender stringValue]];
}
@end
