//
//  ProcessUtils.m
//  MicMonitor
//
//  Lightweight process identification utilities
//  Extracted from OverSight
//

#import "ProcessUtils.h"

@implementation ProcessUtils

+ (NSString*)getProcessPath:(pid_t)pid {
    NSString* processPath = nil;
    char pathBuffer[PROC_PIDPATHINFO_MAXSIZE] = {0};
    int status = -1;
    
    int mib[3] = {0};
    unsigned long systemMaxArgs = 0;
    char* taskArgs = NULL;
    int numberOfArgs = 0;
    size_t size = 0;
    
    memset(pathBuffer, 0x0, PROC_PIDPATHINFO_MAXSIZE);
    
    status = proc_pidpath(pid, pathBuffer, sizeof(pathBuffer));
    if(0 != status) {
        processPath = [NSString stringWithUTF8String:pathBuffer];
    }
    else {
        mib[0] = CTL_KERN;
        mib[1] = KERN_ARGMAX;
        
        size = sizeof(systemMaxArgs);
        
        if(-1 == sysctl(mib, 2, &systemMaxArgs, &size, NULL, 0)) {
            goto bail;
        }
        
        taskArgs = malloc(systemMaxArgs);
        if(NULL == taskArgs) {
            goto bail;
        }
        
        mib[0] = CTL_KERN;
        mib[1] = KERN_PROCARGS2;
        mib[2] = pid;
        
        size = (size_t)systemMaxArgs;
        
        if(-1 == sysctl(mib, 3, taskArgs, &size, NULL, 0)) {
            goto bail;
        }
        
        if(size <= sizeof(int)) {
            goto bail;
        }
        
        memcpy(&numberOfArgs, taskArgs, sizeof(numberOfArgs));
        
        processPath = [NSString stringWithUTF8String:taskArgs + sizeof(int)];
    }
    
bail:
    if(NULL != taskArgs) {
        free(taskArgs);
        taskArgs = NULL;
    }
    
    return processPath;
}

+ (NSString*)getProcessName:(NSString*)path {
    NSString* processName = nil;
    NSBundle* appBundle = nil;
    
    appBundle = [self findAppBundle:path];
    if(nil != appBundle) {
        processName = [appBundle infoDictionary][@"CFBundleName"];
    }
    
    if(nil == processName) {
        processName = [path lastPathComponent];
    }
    
    return processName;
}

+ (NSBundle*)findAppBundle:(NSString*)binaryPath {
    NSBundle* appBundle = nil;
    NSString* appPath = nil;
    
    appPath = [[binaryPath stringByStandardizingPath] stringByResolvingSymlinksInPath];
    
    do {
        appBundle = [NSBundle bundleWithPath:appPath];
        
        if((nil != appBundle) && 
           (YES == [appBundle.executablePath isEqualToString:binaryPath])) {
            break;
        }
        
        appBundle = nil;
        appPath = [appPath stringByDeletingLastPathComponent];
        
    } while((nil != appPath) && 
            (YES != [appPath isEqualToString:@"/"]) && 
            (YES != [appPath isEqualToString:@""]));
    
    return appBundle;
}

+ (NSString*)valueForStringItem:(NSString*)item {
    return (nil != item) ? item : @"unknown";
}

@end 