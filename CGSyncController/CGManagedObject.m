//
//  CGManagedObject.m
//  ThisOrThat
//
//  Created by Chase Gorectke on 1/16/14.
//  Copyright (c) 2014 Revision Works, LLC. All rights reserved.
//

#import <CoreData/CoreData.h>
#import "CGManagedObject.h"

#import "CGDataController.h"
#import "NSManagedObject+SYNC.h"

@implementation CGManagedObject

#pragma mark - CGManagedObject Protocol

- (BOOL)updateFromDictionary:(NSDictionary *)dic
{
    NSString *type = [self parseClassName];
    Class actClass = NSClassFromString(type);
    
    NSManagedObject *obj = [[actClass alloc] init];
    NSDictionary *cleanDic = [obj cleanDictionary:[self dictionaryFromObject]];
    
    if (![cleanDic isEqualToDictionary:dic]) {
        // Relationship checks and error checks...
        // Should be ok passing objectIds of relationships is exactly what the Parse
        // objects are using in the first place
        [self setValuesForKeysWithDictionary:dic];
    }
    
    return YES;
}

- (NSDictionary *)dictionaryFromObject
{
    return [self dictionaryFromObject];
}

- (void)saveServerSideObjectWithBlock:(void(^)(BOOL succeeded, NSError *error))block
{
    BOOL _offline = NO;
    if (_offline) {
        [self saveEventually:block];
    } else {
        [self saveInBackgroundWithBlock:block];
    }
}

@end
