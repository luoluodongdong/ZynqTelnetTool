//
//  ZynqTCP.h
//  CarnelianDriver
//
//  Created by Yang Gu on 1/26/18.
//  Copyright © 2018 Apple. All rights reserved.
//
//  This class implements a TCP/IP connection to a FCT-station-like Zynq board.

#import <Foundation/Foundation.h>

@interface ZynqTCP : NSObject

-(NSError*)connectIP:(NSString*)ip port:(NSString*)port;
-(NSError*)disconnect;

/*!
 @brief Sends a command string and gets a response. Handles the transaction-id layer
 */
-(NSString*)send:(NSString*)input withError:(NSError**)err;

@property (readwrite) NSTimeInterval timeout;

@property (readwrite) BOOL isConnected;

@end
