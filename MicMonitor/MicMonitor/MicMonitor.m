//
//  MicMonitor.m
//  MicMonitor
//
//  Core microphone monitoring functionality
//  Extracted from OverSight
//

#import "MicMonitor.h"
#import <CoreMediaIO/CMIOHardware.h>
#import <AppKit/AppKit.h>

@implementation MicMonitor

- (instancetype)initWithCallback:(void(^)(NSDictionary* event))callback {
    self = [super init];
    if(self) {
        self.eventCallback = callback;
        self.audioListeners = [NSMutableDictionary dictionary];
        self.eventQueue = dispatch_queue_create("com.micmonitor.events", DISPATCH_QUEUE_SERIAL);
        self.logMonitor = [[LogMonitor alloc] init];
        self.builtInMic = [self findBuiltInMic];
        
        NSLog(@"Built-in mic: %@ (device ID: %d)", self.builtInMic.localizedName, [self getAVObjectID:self.builtInMic]);
    }
    return self;
}

- (void)start {
    NSLog(@"Starting microphone monitoring");
    
    [self startLogMonitor];
    
    AVCaptureDeviceDiscoverySession* discoverySession = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInMicrophone] mediaType:AVMediaTypeAudio position:AVCaptureDevicePositionUnspecified];
    
    for(AVCaptureDevice* audioDevice in discoverySession.devices) {
        [self watchAudioDevice:audioDevice];
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self 
                                             selector:@selector(handleConnectedDeviceNotification:) 
                                                 name:AVCaptureDeviceWasConnectedNotification 
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self 
                                             selector:@selector(handleDisconnectedDeviceNotification:) 
                                                 name:AVCaptureDeviceWasDisconnectedNotification 
                                               object:nil];
}

- (void)stop {
    NSLog(@"Stopping microphone monitoring");
    
    [self.logMonitor stop];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    AVCaptureDeviceDiscoverySession* discoverySession = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInMicrophone] mediaType:AVMediaTypeAudio position:AVCaptureDevicePositionUnspecified];
    
    for(AVCaptureDevice* audioDevice in discoverySession.devices) {
        [self unwatchAudioDevice:audioDevice];
    }
}

