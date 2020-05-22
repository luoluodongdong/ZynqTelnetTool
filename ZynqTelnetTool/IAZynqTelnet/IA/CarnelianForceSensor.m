/*!
 *  Copyright 2015 Apple Inc. All rights reserved.
 *
 *  APPLE NEED TO KNOW CONFIDENTIAL
 */

#import "CarnelianForceSensor.h"
#define myDomain @"com.Apple.HWTE.CarnelianForceSensor"

@implementation CarnelianForceSensor

- (instancetype)init
{
    self = [super init];

    if (self)
    {
        // enter initialization code here
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
    if(self.uart != nil) {
        if([self.uart isOpened]) {
            NSError *error;
            [self.uart close:&error];
            if(error != nil) {
                CTLog(CTLOG_LEVEL_ERR, @"%@", [error localizedDescription]);
                return CTRecordStatusFail;
            }
        }
    }
    return YES;
}

- (CTCommandCollection *)commmandDescriptors
{
    CTCommandCollection *collection = [CTCommandCollection new];
    CTCommandDescriptor *command = [[CTCommandDescriptor alloc] initWithName:@"makeSamples" selector:@selector(makeSamples:) description:@"Get N samples"];

    [command addParameter:@"numSamples" type:CTParameterDescriptorTypeNumber defaultValue:@(1) allowedValues:nil required:YES description:@"number of samples"];

    [collection addCommand:command];
    
    command = [[CTCommandDescriptor alloc] initWithName:@"connect" selector:@selector(connect:) description:@"Connect to given port"];
    [command addParameter:@"url" type:CTParameterDescriptorTypeString defaultValue:nil allowedValues:nil required:YES description:@"Port url"];
    [command addParameter:@"timeout" type:CTParameterDescriptorTypeNumber defaultValue:@(5) allowedValues:nil required:NO description:@"Connect timeout"];
    [command addParameter:@"options" type:CTParameterDescriptorTypeDictionary defaultValue:@{} allowedValues:nil required:NO description:@"Options"];
    [collection addCommand:command];
    
    command = [[CTCommandDescriptor alloc] initWithName:@"disconnect" selector:@selector(disconnect:) description:@"Disconnects"];
    [collection addCommand:command];

    return collection;
}

- (void)connect:(CTTestContext *)context
{
    [context runTestWithNames:@[context.pluginName, @"makeSamples"]
                     priority:CTRecordPriorityRequired
                         test:^CTRecordStatus (NSError *__autoreleasing *error)
     {
        if(context.parameters[@"url"] == nil) {
            *error = [NSError errorWithDomain:myDomain code:-1
                                     userInfo:@{ NSLocalizedDescriptionKey : @"context has no url" }];
            CTLog(CTLOG_LEVEL_ERR, @"%@", [*error localizedDescription]);
            return CTRecordStatusFail;
        }
        NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"uart://%@",context.parameters[@"url"]]];
        if(url == nil) {
            *error = [NSError errorWithDomain:myDomain code:-1
                                     userInfo:@{ NSLocalizedDescriptionKey : [NSString stringWithFormat:@"Failed to make url from %@", context.parameters[@"url"]] }];
            CTLog(CTLOG_LEVEL_ERR, @"%@", [*error localizedDescription]);
            return CTRecordStatusFail;
        }
        NSDictionary *options;
        options = context.parameters[@"options"];
        //Force sensor should be 9600 8N1.
        
        CTLog(CTLOG_LEVEL_INFO, @"CarnelianForceSensor connect: %@ options: %@", [url description], [options description]);
        
        self.uart = createUARTChannel(url, options, error);
        if(self.uart == nil) {
            CTLog(CTLOG_LEVEL_ERR, @"%@", [*error localizedDescription]);
            return CTRecordStatusFail;
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
        
        CTLog(CTLOG_LEVEL_INFO, @"CarnelianForceSensor connected");
        return CTRecordStatusPass;
     }];

}

