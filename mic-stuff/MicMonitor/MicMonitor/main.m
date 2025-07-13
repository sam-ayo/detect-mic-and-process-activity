//
//  main.m
//  MicMonitor
//
//  CLI entry point for lightweight microphone monitoring utility
//  Extracted from OverSight
//

#import <Foundation/Foundation.h>
#import <signal.h>
#import "MicMonitor.h"

static MicMonitor* micMonitor = nil;
static BOOL shouldExit = NO;

void signalHandler(int signal) {
    printf("\n"); // New line after ^C
    NSLog(@"Received signal %d, shutting down gracefully...", signal);
    shouldExit = YES;
    
    if(micMonitor) {
        [micMonitor stop];
    }
    
    exit(0);
}

void printUsage() {
    printf("MicMonitor - Lightweight Microphone Monitoring Utility\n");
    printf("Usage: MicMonitor [options]\n");
    printf("Options:\n");
    printf("  -h, --help     Show this help message\n");
    printf("  -v, --version  Show version information\n");
    printf("  -j, --json     Output events in JSON format (default)\n");
    printf("\nThis utility monitors microphone activation and identifies the process using it.\n");
    printf("Press Ctrl+C to stop monitoring.\n");
}

void printVersion() {
    printf("MicMonitor v1.0.0\n");
    printf("Lightweight microphone monitoring utility\n");
    printf("Extracted from OverSight by Objective-See\n");
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        
        for(int i = 1; i < argc; i++) {
            NSString* arg = [NSString stringWithUTF8String:argv[i]];
            
            if([arg isEqualToString:@"-h"] || [arg isEqualToString:@"--help"]) {
                printUsage();
                return 0;
            }
            else if([arg isEqualToString:@"-v"] || [arg isEqualToString:@"--version"]) {
                printVersion();
                return 0;
            }
            else if([arg isEqualToString:@"-j"] || [arg isEqualToString:@"--json"]) {
                
            }
            else {
                printf("Unknown option: %s\n", [arg UTF8String]);
                printUsage();
                return 1;
            }
        }
        
        signal(SIGINT, signalHandler);
        signal(SIGTERM, signalHandler);
        
        NSLog(@"Starting MicMonitor...");
        
        micMonitor = [[MicMonitor alloc] initWithCallback:^(NSDictionary* event) {
            
            NSError* error = nil;
            NSData* jsonData = [NSJSONSerialization dataWithJSONObject:event 
                                                               options:NSJSONWritingPrettyPrinted 
                                                                 error:&error];
            
            if(error) {
                NSLog(@"Error serializing JSON: %@", error.localizedDescription);
                return;
            }
            
            NSString* jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
            printf("%s\n", [jsonString UTF8String]);
            fflush(stdout);
        }];
        
        [micMonitor start];
        
        NSLog(@"MicMonitor started. Press Ctrl+C to stop.");
        
        NSRunLoop* runLoop = [NSRunLoop mainRunLoop];
        while(!shouldExit && [runLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]]) {
            
        }
        
        NSLog(@"MicMonitor stopped.");
    }
    
    return 0;
} 