- (void)startLogMonitor {
    NSLog(@"Starting log monitor for microphone events");
    
    BOOL logMonitorStarted = NO;
    
    // macOS 14+
    if(@available(macOS 14.0, *)) {
        NSLog(@">= macOS 14+: Using log monitor for AV events with (mic): '-[MXCoreSession beginInterruption]: Session <ID: xx, PID = xyz,...'");
        
        // Start log monitoring
        logMonitorStarted = [self.logMonitor start:[NSPredicate predicateWithFormat:@"subsystem=='com.apple.cmio' OR subsystem=='com.apple.coremedia'"] 
                                             level:Log_Level_Default 
                                          callback:^(OSLogEvent* logEvent) {
            @synchronized (self) {
                NSTextCheckingResult* match = nil;
                NSInteger pid = 0;
                
                // mic: "-[MXCoreSession beginInterruption]: Session <ID: xx, PID = xyz, ...":
                if([logEvent.subsystem isEqual:@"com.apple.coremedia"] &&
                   [logEvent.composedMessage hasPrefix:@"-MXCoreSession- -[MXCoreSession beginInterruption]"] &&
                   [logEvent.composedMessage hasSuffix:@"Recording = YES> is going active"]) {
                    
                    // Reset
                    self.logMonitor.lastMicClient = 0;
                    
                    // Init mic regex
                    NSRegularExpression* micRegex = [NSRegularExpression regularExpressionWithPattern:@"PID = (\\d+)" options:0 error:nil];
                    
                    // Match on pid
                    match = [micRegex firstMatchInString:logEvent.composedMessage options:0 range:NSMakeRange(0, logEvent.composedMessage.length)];
                    if((nil == match) || (NSNotFound == match.range.location)) {
                        return;
                    }
                    
                    // Extract/convert pid
                    pid = [[logEvent.composedMessage substringWithRange:[match rangeAtIndex:1]] integerValue];
                    if((0 == pid) || (-1 == pid)) {
                        return;
                    }
                    
                    // Save
                    self.logMonitor.lastMicClient = pid;
                    NSLog(@"Detected microphone activation by PID: %ld", (long)pid);
                }
            }
        }];
    }
    // macOS 13.3+
    else if(@available(macOS 13.3, *)) {
        NSLog(@">= macOS 13.3+: Using 'CMIOExtensionPropertyDeviceControlPID'");
        
        // Start logging
        logMonitorStarted = [self.logMonitor start:[NSPredicate predicateWithFormat:@"subsystem=='com.apple.cmio'"] 
                                             level:Log_Level_Debug 
                                          callback:^(OSLogEvent* logEvent) {
            @synchronized (self) {
                NSTextCheckingResult* match = nil;
                NSInteger pid = 0;
                
                // Only interested in "CMIOExtensionPropertyDeviceControlPID = <pid>;" msgs
                if(YES != [logEvent.composedMessage containsString:@"CMIOExtensionPropertyDeviceControlPID = "]) {
                    return;
                }
                
                // Reset
                self.logMonitor.lastMicClient = 0;
                
                // Init regex
                NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern:@"=\\s*(\\d+)\\s*;" options:0 error:nil];
                
                // Match on pid
                match = [regex firstMatchInString:logEvent.composedMessage options:0 range:NSMakeRange(0, logEvent.composedMessage.length)];
                if((nil == match) || (NSNotFound == match.range.location)) {
                    return;
                }
                
                // Extract/convert pid
                pid = [[logEvent.composedMessage substringWithRange:[match rangeAtIndex:1]] integerValue];
                if((0 == pid) || (-1 == pid)) {
                    return;
                }
                
                // Save
                self.logMonitor.lastMicClient = pid;
                NSLog(@"Detected microphone activation by PID: %ld", (long)pid);
            }
        }];
    }
    // Previous versions of macOS
    else {
        NSLog(@"< macOS 13.3+: Using 'com.apple.SystemStatus'");
        
        // Start logging
        logMonitorStarted = [self.logMonitor start:[NSPredicate predicateWithFormat:@"subsystem=='com.apple.SystemStatus'"] 
                                             level:Log_Level_Default 
                                          callback:^(OSLogEvent* logEvent) {
            @synchronized (self) {
                // Only interested in "Server data changed..." msgs
                if(YES != [logEvent.composedMessage containsString:@"Server data changed for media domain"]) {
                    return;
                }
                
                // Parse audio attributions from the log message
                for(NSString* __strong line in [logEvent.composedMessage componentsSeparatedByString:@"\n"]) {
                    NSNumber* pid = 0;
                    
                    // Trim
                    line = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                    
                    // Look for audio attributions
                    if([line hasPrefix:@"audioAttributions = "] || [line hasPrefix:@"audioRecordingAttributions = "]) {
                        // This is the start of audio attributions list
                        continue;
                    }
                    
                    // Look for audit token with PID
                    if([line containsString:@"<BSAuditToken:"]) {
                        // PID extraction regex
                        NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern:@"(?<=PID: )[0-9]*" options:0 error:nil];
                        
                        // Match/extract pid
                        NSTextCheckingResult* match = [regex firstMatchInString:line options:0 range:NSMakeRange(0, line.length)];
                        if((nil != match) && (NSNotFound != match.range.location)) {
                            pid = @([[line substringWithRange:[match rangeAtIndex:0]] intValue]);
                            if(pid.intValue > 0) {
                                self.logMonitor.lastMicClient = pid.integerValue;
                                NSLog(@"Detected microphone activation by PID: %@", pid);
                            }
                        }
                    }
                }
            }
        }];
    }
    
    if(!logMonitorStarted) {
        NSLog(@"ERROR: Failed to start log monitor - process identification will not work");
    }
}

