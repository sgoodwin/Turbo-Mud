//
//  GOReadDelegate.h
//  Turbo Mud
//
//  Created by Samuel Goodwin on 6/9/11.
//  Copyright 2011 SNAP Interactive. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface GOReadDelegate : NSObject<NSStreamDelegate>{
@private
    NSMutableData *_data;
}


@property(readonly)NSMutableData *data;

- (NSString*)charCodeString:(NSString*)orignal;
@end
