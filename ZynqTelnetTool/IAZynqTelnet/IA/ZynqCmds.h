//
//  ZynqCmds.h
//  CarnelianDriver
//
//  Created by Yang Gu on 1/30/18.
//  Copyright © 2018 Apple. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZynqTCP.h"

@interface ZynqCmds : NSObject

@property (strong) ZynqTCP* connection;

/*!
 @brief Establishes tcp connection
 */
-(NSDictionary*) connect:(NSDictionary*)config withError:(NSError**)err;

/*!
 @brief Closes the tcp connection
 */
-(NSDictionary*) disconnect:(NSDictionary*)config withError:(NSError**)err;

/*!
 @brief Checks if the connection is open
 */
-(NSDictionary*) isConnected:(NSDictionary*)config withError:(NSError**)err;

/*!
 @brief Direct pass-through
 */
-(NSDictionary*) directCommand:(NSDictionary*)config withError:(NSError**)err;

/*!
 @brief Parses string response into data
 */
-(NSDictionary*)parseResp:(NSString*)input withError:(NSError**)err;
@end
