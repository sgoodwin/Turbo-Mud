//
//  Turbo_MudAppDelegate.m
//  Turbo Mud
//
//  Created by Samuel Goodwin on 5/15/11.
//  Copyright 2011 SNAP Interactive. All rights reserved.
//

#import "Turbo_MudAppDelegate.h"
#include <netinet/in.h>
#include <sys/socket.h>
#include "signal.h"
#include <netdb.h>

@implementation Turbo_MudAppDelegate

@synthesize window;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification{
    int fd;
    struct addrinfo hints;
    struct addrinfo *result, *rp;
    
    memset(&hints, 0, sizeof(struct addrinfo));
    hints.ai_canonname = NULL;
    hints.ai_addr = NULL;
    hints.ai_next = NULL;
    hints.ai_family = AF_UNSPEC; // This says we don't care if it's ipv4 or ipv6
    hints.ai_socktype = SOCK_STREAM;
    hints.ai_flags = AI_NUMERICSERV;
    if(getaddrinfo("lusternia.com", "23", &hints, &result) != 0){
        NSLog(@"Getaddrinfo failed");
    }
    
    for(rp = result; rp != NULL;rp = rp->ai_next){
        fd = socket(rp->ai_family, rp->ai_socktype, rp->ai_protocol);
        if(fd == -1){
            continue;
        }
        int flags = fcntl(fd, F_GETFL, 0);
        fcntl(fd, F_SETFL, flags | O_NONBLOCK);
        
        if(connect(fd, rp->ai_addr, rp->ai_addrlen) != -1){
            break;
        }
        
        close(fd);
    }
    
    if(rp == NULL){
        NSLog(@"Could not connect on any address :(");
        freeaddrinfo(result);
    }else{
        dispatch_queue_t queue = dispatch_queue_create("com.mikeash.MAAsyncReader", NULL);        
        dispatch_source_t source = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, fd, 0, queue);
        dispatch_source_set_event_handler(source, ^{
            unsigned long estimatedBytesAvailable = dispatch_source_get_data(source);
            void *buffer = NULL;
            ssize_t bytesRead = read(fd, &buffer, estimatedBytesAvailable);
            NSLog(@"%s read from socket. %zi/%zi", buffer, bytesRead, estimatedBytesAvailable);
        });
        dispatch_source_set_cancel_handler(source, ^{ 
            NSLog(@"Cancelling Reading handler");
            close(fd); 
        });
        dispatch_resume(source);
    }
}

@end
