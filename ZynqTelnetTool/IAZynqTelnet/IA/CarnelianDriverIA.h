/*!
 *	Copyright 2015 Apple Inc. All rights reserved.
 *
 *	APPLE NEED TO KNOW CONFIDENTIAL
 *
 *  CarnelianDriverIA.h
 *  CarnelianDriver
 *
 */

#import <Foundation/Foundation.h>
#import <CoreTestFoundation/CoreTestFoundation.h>

@interface CarnelianDriverIA : NSObject<CTPluginProtocol>

- (void)connect:(CTTestContext *)context;

- (void)disconnect:(CTTestContext *)context;

- (void)isConnected:(CTTestContext *)context;

- (void)sendCommand:(CTTestContext *)context;

@end