- (void)disconnect:(CTTestContext *)context
{
    [context runTestWithNames:@[context.pluginName, @"makeSamples"]
                     priority:CTRecordPriorityRequired
                         test:^CTRecordStatus (NSError *__autoreleasing *error)
     {
         if([self.uart isOpened]) {
             [self.uart close:error];
             if(*error != nil) {
                 CTLog(CTLOG_LEVEL_ERR, @"%@", [*error localizedDescription]);
                 return CTRecordStatusFail;
             }
         } else {
             CTLog(CTLOG_LEVEL_INFO, @"CarnelianForceSensor already disconnected");
         }
         
         CTLog(CTLOG_LEVEL_INFO, @"CarnelianForceSensor disconnected");
         return CTRecordStatusPass;
     }];
}

- (void)makeSamples:(CTTestContext *)context
{
    [context runTestWithNames:@[context.pluginName, @"makeSamples"]
                     priority:CTRecordPriorityRequired
                         test:^CTRecordStatus (NSError *__autoreleasing *error)
    {
        int numSamples = [context.parameters[@"numSamples"] intValue];
        //The default sensor is at 10 samples/second, so we should timeout in numSamples/10 seconds
        double timeout = numSamples/10;
        if(context.parameters[@"timeout"] != nil) {
            timeout = [context.parameters[@"timeout"] doubleValue];
        }
        
        NSMutableData *responseData = [[NSMutableData alloc] init];
        
        //We can't just sample lines because we often get fragments of lines not at the newline markers, so we have to glom it all together then re-separate
        NSDate* startTime = [NSDate date];
        while(true) {
            //Take a sample and concatenate directly
            NSData *returnData = [self.uart readWithTimeout:timeout error:error];
            if(*error != nil) {
                CTLog(CTLOG_LEVEL_ERR, @"%@", [*error localizedDescription]);
                return CTRecordStatusFail;
            }
            [responseData appendData:returnData];
            if([startTime timeIntervalSinceNow] < (timeout * -1)) {
                //Timeout
                break;
            }
        }
        
        //Trim nulls from the data stream because we get stuff like <00000000 00000030 2e303036 400d3d2b 3030302e 30303640 0d3d2b30...>
        NSMutableData *cleanedData = [[NSMutableData alloc] init];
        for(int i = 0; i < [responseData length]; i++) {
            if(((char*)[responseData bytes])[i] != (char)0x00) {
                [cleanedData appendBytes:&[responseData bytes][i] length:1];
            }
        }
        NSString *responseString = [NSString stringWithCString:[cleanedData bytes] encoding:NSASCIIStringEncoding];
        CTLog(CTLOG_LEVEL_INFO, @"CarnelianForceSensor_makeSamples RECV: %@", responseString);

        //Chop into lines
        NSArray *lines = [responseString componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
        //Check if we have enough lines
        if([lines count] < numSamples) {
            *error = [NSError errorWithDomain:myDomain
                                         code:-1
                                     userInfo:@{NSLocalizedDescriptionKey : @"Insufficient lines to match sample count. Increase timeout?"}];
            CTLog(CTLOG_LEVEL_ERR, @"%@", [*error localizedDescription]);
            return CTRecordStatusFail;
        }
        
        //Parse to get lines. We get lines of format: =+000.022@
        NSMutableArray *rawData = [[NSMutableArray alloc] init];
        double sum = 0;
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"=([+-][0-9]*\\.[0-9]*)@"
                                                                               options:0
                                                                                 error:error];
        if(*error != nil) {
            CTLog(CTLOG_LEVEL_ERR, @"%@", [*error localizedDescription]);
            return CTRecordStatusFail;
        }
        
        for(NSString* line in lines) {
            NSArray<NSTextCheckingResult*> *matches = [regex matchesInString:line options:0 range:NSMakeRange(0, [line length])];
            if([matches count] != 1) {
                //Skip this malformed line
//                CTLog(CTLOG_LEVEL_INFO, @"Found %lu matches instead of 1 in line %@", (unsigned long)[matches count],line);
                continue;
            }
            if([matches[0] numberOfRanges] != 2) {
                //Skip this malformed line
                continue;
            }
            NSString *numPart = [line substringWithRange:[matches[0] rangeAtIndex:1]];
            double value = [numPart doubleValue];
            [rawData addObject:@(value)];
            sum += value;
        }
        context.output = @{
                           @"raw" : rawData,
                           @"avg" : @(sum/[rawData count])
                           };
        return CTRecordStatusPass;
    }];
}

@end
