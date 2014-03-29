//
//  SyncController.m
//  ThisOrThat
//
//  Created by Chase Gorectke on 1/25/14.
//  Copyright (c) 2014 Revision Works, LLC. All rights reserved.
//

#import <pthread.h>
#import <Parse/Parse.h>
//#import "ThisOrThatAppDelegate.h"
#import "NSManagedObject+SYNC.h"

#import "CGSyncController.h"
#import "CGDataController.h"

#import "User.h"
#import "Decision.h"
#import "Choice.h"
#import "Friend.h"
#import "Group.h"

#import "PFDecision.h"
#import "PFChoice.h"
#import "PFFriend.h"

#ifdef TAT_LOGGING
#import "CGLogger.h"
#endif

#define DECISION_PULL_LIMIT 50

@interface CGSyncController ()

@end

@implementation CGSyncController

+ (CGSyncController *)sharedController
{
    static CGSyncController *sharedController = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedController = [[CGSyncController alloc] init];
    });
    return sharedController;
}

- (void)startRefreshForClass:(NSString *)aClass
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if (![self offline]) {
            if ([aClass isEqualToString:@"Decision"]) {
                NSArray *decsToSync = [self decisionsForGroup:0];
                [self genericSyncStageForClass:aClass andPreloadedObjects:decsToSync];
            } else {
                [self genericSyncStageForClass:aClass];
            }
        }
    });
}

- (void)genericSyncStageForClass:(NSString *)className
{
    [self genericSyncStageForClass:className andPreloadedObjects:nil];
}

- (void)genericSyncStageForClass:(NSString *)className andPreloadedObjects:(NSArray *)objects
{
    if ([self classCheck:className]) return;
    
    int extPos = 0, intPos = 0;
    NSDictionary *intObj;
    CGManagedObject *extObj;
    NSMutableArray *delete = [[NSMutableArray alloc] init];
    
    NSArray *external;
    if (objects) {
        external = objects;
    } else {
        external = [self grabAllServerObjectsWithName:className orderAscendingByKey:@"createdAt"];
    }
    
    NSArray *internal = [[CGDataController sharedData] managedObjsAsDictionariesForClass:className sortedByKey:@"createdAt" withBatchSize:20 ascending:YES];
    
#warning Test for best and quickest way of accessing objects in dictionary
    // Play with objs vs dictionaries... and batch sizes...
    // [[DataController sharedData] managedObjectsForClass:className sortedByKey:@"createdAt" withBatchSize:20 ascending:YES];
    
    if ([internal count] > intPos) intObj = [internal objectAtIndex:intPos];
    if ([external count] > extPos) extObj = [external objectAtIndex:extPos];
    
    while (intObj || extObj) {
        if (intObj && extObj) {
            if ([[intObj objectForKey:@"objectId"] isEqualToString:[extObj objectId]]) {
                if ([[extObj updatedAt] compare:[intObj objectForKey:@"updatedAt"]] == NSOrderedAscending) {
                    // Update server object
                    [self updateServerObject:extObj fromObject:intObj];
                } else if ([[extObj updatedAt] compare:[intObj objectForKey:@"updatedAt"]] == NSOrderedDescending) {
                    // Update local object
                    [self updateLocalObject:intObj fromObject:extObj];
                }
                intPos++; extPos++;
            } else if (intPos == 0 || extPos == 0) {
                if ([[extObj createdAt] compare:[intObj objectForKey:@"createdAt"]] == NSOrderedAscending) {
                    // Save extObj to device
                    [self saveNewObject:extObj];
                    extPos++;
                } else {
                    [delete addObject:intObj];
                    intPos++;
                }
            } else {
                if ([[extObj createdAt] compare:[intObj objectForKey:@"createdAt"]] == NSOrderedAscending) {
                    [self saveNewObject:extObj];
                    extPos++;
                } else {
                    [self syncNewObject:intObj];
                    intPos++;
                }
            }
        } else if (intObj) {
            // Sync intObj to server
            [self syncNewObject:intObj];
            intPos++;
        } else if (extObj) {
            // Save extObj to device
            [self saveNewObject:extObj];
            extPos++;
        }
        
        if ([internal count] > intPos) intObj = [internal objectAtIndex:intPos];
        if ([external count] > extPos) extObj = [external objectAtIndex:extPos];
    }
    
    // Clean up objects
    [self cleanUpObjects:delete];
}

- (void)cleanUpObjects:(NSArray *)objects
{
    NSManagedObjectContext *context = [[CGDataController sharedData] backgroundManagedObjectContext];
    for (NSManagedObjectID *objId in objects) {
        NSManagedObject *obj = [context objectWithID:objId];
        if (obj) {
            [context deleteObject:obj];
        } else {
            NSLog(@"Error: No object for id");
        }
    }
}

#pragma mark - Sync Tools

