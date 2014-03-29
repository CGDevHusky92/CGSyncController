//
//  CGManagedObject.h
//  ThisOrThat
//
//  Created by Chase Gorectke on 1/16/14.
//  Copyright (c) 2014 Revision Works, LLC. All rights reserved.
//

#import <Parse/Parse.h>

@interface CGManagedObject : PFObject

- (BOOL)updateFromDictionary:(NSDictionary *)dic;
- (NSDictionary *)dictionaryFromObject;

- (void)saveServerSideObjectWithBlock:(void(^)(BOOL succeeded, NSError *error))block;

@end