- (void)handleConnectedDeviceNotification:(NSNotification*)notification {
    AVCaptureDevice* device = notification.object;
    
    NSLog(@"New device connected: %@", device.localizedName);
    
    if([device hasMediaType:AVMediaTypeAudio]) {
        [self watchAudioDevice:device];
    }
}

- (void)handleDisconnectedDeviceNotification:(NSNotification*)notification {
    AVCaptureDevice* device = notification.object;
    
    NSLog(@"Device disconnected: %@", device.localizedName);
    
    if([device hasMediaType:AVMediaTypeAudio]) {
        [self unwatchAudioDevice:device];
    }
}

- (BOOL)watchAudioDevice:(AVCaptureDevice*)device {
    OSStatus status = -1;
    AudioObjectID deviceID = 0;
    AudioObjectPropertyAddress propertyStruct = {0};
    
    propertyStruct.mSelector = kAudioDevicePropertyDeviceIsRunningSomewhere;
    propertyStruct.mScope = kAudioObjectPropertyScopeGlobal;
    propertyStruct.mElement = kAudioObjectPropertyElementMain;
    
    AudioObjectPropertyListenerBlock listenerBlock = ^(UInt32 inNumberAddresses, const AudioObjectPropertyAddress *inAddresses) {
        NSInteger state = [self getMicState:device];
        
        NSLog(@"Mic: %@ changed state to %ld", device.localizedName, (long)state);
        
        // macOS 13.3+ - use this as trigger
        if(@available(macOS 13.3, *)) {
            if(0 == state) {
                // Audio off
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    [self sendMicrophoneEvent:NO withPID:0];
                });
            }
            else if(1 == state) {
                // Audio on
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    // Use the PID from log monitor
                    NSInteger pid = (self.logMonitor.lastMicClient > 0) ? self.logMonitor.lastMicClient : 0;
                    [self sendMicrophoneEvent:YES withPID:pid];
                });
            }
        }
    };
    
    deviceID = [self getAVObjectID:device];
    if(0 == deviceID) {
        NSLog(@"ERROR: failed to find %@'s object id", device.localizedName);
        return NO;
    }
    
    status = AudioObjectAddPropertyListenerBlock(deviceID, &propertyStruct, self.eventQueue, listenerBlock);
    if(noErr != status) {
        NSLog(@"ERROR: AudioObjectAddPropertyListenerBlock() failed with %d", status);
        return NO;
    }
    
    self.audioListeners[device.uniqueID] = listenerBlock;
    
    NSLog(@"Monitoring %@ (uuid: %@ / %x) for audio changes", device.localizedName, device.uniqueID, deviceID);
    
    return YES;
}

- (BOOL)unwatchAudioDevice:(AVCaptureDevice*)device {
    OSStatus status = -1;
    AudioObjectID deviceID = 0;
    AudioObjectPropertyAddress propertyStruct = {0};
    
    propertyStruct.mSelector = kAudioDevicePropertyDeviceIsRunningSomewhere;
    propertyStruct.mScope = kAudioObjectPropertyScopeGlobal;
    propertyStruct.mElement = kAudioObjectPropertyElementMain;
    
    AudioObjectPropertyListenerBlock listenerBlock = self.audioListeners[device.uniqueID];
    if(nil == listenerBlock) {
        return NO;
    }
    
    deviceID = [self getAVObjectID:device];
    if(0 == deviceID) {
        NSLog(@"ERROR: failed to find %@'s object id", device.localizedName);
        return NO;
    }
    
    status = AudioObjectRemovePropertyListenerBlock(deviceID, &propertyStruct, self.eventQueue, listenerBlock);
    if(noErr != status) {
        NSLog(@"ERROR: AudioObjectRemovePropertyListenerBlock() failed with %d", status);
        return NO;
    }
    
    [self.audioListeners removeObjectForKey:device.uniqueID];
    
    NSLog(@"Stopped monitoring %@ for audio changes", device.localizedName);
    
    return YES;
}

