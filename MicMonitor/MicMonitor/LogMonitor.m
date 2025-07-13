//
//  LogMonitor.m
//  MicMonitor
//
//  Simplified system log monitoring for microphone process identification
//  Extracted from OverSight
//

#import "LogMonitor.h"

@implementation OSLogEvent
+ (instancetype)OSLogEvent {
    return [[self alloc] init];
}
@end

// Parse the private OSLogEventProxy event
// Pull out items of interest, and save into our defined event
static OSLogEvent* parseEvent(OSLogEventProxy* event) {
    OSLogEvent *logEvent = [OSLogEvent OSLogEvent];
    logEvent.process = event.process;
    logEvent.processImagePath = event.processImagePath;
    logEvent.processIdentifier = [NSNumber numberWithInt:event.processIdentifier];
    logEvent.sender = event.sender;
    logEvent.senderImagePath = event.senderImagePath;
    logEvent.category = event.category;
    logEvent.subsystem = event.subsystem;
    logEvent.date = event.date;
    logEvent.composedMessage = event.composedMessage;
    return logEvent;
}

@implementation LogMonitor

- (id)init {
    NSError* error = nil;
    
    self = [super init];
    if (nil != self) {
        // Ensure LoggingSupport.framework is loaded
        if (YES != [[NSBundle bundleWithPath:LOGGING_SUPPORT] loadAndReturnError:&error]) {
            NSLog(@"ERROR: failed to load logging framework %@ (error: %@)", LOGGING_SUPPORT, error);
            self = nil;
            goto bail;
        }
    }
    
bail:
    return self;
}

- (BOOL)start:(NSPredicate*)predicate level:(NSUInteger)level callback:(void(^)(OSLogEvent*))callback {
    BOOL started = NO;
    
    // Live stream class
    Class LiveStream = nil;
    
    // Event handler callback
    void (^eventHandler)(OSLogEventProxy* event) = ^void(OSLogEventProxy* event) {
        // Return the parsed event
        callback(parseEvent(event));
    };
    
    // Get 'OSLogEventLiveStream' class
    if (nil == (LiveStream = NSClassFromString(@"OSLogEventLiveStream"))) {
        NSLog(@"ERROR: failed to get OSLogEventLiveStream class");
        goto bail;
    }
    
    // Init live stream
    self.liveStream = [[LiveStream alloc] init];
    if (nil == self.liveStream) {
        NSLog(@"ERROR: failed to init OSLogEventLiveStream");
        goto bail;
    }
    
    // Sanity check - obj responds to setFilterPredicate:?
    if (YES != [self.liveStream respondsToSelector:NSSelectorFromString(@"setFilterPredicate:")]) {
        NSLog(@"ERROR: liveStream doesn't respond to setFilterPredicate:");
        goto bail;
    }
    
    // Set predicate
    [self.liveStream setFilterPredicate:predicate];
    
    // Sanity check - obj responds to setInvalidationHandler:?
    if (YES != [self.liveStream respondsToSelector:NSSelectorFromString(@"setInvalidationHandler:")]) {
        NSLog(@"ERROR: liveStream doesn't respond to setInvalidationHandler:");
        goto bail;
    }
    
    // Set invalidation handler
    [self.liveStream setInvalidationHandler:^void (int reason, id streamPosition) {
        // Note: need to have something set as this gets called (indirectly) when
        // the 'invalidate' method is called ... but don't need to do anything
        ;
    }];
    
    // Sanity check - obj responds to setDroppedEventHandler:?
    if (YES != [self.liveStream respondsToSelector:NSSelectorFromString(@"setDroppedEventHandler:")]) {
        NSLog(@"ERROR: liveStream doesn't respond to setDroppedEventHandler:");
        goto bail;
    }
    
    // Set dropped msg handler
    [self.liveStream setDroppedEventHandler:^void (id droppedMessage) {
        // Note: need to have something set as this gets called (indirectly)
        ;
    }];
    
    // Sanity check - obj responds to setEventHandler:?
    if (YES != [self.liveStream respondsToSelector:NSSelectorFromString(@"setEventHandler:")]) {
        NSLog(@"ERROR: liveStream doesn't respond to setEventHandler:");
        goto bail;
    }
    
    // Set event handler
    [self.liveStream setEventHandler:eventHandler];
    
    // Sanity check - obj responds to setFlags:?
    if (YES != [self.liveStream respondsToSelector:NSSelectorFromString(@"setFlags:")]) {
        NSLog(@"ERROR: liveStream doesn't respond to setFlags:");
        goto bail;
    }
    
    // Set debug & info flags
    [self.liveStream setFlags:level];
    
    // Sanity check - obj responds to activate?
    if (YES != [self.liveStream respondsToSelector:NSSelectorFromString(@"activate")]) {
        NSLog(@"ERROR: liveStream doesn't respond to activate");
        goto bail;
    }
    
    // Activate
    [self.liveStream activate];
    
    NSLog(@"Successfully started log monitor with predicate: %@", predicate);
    
    // Success
    started = YES;
    
bail:
    return started;
}

- (void)stop {
    // Sanity check - obj responds to invalidate?
    if (YES != [self.liveStream respondsToSelector:NSSelectorFromString(@"invalidate")]) {
        goto bail;
    }
    
    // Not nil? invalidate
    if (nil != self.liveStream) {
        [self.liveStream invalidate];
    }
    
bail:
    return;
}

@end 