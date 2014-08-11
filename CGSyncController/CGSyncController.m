//
//  CGSyncController.m
//  REPO
//
//  Created by Charles Gorectke on 7/25/14.
//  Copyright (c) 2014 Jackson. All rights reserved.
//

//#import <pthread/pthread.h>
#import "CGSyncController.h"

#import "CGDataController.h"
#import "NSManagedObject+SYNC.h"

#import "Candidate.h"

NSString * const kCGSyncControllerSyncStartedNotificationKey = @"kCGSyncControllerSyncStartedNotificationKey";
NSString * const kCGSyncControllerSyncCompletedNotificationKey = @"kCGSyncControllerSyncCompletedNotificationKey";

@interface CGSyncController () 

//@property (atomic, assign) BOOL initialized;
@property (atomic, readwrite) BOOL syncInProgress;

//@property (atomic) int globalSyncTotal;
//@property (atomic) int globalSyncCount;
//@property (nonatomic) UIBackgroundTaskIdentifier mainCandidateTask;

@property (nonatomic, strong) NSMutableDictionary *registeredClassesToSync;
@property (nonatomic, strong) NSDateFormatter *dateFormatter;

//@property (nonatomic, strong) NSMutableArray *currentSyncQueue;
//@property (nonatomic, strong) NSMutableArray *missingDataQueue;

//@property (atomic) pthread_mutex_t missing_lock;

@end

@implementation CGSyncController
@synthesize syncInProgress=_syncInProgress;
@synthesize registeredClassesToSync=_registeredClassesToSync;
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
    if (!_registeredClassesToSync) _registeredClassesToSync = [[NSMutableDictionary alloc] init];
    [_registeredClassesToSync setObject:parameter forKey:className];
}

- (NSString *)urlForRegisteredClass:(NSString *)className
{
    NSString * urlPath = [_registeredClassesToSync objectForKey:className];
    if (!urlPath) {
#warning throw Exception
    }
    return urlPath;
}

- (void)syncRegisteredClasses
{
    
}

- (void)syncClass:(NSString *)className
{
    
}

//- (void)syncRegisteredClasses
//{
//    for (NSString * key in [_registeredClassesToSync allKeys]) {
//        [[CGConnectionController sharedConnection] requestStatusOfObjectsWithType:[_registeredClassesToSync objectForKey:key]];
//    }
//}

- (void)checkForNecessarySyncWithStatus:(NSDictionary *)status
{
    NSDictionary * typeStatus = [self statusDictionaryForType:[status objectForKey:@"type"]];
    if ([[status objectForKey:@"lastUpdated"] compare:[typeStatus objectForKey:@"lastUpdated"]] != NSOrderedSame) {
        NSString * typeKey = [status objectForKey:@"type"];
        [[CGConnectionController sharedConnection] requestObjectsWithType:[_registeredClassesToSync objectForKey:typeKey] andLimit:0];
    }
}



- (NSDictionary *)statusDictionaryForType:(NSString *)type
{
    NSArray * objectsArray = [[CGDataController sharedData] managedObjsAsDictionariesForClass:type sortedByKey:@"updatedAt" withBatchSize:1 ascending:NO];
    if (!objectsArray) {
        return nil;
    } else {
        NSDictionary * obj = [objectsArray objectAtIndex:0];
        
#warning Get correct keys to return
        NSDictionary * ret = [[NSDictionary alloc] initWithObjectsAndKeys:[obj objectForKey:@"updatedAt"], @"updatedAt", nil];
        return ret;
    }
}

- (void)syncObjectsOfType:(NSString *)type withObjects:(NSArray *)objects
{
    NSArray * cachedObjects = [[CGDataController sharedData] managedObjectsForClass:type sortedByKey:@"updatedAt"];
    NSArray * longerArray = ([objects count] > [cachedObjects count]) ? objects : cachedObjects;
    NSArray * shorterArray = ([objects count] > [cachedObjects count]) ? cachedObjects : objects;
    
    int shortOffset = 0;
    
    for (int i = 0; i < [longerArray count]; i++) {
        
        
        NSDictionary * shortObj;
        NSDictionary * longObj = [longerArray objectAtIndex:i];
        
        if ([shorterArray count] > i - shortOffset) {
            shortObj = [shorterArray objectAtIndex:i - shortOffset];
        
            NSString * objLongId = [longObj objectForKey:@"objectId"];
            NSString * objShortId = [shortObj objectForKey:@"objectId"];
                
            if ([objLongId isEqualToString:objShortId]) {
                
                NSDate * longDate = [longObj objectForKey:@"updatedAt"];
                NSDate * shortDate = [shortObj objectForKey:@"updatedAt"];
                
                if ([longDate compare:shortDate] == NSOrderedAscending) {
                    
                    // update longObj with shortObj data and then sync or store longObj
                    
                } else if ([longDate compare:shortDate] == NSOrderedDescending) {
                    
                    // update shortObj with longObj data and then sync or store longObj
                    
                }
                
            } else {
                
                // Insert longObj into Data Store or Sync
                shortOffset++;
                
            }
            
        } else {
            
            // Insert longObj into Data Store or Sync
            shortOffset++;
                
        }
    }
}

