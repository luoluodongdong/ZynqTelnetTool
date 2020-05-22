/*!
 *	Copyright 2016 Apple Inc. All rights reserved.
 *
 *	APPLE NEED TO KNOW CONFIDENTIAL
 */

#import <Foundation/Foundation.h>

@protocol EZTelnetStreamListener <NSObject>

- (void)receiveStandardInData:(NSString *)str;
- (void)receiveStandardOutData:(NSString *)str;
- (void)receiveStandardErrorData:(NSString *)str;
 
@end

@interface EZTelnet : NSObject

+ (instancetype)ezTelnetWithURL:(NSURL *)url;
+ (instancetype)ezTelnetWithHost:(NSString *)host port:(unsigned)port;
- (bool)openConnectionWithTimeout:(NSTimeInterval)timeout connectionClosedHandler:(void (^)(NSError *))handler error:(NSError *__autoreleasing *)err;

- (bool)write:(NSString *)str waitForRegexMatch:(NSString *)regex_str timeout:(NSTimeInterval)timeo response:(NSString *__autoreleasing *)response;
- (void)close;

@property (strong) NSString *lineSeparator;                 /* by default is '\n' */
@property (weak) id<EZTelnetStreamListener> telnetListener; /* listeners to receive raw stdout and stderr data */

//Path to where the telnet binary is
@property (strong) NSString *launchPath;

@end