- (BOOL)classCheck:(NSString *)className
{
    if (!className) return NO;
    if ([className isEqualToString:@"Decision"] || [className isEqualToString:@"Choice"] || [className isEqualToString:@"Friend"] || [className isEqualToString:@"Group"]) {
        return YES;
    }
    return NO;
}

#warning fix and check inputs and arrays for existing objects... push object grab code to DataController
- (void)updateLocalObject:(NSDictionary *)intObj fromObject:(CGManagedObject *)extObj
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSArray *objArray = [[CGDataController sharedData] managedObjectsForClass:[intObj objectForKey:@"parseClassName"] sortedByKey:@"createdAt" withPredicate:[NSPredicate predicateWithFormat:@"objectId like %@", [intObj objectForKey:@"objectId"]]];
        NSManagedObject *obj = [objArray objectAtIndex:0];
        [self setObjectSync:obj andNotify:YES];
        [obj updateFromDictionary:[extObj dictionaryFromObject]];
        [self setObjectSync:obj andNotify:NO];
    });
}

- (void)updateServerObject:(CGManagedObject *)extObj fromObject:(NSDictionary *)intObj
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *error = nil;
        NSArray *objArray = [[CGDataController sharedData] managedObjectsForClass:[intObj objectForKey:@"parseClassName"] sortedByKey:@"createdAt" withPredicate:[NSPredicate predicateWithFormat:@"objectId like %@", [intObj objectForKey:@"objectId"]]];
        NSManagedObject *obj = [objArray objectAtIndex:0];
        [self setObjectSync:obj andNotify:YES];
        [extObj updateFromDictionary:intObj];
        [extObj save:&error];
        [self setObjectSync:obj andNotify:NO];
    });
}

- (void)saveNewObject:(CGManagedObject *)extObj
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSManagedObject *obj = [[CGDataController sharedData] newManagedObjectForClass:[extObj parseClassName]];
        [self setObjectSync:obj andNotify:YES];
        [self customSaveForObject:obj fromObject:extObj];
        [self setObjectSync:obj andNotify:NO];
    });
}

- (void)syncNewObject:(NSDictionary *)intObj
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSManagedObject *obj = [[CGDataController sharedData] managedObjectForClass:[intObj objectForKey:@"parseClassName"] withId:[intObj objectForKey:@"objectId"]];
        if (obj) {
            [self setObjectSync:obj andNotify:YES];
            [self customSyncForObject:obj];
            [self setObjectSync:obj andNotify:NO];
        } else {
            NSLog(@"Error: Object for syncing could not be found");
        }
    });
}

- (void)customSaveForObject:(NSManagedObject *)intObj fromObject:(CGManagedObject *)extObj
{
    if (!intObj || !extObj) return;
    [intObj updateFromDictionary:[extObj dictionaryFromObject]];
    if ([[intObj parseClassName] isEqualToString:@"Choice"]) {
        
    }
}

- (void)customSyncForObject:(NSManagedObject *)obj
{
    NSString *className = [obj parseClassName];
    CGManagedObject *extObj = (CGManagedObject *)[PFObject objectWithClassName:[obj parseClassName]];
    [extObj updateFromDictionary:[obj dictionaryFromObject]];
    
    if ([className isEqualToString:@"Decision"]) {
        
        if ([[extObj parseClassName] isEqualToString:@"Decision"]) {
            PFDecision *decObj = (PFDecision *)extObj;
            NSArray *choiceIds = [decObj choices];
            BOOL choicesSynced = false;
            
            while (!choicesSynced) {
#warning won't work because objIds won't exist yet... Just check relationship and go from there...
                for (NSString *chcId in choiceIds) {
                    if (![self objectExistsOnDisk:chcId]) {
                        CGManagedObject *chcObj = [self retrieveObjectOnServer:chcId];
                        [self saveNewObject:chcObj];
                    }
                }
            }
        }
    }
}

- (BOOL)objectExistsOnDisk:(NSString *)objId
{
    return NO;
}

- (CGManagedObject *)retrieveObjectOnServer:(NSString *)objId
{
    return nil;
}

- (void)setObjectSync:(NSManagedObject *)obj andNotify:(BOOL)sync
{
    NSManagedObjectContext *context = [[CGDataController sharedData] backgroundManagedObjectContext];
    [obj setSyncing:[NSNumber numberWithBool:sync]];
    [context performBlockAndWait:^{
        NSError *error = nil;
        if (![context save:&error]) {
            NSLog(@"Error Unable To Save Context: %@", [error localizedDescription]);
        }
    }];
}

#pragma mark - Grab server objects

- (NSArray *)grabAllServerObjectsWithName:(NSString *)className
{
    return [self grabAllServerObjectsWithName:className orderAscendingByKey:nil];
}

- (NSArray *)grabAllServerObjectsWithName:(NSString *)className orderAscendingByKey:(NSString *)key
{
    return [self grabAllServerObjectsWithName:className orderedByKey:key ascending:YES];
}

