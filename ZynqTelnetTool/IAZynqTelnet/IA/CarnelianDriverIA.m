/*!
 *	Copyright 2015 Apple Inc. All rights reserved.
 *
 *	APPLE NEED TO KNOW CONFIDENTIAL
 */

#import "CarnelianDriverIA.h"
#import "ZynqCmds.h"

@interface CarnelianDriverIA()
{
    ZynqCmds* myCmds;
}
@end

@implementation CarnelianDriverIA

- (instancetype)init
{
    self = [super init];

    if (self)
    {
        myCmds = [[ZynqCmds alloc] init];
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
    return YES;
}

- (CTCommandCollection *)commmandDescriptors
{
    // Collection contains descriptions of all the commands exposed by a plugin
    CTCommandCollection *collection = [CTCommandCollection new];
    // A command exposes its name, the selector to call, and a short description
    // Selector should take in one object of CTTestContext type
    CTCommandDescriptor *command = [[CTCommandDescriptor alloc] initWithName:@"connect"
                                                                    selector:@selector(connect:)
                                                                 description:@"Connects to the given IP"];

    // Commands can define the parameters they need
    [command addParameter:@"ip"
                     type:CTParameterDescriptorTypeString
             defaultValue:@"169.254.1.32"
            allowedValues:nil
                 required:YES
              description:@"ip address of the Zynq board"];
    [command addParameter:@"port"
                     type:CTParameterDescriptorTypeString
             defaultValue:@"7600"
            allowedValues:nil
                 required:YES
              description:@"port of the Zynq board"];
    [collection addCommand:command];

    
    command = [[CTCommandDescriptor alloc] initWithName:@"disconnect"
                                               selector:@selector(disconnect:)
                                            description:@"Disconnects"];

    [collection addCommand:command];
    
    command = [[CTCommandDescriptor alloc] initWithName:@"isConnected"
                                               selector:@selector(isConnected:)
                                            description:@"Checks if connection is live. returns {result : true/false}"];
    [collection addCommand:command];
    
    command = [[CTCommandDescriptor alloc] initWithName:@"sendCommand"
                                               selector:@selector(sendCommand:)
                                            description:@"Sends a command string. Auto-parses responses if any"];
    [command addParameter:@"command"
                     type:CTParameterDescriptorTypeString
             defaultValue:nil
            allowedValues:nil
                 required:YES
              description:@"string command to send. transaction ID will be added separately"];
    [collection addCommand:command];
    
    return collection;
}

- (void)connect:(CTTestContext *)context
{
    [context runTest:^CTRecordStatus (NSError *__autoreleasing *error) {
        [myCmds connect:context.parameters withError:error];
        if(*error != nil) {
            CTLog(CTLOG_LEVEL_ERR, @"%@", [*error localizedDescription]);
        }
        return (*error == nil)?CTRecordStatusPass:CTRecordStatusFail;
    }];
}

- (void)disconnect:(CTTestContext *)context
{
    [context runTest:^CTRecordStatus (NSError *__autoreleasing *error) {
        [myCmds disconnect:context.parameters withError:error];
        if(*error != nil) {
            CTLog(CTLOG_LEVEL_ERR, @"%@", [*error localizedDescription]);
        }
        return (*error == nil)?CTRecordStatusPass:CTRecordStatusFail;
    }];
}

- (void)isConnected:(CTTestContext *)context
{
    [context runTest:^CTRecordStatus (NSError *__autoreleasing *error) {
        context.output = [myCmds isConnected:context.parameters withError:error];
        //Returns @{@"result" : @(self.connection.isConnected)}
        if(*error != nil) {
            CTLog(CTLOG_LEVEL_ERR, @"%@", [*error localizedDescription]);
        }
        return (*error == nil)?CTRecordStatusPass:CTRecordStatusFail;
    }];
}

- (void)sendCommand:(CTTestContext *)context
{
    [context runTest:^CTRecordStatus (NSError *__autoreleasing *error) {
        context.output = [myCmds directCommand:context.parameters withError:error];
        //Returns @{@"result" : @(self.connection.isConnected)}
        if(*error != nil) {
            CTLog(CTLOG_LEVEL_ERR, @"%@", [*error localizedDescription]);
        }
        return (*error == nil)?CTRecordStatusPass:CTRecordStatusFail;
    }];
}

@end
