//
//  LogMonitor.h
//  MicMonitor
//
//  Simplified system log monitoring for microphone process identification
//  Extracted from OverSight
//

#import <Foundation/Foundation.h>

// Log levels (from OverSight)
typedef enum
{
    Log_Level_Default,
    Log_Level_Info,
    Log_Level_Debug
} LogLevels;

// Path to LoggingSupport framework
#define LOGGING_SUPPORT @"/System/Library/PrivateFrameworks/LoggingSupport.framework"

@interface OSLogEvent : NSObject
@property NSString *process;
@property NSNumber *processIdentifier;
@property NSString *processImagePath;
@property NSString *sender;
@property NSString *senderImagePath;
@property NSString *category;
@property NSString *subsystem;
@property NSDate *date;
@property NSString *composedMessage;
+ (instancetype)OSLogEvent;
@end

@interface OSLogEventLiveStream : NSObject
- (void)activate;
- (void)invalidate;
- (void)setFilterPredicate:(NSPredicate *)predicate;
- (void)setDroppedEventHandler:(void (^)(id))callback;
- (void)setInvalidationHandler:(void (^)(int, id))callback;
- (void)setEventHandler:(void (^)(id))callback;
- (void)setFlags:(NSUInteger)flags;
@property(nonatomic) unsigned long long flags;
@end

@interface OSLogEventProxy : NSObject
@property(readonly, nonatomic) NSString *process;
@property(readonly, nonatomic) int processIdentifier;
@property(readonly, nonatomic) NSString *processImagePath;
@property(readonly, nonatomic) NSString *sender;
@property(readonly, nonatomic) NSString *senderImagePath;
@property(readonly, nonatomic) NSString *category;
@property(readonly, nonatomic) NSString *subsystem;
@property(readonly, nonatomic) NSDate *date;
@property(readonly, nonatomic) NSString *composedMessage;
@end

@interface LogMonitor : NSObject

@property(nonatomic, retain, nullable) id liveStream;
@property(nonatomic, assign) NSInteger lastMicClient;

- (BOOL)start:(NSPredicate *)predicate level:(NSUInteger)level callback:(void (^)(OSLogEvent *))callback;
- (void)stop;

@end