- (NSArray *)grabAllServerObjectsWithName:(NSString *)className orderDescendingByKey:(NSString *)key
{
    return [self grabAllServerObjectsWithName:className orderedByKey:key ascending:NO];
}

- (NSArray *)grabAllServerObjectsWithName:(NSString *)className orderedByKey:(NSString *)key ascending:(BOOL)ascend
{
    if (!className) return nil;
    
    NSError *error = nil;
    PFQuery *query = [PFQuery queryWithClassName:className];
    query.limit = 1000;
    
    if (key) {
        if (ascend) {
            [query orderByAscending:key];
        } else {
            [query orderByDescending:key];
        }
    }
    
    NSArray *objects = [query findObjects:&error];
    
    if (error) {
        NSLog(@"Error: %@", [error localizedDescription]);
    }
    
    return objects;
}

#pragma mark - Custom Decision Grab Tools

- (NSArray *)decisionsForGroup:(int)group
{
    NSError *error = nil;
    
    // 1
    if ([PFUser currentUser]) {
        PFQuery *rec = [PFQuery queryWithClassName:@"Decision"];
        [rec whereKey:@"receiver" equalTo:[[PFUser currentUser] username]];
        [rec orderByDescending:@"createdAt"];
        rec.limit = 50;
        NSArray *recObjs = [rec findObjects:&error];
        if (error) {
            NSLog(@"Error: %@", [error localizedDescription]);
            return nil;
        }
        
        // 2
        PFQuery *sen = [PFQuery queryWithClassName:@"Decision"];
        [sen whereKey:@"sender" equalTo:[[PFUser currentUser] username]];
        [sen orderByDescending:@"createdAt"];
        sen.limit = 1000;
        NSArray *senObjs = [sen findObjects:&error];
        if (error) {
            NSLog(@"Error: %@", [error localizedDescription]);
            return nil;
        }
        
        // 3
        // Unique array of objectIds
        // Array of the unique objects
        NSArray *senUniqueObjs = [self decisionsStripUniqueObjects:senObjs];
        
        // 4
        // Combine Unique Array and Rec Array Sorted By "createdAt"
        // Remove Anything after 50 items
        NSArray *combinedArray = [self decisionsSortedArrayOfObjects:recObjs andObjects:senUniqueObjs withLimit:YES];
        
        // 5
        // Iterate over remaining array and find objects contained in the unique array
        // add those objects to separate array and call decisionsFinalSelfSenderGroup on there valueForKey:@"choices"
        NSMutableArray *combMutable = [combinedArray mutableCopy];
        [combMutable removeObjectsInArray:recObjs];
        NSArray *finalUnique = [combMutable valueForKeyPath:@"choices"];
        NSArray *totalSend = [self decisionsFinalSenderFromGatheredObjects:senObjs forKeys:finalUnique];
        
        // 6
        // Recombine into single array
        NSArray *ret = [self decisionsSortedArrayOfObjects:recObjs andObjects:totalSend withLimit:YES];
        return ret;
    }
    
    return nil;
}

- (NSArray *)decisionsStripUniqueObjects:(NSArray *)objects
{
    if (!objects) return nil;
    NSMutableArray *ret = [[NSMutableArray alloc] init];
    NSMutableArray *uniqueObjKeys = [[objects valueForKeyPath:@"@distinctUnionOfObjects.choices"] mutableCopy];
    for (PFDecision *dec in objects) {
        if ([uniqueObjKeys containsObject:[dec choices]]) {
            [ret addObject:dec];
            [uniqueObjKeys removeObject:[dec choices]];
        }
    }
    return ret;
}

- (NSArray *)decisionsSortedArrayOfObjects:(NSArray *)objsOne andObjects:(NSArray *)objsTwo withLimit:(BOOL)limit
{
    if (!objsOne || !objsTwo) return nil;
    NSMutableArray *ret = [objsOne mutableCopy];
    ret = [[ret arrayByAddingObjectsFromArray:objsTwo] mutableCopy];
    [ret sortUsingDescriptors:[NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:@"createdAt" ascending:YES]]];
    if (limit && [ret count] > DECISION_PULL_LIMIT) {
        [ret removeObjectsInRange:NSMakeRange((DECISION_PULL_LIMIT), [ret count] - DECISION_PULL_LIMIT)];
    }
    return ret;
}

- (NSArray *)decisionsFinalSenderFromGatheredObjects:(NSArray *)objs forKeys:(NSArray *)objIds
{
    if (!objs || !objIds) return nil;
    NSMutableArray *ret = [[NSMutableArray alloc] init];
    for (PFDecision *dec in objs) {
        if ([objIds containsObject:[dec choices]]) {
            [ret addObject:dec];
        }
    }
    return ret;
}

@end
