/*!
 *	Copyright 2015 Apple Inc. All rights reserved.
 *
 *	APPLE NEED TO KNOW CONFIDENTIAL
 *
 *  CarnelianGaugeBlock.h
 *  CarnelianDriver
 *
 */

#import <Foundation/Foundation.h>
#import <CoreTestFoundation/CoreTestFoundation.h>
#import <AtlasCommunication/AtlasCommunication.h>

@interface CarnelianGaugeBlock : NSObject<CTPluginProtocol>

@property id<ATKDataChannel> uart;

- (void)connect:(CTTestContext *)context;

- (void)disconnect:(CTTestContext *)context;

- (void)sendCommand:(CTTestContext *)context;

@end
