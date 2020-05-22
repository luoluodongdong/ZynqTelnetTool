//
//  IACmds.m
//  CarnelianDriver
//
//  Created by Yang Gu on 1/30/18.
//  Copyright © 2018 Apple. All rights reserved.
//
//  Implements IA command system API

#import "ZynqCmds.h"
#define errDomain @"com.Apple.HWTE.ZynqCmds"

@interface ZynqCmds()
{
}

-(NSDictionary*)parseCSKV:(NSString*)input withError:(NSError**)err;
-(NSDictionary*)FOMfromKV:(NSDictionary*)input;
-(NSDictionary*)parseCSHB:(NSString*)input withError:(NSError**)err;
-(NSDictionary*)parseTimestamps:(NSString*)input withError:(NSError**)err;

//Converting between weird "second,millisecond" format and timeinterval
NSString* timeIntervalToCSV(NSTimeInterval input);
NSTimeInterval CSVtoTimeInterval(NSString* input);

@end

@implementation ZynqCmds

-(id) init
{
    self = [super init];
    self.connection = [[ZynqTCP alloc] init];
    self.connection.timeout = 3.0;
    return self;
}

-(NSDictionary*) connect:(NSDictionary*)config withError:(NSError**)err
{
    *err = [self.connection connectIP:config[@"ip"] port:config[@"port"]];
    return @{};
}

-(NSDictionary*) disconnect:(NSDictionary*)config withError:(NSError**)err
{
    *err = [self.connection disconnect];
    return @{};
}

-(NSDictionary*) isConnected:(NSDictionary*)config withError:(NSError**)err
{
    *err = nil;
    return @{@"result" : @(self.connection.isConnected)};
}

-(NSDictionary*) helloWorld:(NSDictionary*)config withError:(NSError**)err
{
    [self.connection send:@"hello world()" withError:err];
    return nil;
}

-(NSDictionary*) getSN:(NSDictionary*)config withError:(NSError**)err
{
    //FIXME: This command doesn't work on the board(?)
    NSString *resp = [self.connection send:@"sn(-r)" withError:err];
    if(*err) return @{};
    NSString *parsedResp = [self parseResp:resp withError:err][@"data"];
    if(*err) return @{};
    return @{@"result" : parsedResp};
}

-(NSDictionary*) getVersion:(NSDictionary*)config withError:(NSError**)err
{
    NSDictionary *result = nil;
    //Get the MCU Ver
    NSString *resp = [self.connection send:@"version(0)" withError:err];
    if(*err) return @{};
    NSString *parsedResp = [self parseResp:resp withError:err][@"data"];
    if(*err) return @{};
    
    //Remove excess '$\n'
    NSString *oneLineResp = [parsedResp stringByReplacingOccurrencesOfString:@"$\n" withString:@""];
    result = [self parseCSKV:oneLineResp withError:err];
    
    return result;
}

-(NSDictionary*) directCommand:(NSDictionary*)config withError:(NSError**)err
{
    //Get the MCU Ver
    NSString *resp = [self.connection send:config[@"command"] withError:err];
    NSDictionary *parsedResp = [self parseResp:resp withError:err];
    
    return parsedResp;
}

-(NSDictionary*) syncTime:(NSDictionary*)config withError:(NSError**)err
{
    //If config has key @"write" we'll sync board time to our time. Otherwise only read.
    //We compensate for network and propagation time by checking echo-back and then re-issuing with correction
    if(config[@"write"]) {
        //Measure time anomaly
        NSTimeInterval lockTime = CFAbsoluteTimeGetCurrent();
        NSString *timeString = timeIntervalToCSV(lockTime);
        
        NSString *resp = [self.connection send:[NSString stringWithFormat:@"synctime(-w,%@)",timeString] withError:err];
        if(*err) return @{};
        resp = [self.connection send:@"synctime(-r)" withError:err];
        if(*err) return @{};
        NSString *parsedResp = [self parseResp:resp withError:err][@"data"];
        if(*err) return @{};
        
        NSTimeInterval endTime = CSVtoTimeInterval(parsedResp);
        NSTimeInterval timeAnomaly = endTime - lockTime;
        NSLog(@"Time Anomaly: %.3f", timeAnomaly);
        
        //Re-write, with time anomaly added
        lockTime = CFAbsoluteTimeGetCurrent() + timeAnomaly;
        timeString = timeIntervalToCSV(lockTime);
        resp = [self.connection send:[NSString stringWithFormat:@"synctime(-w,%@)",timeString] withError:err];
        if(*err) return @{};
    }
    
    NSDictionary *result = nil;

    NSString *resp = [self.connection send:@"synctime(-r)" withError:err];
    if(*err) return @{};
    NSTimeInterval nowTime = CFAbsoluteTimeGetCurrent();
    NSString *parsedResp = [self parseResp:resp withError:err][@"data"];
    if(*err) return @{};
    NSTimeInterval boardTime = CSVtoTimeInterval(parsedResp);
    NSTimeInterval timeAnomaly = nowTime - boardTime;
    
    //Parse into actual numeric
    result = @{@"result" : @(boardTime), @"anomaly" : @(timeAnomaly)};
    
    return result;
}

