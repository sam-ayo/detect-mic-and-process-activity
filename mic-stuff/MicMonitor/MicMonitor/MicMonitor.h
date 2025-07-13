//
//  MicMonitor.h
//  MicMonitor
//
//  Core microphone monitoring functionality
//  Extracted from OverSight
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreAudio/CoreAudio.h>
#import "LogMonitor.h"
#import "ProcessUtils.h"

@interface MicMonitor : NSObject

@property(nonatomic, retain) LogMonitor *logMonitor;
@property(nonatomic, retain) AVCaptureDevice *builtInMic;
@property(nonatomic, retain) NSMutableDictionary *audioListeners;
@property(nonatomic, retain) dispatch_queue_t eventQueue;
@property(nonatomic, copy) void (^eventCallback)(NSDictionary *event);

- (instancetype)initWithCallback:(void (^)(NSDictionary *event))callback;
- (void)start;
- (void)stop;
- (AVCaptureDevice *)findBuiltInMic;
- (BOOL)watchAudioDevice:(AVCaptureDevice *)device;
- (BOOL)unwatchAudioDevice:(AVCaptureDevice *)device;
- (UInt32)getMicState:(AVCaptureDevice *)device;
- (UInt32)getAVObjectID:(AVCaptureDevice *)device;

@end