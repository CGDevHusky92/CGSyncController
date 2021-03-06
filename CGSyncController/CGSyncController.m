//
//  CGSyncController.m
//  REPO
//
//  Created by Charles Gorectke on 7/25/14.
//  Copyright (c) 2014 Jackson. All rights reserved.
//

#import "CGSyncController.h"

#import <CGDataController/CGDataController.h>
#import <CGSubExtender/CGSubExtender.h>

#define SYNC_PRINT_DEBUG    1

NSString * const kCGSyncControllerSyncStartedNotificationKey = @"kCGSyncControllerSyncStartedNotificationKey";
NSString * const kCGSyncControllerSyncCompletedNotificationKey = @"kCGSyncControllerSyncCompletedNotificationKey";

@interface CGSyncController () 

//@property (atomic, assign) BOOL initialized;
@property (atomic, readwrite) BOOL syncInProgress;

//@property (atomic) int globalSyncTotal;
//@property (atomic) int globalSyncCount;
//@property (nonatomic) UIBackgroundTaskIdentifier mainCandidateTask;


@property (nonatomic, strong) NSDateFormatter *dateFormatter;

//@property (nonatomic, strong) NSMutableArray *currentSyncQueue;
//@property (nonatomic, strong) NSMutableArray *missingDataQueue;

//@property (atomic) pthread_mutex_t missing_lock;

@end

@implementation CGSyncController
@synthesize syncInProgress=_syncInProgress;
@synthesize dateFormatter=_dateFormatter;
//@synthesize missing_lock=_missing_lock;

+ (CGSyncController *)sharedSync
{
    static CGSyncController *sharedSync = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedSync = [[CGSyncController alloc] init];
    });
    return sharedSync;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
//        [[CGConnectionController sharedConnection] setSyncDelegate:self];
        [[CGConnectionController sharedConnection] setDataDelegate:self];
        
//        _initialized = NO;
        _syncInProgress = NO;
//        _currentSyncQueue = [[NSMutableArray alloc] init];
//        _missingDataQueue = [[NSMutableArray alloc] init];
//        pthread_mutex_init(&_missing_lock, NULL);
    }
    return self;
}

- (void)registerClassForSync:(NSString *)className withURLParameter:(NSString *)parameter
{
    [[CGConnectionController sharedConnection] registerClass:className withURLParameter:parameter];
}

//- (NSString *)urlForRegisteredClass:(NSString *)className
//{
//    
//    
//    NSString * urlPath = [_registeredClassesToSync objectForKey:className];
//    if (!urlPath) {
//#warning throw Exception
//    }
//    return urlPath;
//}

- (void)syncRegisteredClasses
{
    for (NSString * key in [[CGConnectionController sharedConnection] registeredClasses]) {
        NSLog(@"Checking If Sync Is Necessary For %@", key);
        [self initSyncWithClass:key];
    }
}

- (void)initSyncWithClass:(NSString *)className
{
    // Status Check
    [[CGConnectionController sharedConnection] requestStatusOfObjectsWithType:className andCompletion:^(NSDictionary * statusDic, NSError * error){
        if (!error) {
            NSDictionary * localStatus = [[CGDataController sharedData] statusDictionaryForClass:className];
            
            NSDate * serverDate, * localDate;
            
            if (![[statusDic objectForKey:@"lastUpdatedAt"] isEqualToString:@""]) {
                NSLog(@"Server Date: %@", [statusDic objectForKey:@"lastUpdatedAt"]);
                serverDate = [[NSDate alloc] initWithString:[statusDic objectForKey:@"lastUpdatedAt"]];
            } else {
                NSLog(@"Server has no recruiters");
            }
            
            
            if ([[localStatus objectForKey:@"lastUpdatedAt"] isKindOfClass:[NSDate class]]) {
                localDate = [localStatus objectForKey:@"lastUpdatedAt"];
            } else if (![[localStatus objectForKey:@"lastUpdatedAt"] isEqualToString:@""]) {
                NSLog(@"Local Date: %@", [localStatus objectForKey:@"lastUpdatedAt"]);
                localDate = [[NSDate alloc] initWithString:[localStatus objectForKey:@"lastUpdatedAt"]];
            } else {
                NSLog(@"Local cache has no recruiters");
            }
            
            if ((!serverDate && localDate) || (serverDate && !localDate) || [serverDate compare:localDate] != NSOrderedSame) {
#warning Notify start of sync
                NSLog(@"Firing Sync For %@", className);
                [self syncWithClass:className];
            } else {
                NSLog(@"Server Date %@ ... Local Date %@", serverDate, localDate);
                NSLog(@"Synchronization Is Not Needed For %@", className);
            }
        } else {
#warning Throw Exception
        }
    }];
}