#pragma mark - CGConnection Data Protocol

- (void)connection:(CGConnection *)connection didSyncObject:(NSDictionary *)object
{
    NSLog(@"Connection Successfully Synced Object");
}

- (void)connection:(CGConnection *)connection didFailToSyncObject:(NSDictionary *)object withError:(NSError *)error
{
    NSLog(@"Connection Failed To Sync Object");
    DLog(@"Error: %@", [error localizedDescription]);
}

- (void)connection:(CGConnection *)connection didDeleteObject:(NSDictionary *)object
{
    NSLog(@"Connection Successfully Deleted Object");
}

- (void)connection:(CGConnection *)connection didFailToDeleteObject:(NSDictionary *)object withError:(NSError *)error
{
    NSLog(@"Connection Failed To Delete Object");
    DLog(@"Error: %@", [error localizedDescription]);
}

- (void)connection:(CGConnection *)connection didReceiveObject:(NSDictionary *)object
{
    NSLog(@"Connection Successfully Received Object");
}

- (void)connection:(CGConnection *)connection didFailToReceiveObjectWithError:(NSError *)error
{
    NSLog(@"Connection Failed To Receive Object");
    DLog(@"Error: %@", [error localizedDescription]);
}

- (void)connection:(CGConnection *)connection didReceiveObjects:(NSArray *)objects
{
    NSLog(@"Connection Successfully Received Objects");
}

- (void)connection:(CGConnection *)connection didFailToReceiveObjectsWithError:(NSError *)error
{
    NSLog(@"Connection Failed To Receive Objects");
    DLog(@"Error: %@", [error localizedDescription]);
}

- (void)connection:(CGConnection *)connection didReceiveStatusForType:(NSDictionary *)status
{
    NSLog(@"Connection Successfully Received Status");
    [self checkForNecessarySyncWithStatus:status];
}

- (void)connection:(CGConnection *)connection didFailToReceiveStatusForObjectType:(NSString *)type withError:(NSError *)error
{
    NSLog(@"Connection Failed To Receive Status");
    DLog(@"Error: %@", [error localizedDescription]);
}

- (void)connection:(CGConnection *)connection didReceiveCount:(NSUInteger)count forObjectType:(NSString *)type
{
    NSLog(@"Connection Successfully Received Count");
}

- (void)connection:(CGConnection *)connection didFailToReceiveCountForObjectType:(NSString *)type withError:(NSError *)error
{
    NSLog(@"Connection Failed To Receive Count");
    DLog(@"Error: %@", [error localizedDescription]);
}

#pragma mark - Date Conversion Methods

- (void)initializeDateFormatter {
    if (!self.dateFormatter) {
        self.dateFormatter = [[NSDateFormatter alloc] init];
        [self.dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss'Z'"];
        [self.dateFormatter setTimeZone:[NSTimeZone timeZoneWithName:@"GMT"]];
    }
}

- (NSDate *)dateUsingStringFromAPI:(NSString *)dateString {
    [self initializeDateFormatter];
    // NSDateFormatter does not like ISO 8601 so strip the milliseconds and timezone
    dateString = [dateString substringWithRange:NSMakeRange(0, [dateString length]-5)];
    return [self.dateFormatter dateFromString:dateString];
}

- (NSString *)dateStringForAPIUsingDate:(NSDate *)date {
    [self initializeDateFormatter];
    NSString *dateString = [self.dateFormatter stringFromDate:date];
    // remove Z
    dateString = [dateString substringWithRange:NSMakeRange(0, [dateString length]-1)];
    // add milliseconds and put Z back on
    dateString = [dateString stringByAppendingFormat:@".000Z"];
    
    return dateString;
}

#pragma mark - Dealloc Protocol

- (void)dealloc
{
//    pthread_mutex_destroy(&_missing_lock);
}

@end