#pragma mark -
#pragma mark Parsing Functions
-(NSDictionary*)parseResp:(NSString*)input withError:(NSError**)err
{
    //Parse out either:
    //ACK(<DONE or ERROR>;num,num,num,num,num)
    //ACK(<reply data>;<DONE or ERROR>;num,num,num,num,num)
    //The first pair of num,num are the seconds and milliseconds timestamps of operation start
    //The second pair of num,num are the seconds and milliseconds timestamps of operation end
    //The last num is elapsed time in milliseconds
    
    //Parse out the ACK()
    NSRegularExpression *ackExpr =[NSRegularExpression regularExpressionWithPattern:@"ACK\\((.*)\\)" options:0 error:err];
    if(*err) return nil;
    NSArray *matches = [ackExpr matchesInString:input options:0 range:NSMakeRange(0, [input length])];
    if([matches count] == 0) {
        *err = [NSError errorWithDomain:errDomain
                                   code:-1
                               userInfo:@{NSLocalizedDescriptionKey : @"Did not match ACK() in response"}];
        return nil;
    }
    
    NSString *acklessString = [input substringWithRange:[matches[0] rangeAtIndex:1]];
    
    //Break by semicolons
    NSArray *semicolonSeparatedString = [acklessString componentsSeparatedByString:@";"];
    
    //We should have either 2 or 3 sections
    NSMutableDictionary *returnDict = [[NSMutableDictionary alloc] init];
    NSString *dataString; //Holds some kind of string-encoded data, if any
    NSString *resultString; //Holds DONE/ERROR, if any
    NSMutableDictionary *data; //Holds parsed data, if any
    switch([semicolonSeparatedString count])
    {
        case 3: ///< data>;<DONE or ERROR>;num,num,num,num,num
            //Try to parse the data returned. If not, return it as a string.
            //Known formats include:
            //key = value unit,key = value unit,...
            //hex,hex,hex,hex,...
            //message
            @try {
                dataString = semicolonSeparatedString[0];
                data = [[NSMutableDictionary alloc] init];
                data[@"data"] = dataString;
                [data addEntriesFromDictionary:[self parseCSKV:dataString withError:err]];
                if(*err) return nil;
                [data addEntriesFromDictionary:[self parseCSHB:dataString withError:err]];
                if(*err) return nil;
            }
            @catch(NSException *exception) {
                *err = [NSError errorWithDomain:errDomain
                                           code:-1
                                       userInfo:@{NSLocalizedDescriptionKey : [NSString stringWithFormat:@"Error while parsing data. %@", [exception description]]}];
                return nil;
            }
            [returnDict addEntriesFromDictionary:data];
            //We fall through here to case 2 to parse the rest
        case 2: ///< or ERROR>;num,num,num,num,num
            @try {
                //Try to determine if it's DONE or ERROR. If it's neither, error out.
                resultString = semicolonSeparatedString[[semicolonSeparatedString count] - 2];
                returnDict[@"result"] = resultString;
                if([resultString compare:@"DONE"] == NSOrderedSame) {
                    returnDict[@"error"] = @FALSE; //For compatibility
                } else if([resultString compare:@"ERROR"] == NSOrderedSame) {
                    returnDict[@"error"] = @TRUE; //For compatibility
                } else {
                    //We don't know what this result is. We should just fail outright
                    *err = [NSError errorWithDomain:errDomain
                                               code:-1
                                           userInfo:@{NSLocalizedDescriptionKey : @"Malformed response is not DONE or ERROR"}];
                    return nil;
                }
            }
            @catch(NSException *exception) {
                *err = [NSError errorWithDomain:errDomain
                                           code:-1
                                       userInfo:@{NSLocalizedDescriptionKey : [NSString stringWithFormat:@"Error while parsing result. %@", [exception description]]}];
                return nil;
            }
            
            [returnDict addEntriesFromDictionary:[self parseTimestamps:semicolonSeparatedString[[semicolonSeparatedString count] - 1] withError:err]];
            if(*err) return nil;
            break;
        default:
            //We don't have 2 or 3. What the heck. Return.
            *err = [NSError errorWithDomain:errDomain
                                       code:-1
                                   userInfo:@{NSLocalizedDescriptionKey : @"Malformed response does not have 2 or 3 semicolon-separated sections"}];
            return nil;
    }
    
    return [NSDictionary dictionaryWithDictionary:returnDict];
}

