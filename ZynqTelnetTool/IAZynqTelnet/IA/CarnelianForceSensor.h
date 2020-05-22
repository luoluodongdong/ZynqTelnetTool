/*!
 *	Copyright 2015 Apple Inc. All rights reserved.
 *
 *	APPLE NEED TO KNOW CONFIDENTIAL
 *
 *  CarnelianForceSensor.h
 *  CarnelianDriver
 *
 */

#import <Foundation/Foundation.h>
#import <CoreTestFoundation/CoreTestFoundation.h>
#import <AtlasCommunication/AtlasCommunication.h>

@interface CarnelianForceSensor : NSObject<CTPluginProtocol>

@property id<ATKDataChannel> uart;

- (void)connect:(CTTestContext *)context;
- (void)disconnect:(CTTestContext *)context;
- (void)makeSamples:(CTTestContext *)context;

@end
