//
//  NSManagedObject+SYNC.h
//  ThisOrThat
//
//  Created by Chase Gorectke on 2/23/14.
//  Copyright (c) 2014 Revision Works, LLC. All rights reserved.
//

#import <CoreData/CoreData.h>
#import <Foundation/Foundation.h>

@interface NSManagedObject (SYNC)

@property (nonatomic, retain) NSString * parseClassName;
@property (nonatomic, retain) NSDate * createdAt;
@property (nonatomic, retain) NSString * objectId;
@property (nonatomic, retain) NSNumber * pending;
@property (nonatomic, retain) NSDate * updatedAt;
@property (nonatomic, retain) NSNumber * syncing;

- (BOOL)updateFromDictionary:(NSDictionary *)dic;
- (NSDictionary *)dictionaryFromObject;
- (NSDictionary *)cleanDictionary:(NSDictionary *)dic;

@end