// Parses comma-separated key-value pairs (a=b,c=d,...)
-(NSDictionary*)parseCSKV:(NSString*)input withError:(NSError**)err
{
    @try {
        //Break by commas
        NSArray *entries = [input componentsSeparatedByString:@","];
        
        NSMutableDictionary *entriesDict = [[NSMutableDictionary alloc] init];
        
        //Pair by equal signs
        for(NSString *entry in entries) {
            NSArray *pair = [entry componentsSeparatedByString:@"="];
            if([pair count] != 2) continue;
            entriesDict[[pair[0] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]] = [pair[1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        }
        
        if([entriesDict count] == 0) return @{};
        
        //Attempt to parse it as foms
        NSDictionary *fomDict = [self FOMfromKV:entriesDict];
        
        return @{@"data_kv" : entriesDict, @"data_fom" : fomDict};
    } @catch (NSException *exception) {
        *err = [NSError errorWithDomain:errDomain
                                   code:-1
                               userInfo:@{NSLocalizedDescriptionKey : [NSString stringWithFormat:@"Error while trying to parse as comma-separated key-value pairs. %@", [exception description]]}];
        return @{};
    }
}

-(NSDictionary*)FOMfromKV:(NSDictionary*)input
{
    //Attempt to parse dictionary of format {"average " = " -2.7475214363313714 mV"} into {"average" : {"value" : NSNumber, "unit" : "mV"}}
    NSMutableDictionary *returnDict = [[NSMutableDictionary alloc] init];
    
    for(NSString *key in input) {
        //Attempt to detect spaces in the value string
        NSArray *components = [input[key] componentsSeparatedByString:@" "];
        if([components count] == 2) {
            NSCharacterSet* notDigits = [[NSCharacterSet characterSetWithCharactersInString:@"0123456789.-"] invertedSet];
            if ([components[0] rangeOfCharacterFromSet:notDigits].location == NSNotFound)
            {
                returnDict[key] = @{@"value" : @([components[0] doubleValue]), @"unit" : components[1]};
            }
            
        }
        if([components count] == 1) {
            NSCharacterSet* notDigits = [[NSCharacterSet characterSetWithCharactersInString:@"0123456789.-"] invertedSet];
            if ([components[0] rangeOfCharacterFromSet:notDigits].location == NSNotFound)
            {
                returnDict[key] = @{@"value" : @([components[0] doubleValue])};
            }
        }
    }

    return returnDict;
}

// Parses comma-separated hexadecimal bytes (ca,fe,ba,be,...)
-(NSDictionary*)parseCSHB:(NSString*)input withError:(NSError**)err
{
    Byte *buffer;
    @try {
        //Break by commas
        NSArray *entries = [input componentsSeparatedByString:@","];
        buffer = malloc(sizeof(Byte) * [entries count]);
        NSMutableData *tempData = [[NSMutableData alloc] init];
        
        //Parse out hex and tack on
        for(int i = 0; i < [entries count]; i++) {
            unsigned temp = 0;
            NSScanner *scanner = [NSScanner scannerWithString:entries[i]];
            [scanner setScanLocation:0];
            [scanner scanHexInt:&temp];
            memcpy(&buffer[i], &temp, sizeof(Byte));
        }
        [tempData appendBytes:buffer length:(sizeof(Byte) * [entries count])];
        return @{@"data_hex" : tempData};
    } @catch (NSException *exception) {
        *err = [NSError errorWithDomain:errDomain
                                   code:-1
                               userInfo:@{NSLocalizedDescriptionKey : [NSString stringWithFormat:@"Error while trying to parse as comma-separated key-value pairs. %@", [exception description]]}];
        return @{};
    } @finally {
        free(buffer);
    }
}

-(NSDictionary*)parseTimestamps:(NSString*)input withError:(NSError**)err
{
    NSTimeInterval startTime, endTime, elapsedTime; //Holds start/stop timestamps, if any
    NSArray *timeComponents;
    NSMutableDictionary *returnDict = [[NSMutableDictionary alloc] init];
    @try {
        //Try to determine the timestamps
        timeComponents = [input componentsSeparatedByString:@","];
        if([timeComponents count] != 5) {
            *err = [NSError errorWithDomain:errDomain
                                       code:-1
                                   userInfo:@{NSLocalizedDescriptionKey : @"Malformed response does not have 5 timestamp components"}];
            return nil;
        }
        
        //Stitch seconds,milliseconds into seconds.milliseconds
        startTime = [timeComponents[0] integerValue] + ([timeComponents[1] integerValue] / 1000.0);
        returnDict[@"startTime"] = @(startTime);
        endTime = [timeComponents[2] integerValue] + ([timeComponents[3] integerValue] / 1000.0);
        returnDict[@"endTime"] = @(endTime);
        elapsedTime = ([timeComponents[4] integerValue] / 1000.0);
        returnDict[@"elapsedTime"] = @(elapsedTime);
    }
    @catch(NSException *exception) {
        *err = [NSError errorWithDomain:errDomain
                                   code:-1
                               userInfo:@{NSLocalizedDescriptionKey : [NSString stringWithFormat:@"Error while parsing result. %@", [exception description]]}];
        return @{};
    }
    return returnDict;
}

#pragma mark -
#pragma mark Time Format Conversion
NSString* timeIntervalToCSV(NSTimeInterval input)
{
    NSString *whole = [NSString stringWithFormat:@"%.3f", input];
    return [whole stringByReplacingOccurrencesOfString:@"." withString:@","];
}

NSTimeInterval CSVtoTimeInterval(NSString* input)
{
    NSString *decimalRepresent = [input stringByReplacingOccurrencesOfString:@"," withString:@"."];
    return [decimalRepresent doubleValue];
}

@end
