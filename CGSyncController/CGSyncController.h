//
//  SyncController.h
//  ThisOrThat
//
//  Created by Chase Gorectke on 1/25/14.
//  Copyright (c) 2014 Revision Works, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CGObject.h"
#import "CGDataController.h"
#import "CGConnectionController.h"

@interface CGSyncController : CGObject

+ (instancetype)sharedSync;

- (void)startRefreshForClass:(NSString *)aClass;

@end
