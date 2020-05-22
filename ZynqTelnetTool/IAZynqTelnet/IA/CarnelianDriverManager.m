/*!
 *  Copyright 2015 Apple Inc. All rights reserved.
 *
 *  APPLE NEED TO KNOW CONFIDENTIAL
 */

#import "CarnelianDriverIA.h"
#import "CarnelianDriverManager.h"
#define myDomain @"com.Apple.HWTE.CarnelianDriverManager"

@implementation CarnelianDriverManager

- (instancetype)init
{
    self = [super init];

    if (self)
    {
        self.managedConnections = [[NSMutableDictionary alloc] init];
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
    CTCommandCollection *collection = [CTCommandCollection new];
    CTCommandDescriptor *command = [[CTCommandDescriptor alloc] initWithName:@"connect"
                                                                    selector:@selector(connect:)
                                                                 description:@"Connects to the given IP and port and saves as a particular id"];
    
    [command addParameter:@"id"
                     type:CTParameterDescriptorTypeString
             defaultValue:nil
            allowedValues:nil
                 required:YES
              description:@"Unique identifier for this connection"];
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
                                            description:@"Disconnects all open connections"];
    [command addParameter:@"id"
                     type:CTParameterDescriptorTypeString
             defaultValue:nil
            allowedValues:nil
                 required:YES
              description:@"Unique identifier for this connection"];
    [collection addCommand:command];
    
    command = [[CTCommandDescriptor alloc] initWithName:@"listConnections"
                                               selector:@selector(listConnections:)
                                            description:@"Lists all open connections"];
    [collection addCommand:command];
    
    command = [[CTCommandDescriptor alloc] initWithName:@"isConnected"
                                               selector:@selector(isConnected:)
                                            description:@"Checks if connection is live. returns {result : true/false}"];
    [command addParameter:@"id"
                     type:CTParameterDescriptorTypeString
             defaultValue:nil
            allowedValues:nil
                 required:YES
              description:@"Unique identifier for this connection"];
    [collection addCommand:command];
    
    command = [[CTCommandDescriptor alloc] initWithName:@"sendCommand"
                                               selector:@selector(sendCommand:)
                                            description:@"Sends a command string. Auto-parses responses if any"];
    [command addParameter:@"id"
                     type:CTParameterDescriptorTypeString
             defaultValue:nil
            allowedValues:nil
                 required:YES
              description:@"Unique identifier for this connection"];
    [command addParameter:@"command"
                     type:CTParameterDescriptorTypeString
             defaultValue:nil
            allowedValues:nil
                 required:YES
              description:@"string command to send. transaction ID will be added separately"];
    [collection addCommand:command];
    
    return collection;}


- (void)connect:(CTTestContext *)context
{
    [context runTest:^CTRecordStatus (NSError *__autoreleasing *error) {
        if(self.managedConnections[context.parameters[@"id"]] != nil) {
            *error = [NSError errorWithDomain:myDomain code:-1
                                     userInfo:@{ NSLocalizedDescriptionKey : @"Connection id already exists." }];
            CTLog(CTLOG_LEVEL_ERR, @"%@", [*error localizedDescription]);
            return CTRecordStatusFail;
        }
        return CTRecordStatusPass;
    }];
    
    //Create a new CarnelianDriverIA plugin
    CarnelianDriverIA *newPlugin = [[CarnelianDriverIA alloc] init];
    self.managedConnections[context.parameters[@"id"]] = newPlugin;
    [self.managedConnections[context.parameters[@"id"]] connect:context];
    //FIXME: Add protection against connection fails. Remove the open connection.
}

- (void)disconnect:(CTTestContext *)context
{
    [context runTest:^CTRecordStatus (NSError *__autoreleasing *error) {
        if(self.managedConnections[context.parameters[@"id"]] == nil) {
            *error = [NSError errorWithDomain:myDomain code:-1
                                     userInfo:@{ NSLocalizedDescriptionKey : @"Connection id doesn't exist." }];
            CTLog(CTLOG_LEVEL_ERR, @"%@", [*error localizedDescription]);
            return CTRecordStatusFail;
        }
        return CTRecordStatusPass;
    }];
    
    [self.managedConnections[context.parameters[@"id"]] disconnect:context];
    //Remove this as it's disconnected
    self.managedConnections[context.parameters[@"id"]] = nil;
}

- (void)listConnections:(CTTestContext *)context
{
    [context runTest:^CTRecordStatus (NSError *__autoreleasing *error) {
        context.output = [self.managedConnections allKeys];
        CTLog(CTLOG_LEVEL_INFO, @"Open Connections: %@", [context.output description]);
        return CTRecordStatusPass;
    }];
}

- (void)isConnected:(CTTestContext *)context
{
    [context runTest:^CTRecordStatus (NSError *__autoreleasing *error) {
        if(self.managedConnections[context.parameters[@"id"]] == nil) {
            context.output = @(FALSE);
        }
        return CTRecordStatusPass;
    }];
    if(context.output != nil) {
        [self.managedConnections[context.parameters[@"id"]] isConnected:context];
    }
    //FIXME: Add protection against connection fails. Remove the open connection.
}

- (void)sendCommand:(CTTestContext *)context
{
    [context runTest:^CTRecordStatus (NSError *__autoreleasing *error) {
        if(self.managedConnections[context.parameters[@"id"]] == nil) {
            *error = [NSError errorWithDomain:myDomain code:-1
                                     userInfo:@{ NSLocalizedDescriptionKey : @"Connection id doesn't exist." }];
            CTLog(CTLOG_LEVEL_ERR, @"%@", [*error localizedDescription]);
            return CTRecordStatusFail;
        }
        return CTRecordStatusPass;
    }];
    
    [self.managedConnections[context.parameters[@"id"]] sendCommand:context];
}

@end
