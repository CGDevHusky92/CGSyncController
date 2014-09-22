//
//  CGSyncController.h
//  REPO
//
//  Created by Charles Gorectke on 7/25/14.
//  Copyright (c) 2014 Jackson. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CGConnectionController.h"

// extern NSString * const kCGSyncControllerInitialCompleteKey;
// extern NSString * const kCGSyncControllerSyncCompletedNotificationName;

extern NSString * const kCGSyncControllerSyncStartedNotificationKey;
extern NSString * const kCGSyncControllerSyncCompletedNotificationKey;

typedef NS_ENUM(NSInteger, CGSyncStatus) {
    kCGStatusPending,
    kCGStatusSynced,
    kCGStatusDeleted
};

@protocol CGSyncControllerDelegate <NSObject>

- (void)willStartSyncForClass:(NSString *)className;
- (void)didStartSyncForClass:(NSString *)className;

- (void)updateSyncCompletionWithPercentage:(CGFloat)percent forClass:(NSString *)className;

- (void)willFinishSyncForClass:(NSString *)className;
- (void)didFinishSyncForClass:(NSString *)className;

@end

@interface CGSyncController : NSObject <CGConnectionDataDelegate>

@property (weak, nonatomic) id<CGSyncControllerDelegate> delegate;
@property (atomic, readonly) BOOL syncInProgress;

#pragma mark - Class Methods

+ (CGSyncController *)sharedSync;

#pragma mark - Object Methods

- (void)registerClassForSync:(NSString *)className withURLParameter:(NSString *)parameter;
- (NSString *)urlForRegisteredClass:(NSString *)className;

#pragma mark - Sync Methods

- (void)syncRegisteredClasses;
- (void)initSyncWithClass:(NSString *)className;

- (CGFloat)currentSyncProgress;

@end
