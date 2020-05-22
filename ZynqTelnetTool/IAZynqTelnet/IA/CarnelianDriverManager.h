/*!
 *	Copyright 2015 Apple Inc. All rights reserved.
 *
 *	APPLE NEED TO KNOW CONFIDENTIAL
 *
 *  CarnelianDriverManager.h
 *  CarnelianDriver
 *
 */

#import <Foundation/Foundation.h>
#import <CoreTestFoundation/CoreTestFoundation.h>

@interface CarnelianDriverManager : NSObject<CTPluginProtocol>

- (void)connect:(CTTestContext *)context;

- (void)disconnect:(CTTestContext *)context;

- (void)isConnected:(CTTestContext *)context;

- (void)sendCommand:(CTTestContext *)context;

@property (strong) NSMutableDictionary *managedConnections;

@end