- (void)syncWithClass:(NSString *)className
{
    [[CGConnectionController sharedConnection] requestObjectsWithType:className andCompletion:^(NSArray * serverObjects, NSError * error){
        NSLog(@"Received Server Response");
        if (!error) {
            NSArray * cachedObjects = [[CGDataController sharedData] managedObjectsForClass:className sortedByKey:@"updatedAt" ascending:NO withFetchLimit:0 withBatchSize:0 withPredicate:nil];
            NSArray * longerArray = ([serverObjects count] > [cachedObjects count]) ? serverObjects : cachedObjects;
            NSArray * shorterArray = ([serverObjects count] > [cachedObjects count]) ? cachedObjects : serverObjects;
            
            NSLog(@"Determined Loop Counts And Offsets");
            
            int i = 0, shortOffset = 0;
            
            for (i = 0; i < [longerArray count]; i++) {
                
                NSDictionary * shortObj;
                NSDictionary * longObj = [longerArray objectAtIndex:i];
                
                if ([shorterArray count] > i - shortOffset) {
                    shortObj = [shorterArray objectAtIndex:i - shortOffset];
                    
                    NSString * objLongId = [longObj valueForKey:@"objectId"];
                    NSString * objShortId = [shortObj valueForKey:@"objectId"];
                    
                    if ([objLongId isEqualToString:objShortId]) {
                        
                        NSDate * longDate, * shortDate;
                        
                        if ([[longObj valueForKey:@"updatedAt"] isKindOfClass:[NSDate class]]) {
                            longDate = [longObj valueForKey:@"updatedAt"];
                        } else {
                            longDate = [[NSDate alloc] initWithString:[longObj valueForKey:@"updatedAt"]];
                        }
                        
                        if ([[shortObj valueForKey:@"updatedAt"] isKindOfClass:[NSDate class]]) {
                            shortDate = [shortObj valueForKey:@"updatedAt"];
                        } else {
                            shortDate = [[NSDate alloc] initWithString:[shortObj valueForKey:@"updatedAt"]];
                        }
                        
                        if ([longDate compare:shortDate] == NSOrderedAscending) {
                            
                            // update longObj with shortObj data and then sync or store longObj
                            NSLog(@"Update longObj");
                            
                            [self handleUpdateForClassName:className withObject:shortObj];
                            
                        } else if ([longDate compare:shortDate] == NSOrderedDescending) {
                            
                            // update shortObj with longObj data and then sync or store longObj
                            NSLog(@"Update shortObj");
                            
                            
                            [self handleUpdateForClassName:className withObject:longObj];
                            
                        } else {
                            
                            NSLog(@"Item is in sync");
                            
                        }
                        
                    } else {
                        NSLog(@"Update 2 longObj");
                        
                        [self handleUpdateForClassName:className withObject:longObj];
                        shortOffset++;
                        
                    }
                    
                } else {
                    NSLog(@"Update 3 longObj");
                    
                    [self handleUpdateForClassName:className withObject:longObj];
                    shortOffset++;
                    
                }
            }
            
            while (i - shortOffset < [shorterArray count]) {
                // Finish syncing shorter array
                
                NSLog(@"Update 2 shortObj");
                
                [self handleUpdateForClassName:className withObject:[shorterArray objectAtIndex:(i - shortOffset)]];
                i++;
            }
            
#warning Notify end of sync...post sync cycle
        } else {
#warning Throw Exception
        }
    }];
}

- (void)handleUpdateForClassName:(NSString *)className withObject:(id)object
{
    if ([object isKindOfClass:[NSDictionary class]]) {
        // Save Server Object To Store
        
       
        CGManagedObject * obj = [[CGDataController sharedData] managedObjectForClass:className withId:[object valueForKey:@"objectId"]];
        if (obj) {
            
            NSLog(@"Updating Object And Saving To Store");
            
            //[obj updateFromDictionary:object];
            
            [[CGDataController sharedData] save];
            
        } else {
            // Insert New Object Into Data Store And Fill In Data
            
            NSLog(@"Inserting Object And Saving To Store");
            
            CGManagedObject * newObj = [[CGDataController sharedData] newManagedObjectForClass:className];
            
            NSLog(@"Test Object Is Actually - %@", object);
            
//            if ([newObj updateFromDictionary:object]) {
//                NSLog(@"That worked");
//            } else {
//                NSLog(@"That didn't work");
//            }
            
//            NSLog(@"Final Object - %@", newObj);
            
            [[CGDataController sharedData] save];
            
        }
    } else {
        // Sync Managed Object To Server
#ifdef SYNC_PRINT_DEBUG
        NSLog(@"Error");
//        NSLog(@"Updating Object And Syncing To Server - %@", object);
#endif
        
        [[CGConnectionController sharedConnection] syncObjectType:className withID:[object valueForKey:@"objectId"] andCompletion:^(NSError * error){
            if (error) {
#warning Throw Sync Error...Possibly cancel sync
                
                NSLog(@"Sync Error: %@", error);
            } else {
                #warning Individual items synced notification? with object type???
            }
        }];
    }
}

- (CGFloat)currentSyncProgress
{
    return 0.0;
}



#pragma mark - Dealloc Protocol

- (void)dealloc
{
//    pthread_mutex_destroy(&_missing_lock);
}

@end
