//
//  ProcessUtils.h
//  MicMonitor
//
//  Lightweight process identification utilities
//  Extracted from OverSight
//

#import <Foundation/Foundation.h>
#import <libproc.h>
#import <sys/sysctl.h>

@interface ProcessUtils : NSObject

+ (NSString *)getProcessPath:(pid_t)pid;
+ (NSString *)getProcessName:(NSString *)path;
+ (NSString *)valueForStringItem:(NSString *)item;

@end