- (void)sendMicrophoneEvent:(BOOL)isActive withPID:(NSInteger)pid {
    NSMutableDictionary* event = [NSMutableDictionary dictionary];
    
    event[@"timestamp"] = [NSDateFormatter localizedStringFromDate:[NSDate date] 
                                                         dateStyle:NSDateFormatterMediumStyle 
                                                         timeStyle:NSDateFormatterMediumStyle];
    event[@"event"] = isActive ? @"microphone_activated" : @"microphone_deactivated";
    event[@"device"] = self.builtInMic.localizedName ?: @"Unknown Microphone";
    
    if(isActive && pid > 0) {
        NSString* processPath = [ProcessUtils getProcessPath:(pid_t)pid];
        NSString* processName = [ProcessUtils getProcessName:processPath];
        
        event[@"process"] = @{
            @"name": [ProcessUtils valueForStringItem:processName],
            @"pid": @(pid),
            @"path": [ProcessUtils valueForStringItem:processPath]
        };
        
        NSLog(@"Microphone activated by: %@ (PID: %ld)", processName, (long)pid);
    }
    else if(isActive && pid == 0) {
        NSLog(@"Microphone activated but process could not be identified");
    }
    
    if(self.eventCallback) {
        self.eventCallback(event);
    }
}

- (AVCaptureDevice*)findBuiltInMic {
    AVCaptureDevice* builtInMic = nil;
    
    AVCaptureDeviceDiscoverySession* discoverySession = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInMicrophone] mediaType:AVMediaTypeAudio position:AVCaptureDevicePositionUnspecified];
    
    for(AVCaptureDevice* currentMic in discoverySession.devices) {
        NSLog(@"Device: %@/%@/%@", currentMic.manufacturer, currentMic.localizedName, currentMic.uniqueID);
        
        if([currentMic.manufacturer isEqualToString:@"Apple Inc."]) {
            if([currentMic.uniqueID isEqualToString:@"BuiltInMicrophoneDevice"] ||
               [currentMic.localizedName isEqualToString:@"Built-in Microphone"]) {
                builtInMic = currentMic;
                break;
            }
        }
    }
    
    if(!builtInMic) {
        builtInMic = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
        NSLog(@"Apple Mic not found, defaulting to default device: %@/%@", builtInMic.manufacturer, builtInMic.localizedName);
    }
    
    return builtInMic;
}

- (UInt32)getMicState:(AVCaptureDevice*)device {
    OSStatus status = -1;
    AudioObjectID deviceID = 0;
    UInt32 isRunning = 0;
    UInt32 propertySize = sizeof(isRunning);
    
    AudioObjectPropertyAddress propertyStruct = {0};
    propertyStruct.mSelector = kAudioDevicePropertyDeviceIsRunningSomewhere;
    propertyStruct.mScope = kAudioObjectPropertyScopeGlobal;
    propertyStruct.mElement = kAudioObjectPropertyElementMain;
    
    deviceID = [self getAVObjectID:device];
    if(0 == deviceID) {
        NSLog(@"ERROR: failed to find %@'s object id", device.localizedName);
        return -1;
    }
    
    status = AudioObjectGetPropertyData(deviceID, &propertyStruct, 0, NULL, &propertySize, &isRunning);
    if(noErr != status) {
        NSLog(@"ERROR: failed to get run state for %@ (error: %#x)", device.localizedName, status);
        return -1;
    }
    
    return isRunning;
}

- (UInt32)getAVObjectID:(AVCaptureDevice*)device {
    UInt32 objectID = 0;
    SEL methodSelector = NSSelectorFromString(@"connectionID");
    
    if(![device respondsToSelector:methodSelector]) {
        return 0;
    }
    
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wpointer-to-int-cast"
    #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    objectID = (UInt32)[device performSelector:methodSelector withObject:nil];
    #pragma clang diagnostic pop
    
    return objectID;
}

@end 