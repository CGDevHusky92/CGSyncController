//
//  SyncController.h
//  ThisOrThat
//
//  Created by Chase Gorectke on 1/25/14.
//  Copyright (c) 2014 Revision Works, LLC. All rights reserved.
//

#import <Parse/Parse.h>
#import <Foundation/Foundation.h>
#import "CGObject.h"
#import "CGDataController.h"

@interface CGSyncController : CGObject

+ (CGSyncController *)sharedController;

- (void)startRefreshForClass:(NSString *)aClass;

@end
