/*!
 *  Copyright 2015 Apple Inc. All rights reserved.
 *
 *  APPLE NEED TO KNOW CONFIDENTIAL
 */

#import "CarnelianGaugeBlock.h"
#define myDomain @"com.Apple.HWTE.CarnelianGaugeBlock"

@implementation CarnelianGaugeBlock

- (instancetype)init
{
    self = [super init];

    if (self)
    {
    }

    return self;
}

- (CTVersion *)version
{
    // Plugin version is first parameter (specified by plugin owner)
    // project build version is the version given by the build system (use compiler variable here)
    // short description is a string describing what your plugin does.
    CTVersion *version = [[CTVersion alloc] initWithVersion:@"1"
                                        projectBuildVersion:@"1"
                                           shortDescription:@"My short description"];

    return version;
}

- (BOOL)setupWithContext:(CTContext *)context error:(NSError *__autoreleasing *)error
{
    return YES;
}

- (BOOL)teardownWithContext:(CTContext *)context error:(NSError *__autoreleasing *)error
{
    [self disconnect:nil];
    return YES;
}

- (CTCommandCollection *)commmandDescriptors
{
    CTCommandCollection *collection = [CTCommandCollection new];
    CTCommandDescriptor *command = [[CTCommandDescriptor alloc] initWithName:@"sendCommand" selector:@selector(sendCommand:) description:@"Sends a command and reads response"];

    [command addParameter:@"command" type:CTParameterDescriptorTypeString defaultValue:@"HELP" allowedValues:nil required:YES description:@"Command to send"];

    [collection addCommand:command];
    
    command = [[CTCommandDescriptor alloc] initWithName:@"connect"
                                               selector:@selector(connect:)
                                            description:@"Connects to gauge block over uart"];
    [command addParameter:@"url"
                     type:CTParameterDescriptorTypeString
             defaultValue:@"dev/cu.usbserial-GAUGEBLOCK-EW"
            allowedValues:nil
                 required:NO
              description:@"URL of serial port"];
    [command addParameter:@"options"
                     type:CTParameterDescriptorTypeDictionary
             defaultValue:@{}
            allowedValues:nil
                 required:NO
              description:@"Options to connect, like baud rate"];
    [command addParameter:@"timeout"
                     type:CTParameterDescriptorTypeNumber
             defaultValue:@(5.0)
            allowedValues:nil
                 required:NO
              description:@"Seconds of timeout"];
    [collection addCommand:command];
    
    command = [[CTCommandDescriptor alloc] initWithName:@"disconnect"
                                               selector:@selector(disconnect:)
                                            description:@"Disconnects uart, if connected"];
    [collection addCommand:command];

    return collection;
}

- (void)connect:(CTTestContext *)context
{
    [context runTestWithNames:@[context.pluginName, @"command"]
                     priority:CTRecordPriorityRequired
                         test:^CTRecordStatus (NSError *__autoreleasing *error)
    {
        if(context.parameters[@"url"] == nil) {
            *error = [NSError errorWithDomain:myDomain code:-1
                                     userInfo:@{ NSLocalizedDescriptionKey : @"context has no url" }];
            CTLog(CTLOG_LEVEL_ERR, @"%@", [*error localizedDescription]);
            return FALSE;
        }
        NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"uart://%@",context.parameters[@"url"]]];
        if(url == nil) {
            *error = [NSError errorWithDomain:myDomain code:-1
                                     userInfo:@{ NSLocalizedDescriptionKey : [NSString stringWithFormat:@"Failed to make url from %@", context.parameters[@"url"]] }];
            CTLog(CTLOG_LEVEL_ERR, @"%@", [*error localizedDescription]);
            return FALSE;
        }
        NSDictionary *options;
        options = context.parameters[@"options"];
        
        CTLog(CTLOG_LEVEL_INFO, @"CarnelianGaugeBlock connect: %@ options: %@", [url description], [options description]);
        
        self.uart = createUARTChannel(url, options, error);
        if(self.uart == nil) {
            CTLog(CTLOG_LEVEL_ERR, @"%@", [*error localizedDescription]);
            return NO;
        }
        
        double timeout = 5.0;
        if(context.parameters[@"timeout"] != nil) {
            timeout = [context.parameters[@"timeout"] doubleValue];
        }
        
        [self.uart openWithTimeout:timeout error:error];
        if(*error != nil) {
            CTLog(CTLOG_LEVEL_ERR, @"%@", [*error localizedDescription]);
            return CTRecordStatusFail;
        }
        
        CTLog(CTLOG_LEVEL_INFO, @"CarnelianGaugeBlock connected");
        return CTRecordStatusPass;
    }];
}

- (void)disconnect:(CTTestContext *)context
{
    [context runTestWithNames:@[context.pluginName, @"command"]
                     priority:CTRecordPriorityRequired
                         test:^CTRecordStatus (NSError *__autoreleasing *error)
     {
         if(self.uart != nil) {
             if([self.uart isOpened]) {
                 NSError *error;
                 [self.uart close:&error];
                 if(error != nil) {
                     CTLog(CTLOG_LEVEL_ERR, @"%@", [error localizedDescription]);
                     return CTRecordStatusFail;
                 }
             } else {
                CTLog(CTLOG_LEVEL_INFO, @"CarnelianGaugeBlock was not open");
             }
             CTLog(CTLOG_LEVEL_INFO, @"CarnelianGaugeBlock is now disconnected");
         } else {
             CTLog(CTLOG_LEVEL_INFO, @"CarnelianGaugeBlock was not connected");
         }
         
         return CTRecordStatusPass;
     }];
}

- (void)sendCommand:(CTTestContext *)context
{
    [context runTestWithNames:@[context.pluginName, @"command"]
                     priority:CTRecordPriorityRequired
                         test:^CTRecordStatus (NSError *__autoreleasing *failureInfo)
    {
        NSString *command = context.parameters[@"command"];
        NSData *cmdData = [command dataUsingEncoding:NSUTF8StringEncoding];
        CTLog(CTLOG_LEVEL_INFO, @"CarnelianGaugeBlock_sendCommand SEND: %@", command);
        [self.uart write:cmdData error:failureInfo];
        if(*failureInfo != nil) {
            CTLog(CTLOG_LEVEL_ERR, @"%@", [*failureInfo localizedDescription]);
            return CTRecordStatusFail;
        }
        
        double timeout = 1.0;
        if(context.parameters[@"timeout"] != nil) {
            timeout = [context.parameters[@"timeout"] doubleValue];
        }
        
        NSMutableData *allReturns = [[NSMutableData alloc] init];
        while(true) {
            NSData *returnData = [self.uart readWithTimeout:timeout error:failureInfo];
            if([returnData length] > 0) {
                [allReturns appendData:returnData];
            } else {
                break;
            }
        }
        if(*failureInfo != nil) {
            CTLog(CTLOG_LEVEL_ERR, @"%@", [*failureInfo localizedDescription]);
            return CTRecordStatusFail;
        }
        NSString *response = [NSString stringWithCString:[allReturns bytes] encoding:NSUTF8StringEncoding];
        CTLog(CTLOG_LEVEL_INFO, @"CarnelianGaugeBlock_sendCommand RECV: %@", response);
        context.output = response;
        
        return CTRecordStatusPass;
    }];
}

@end
