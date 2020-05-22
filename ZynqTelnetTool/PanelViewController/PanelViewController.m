//
//  PanelViewController.m
//  NITool
//
//  Created by WeidongCao on 2020/5/19.
//  Copyright © 2020 WeidongCao. All rights reserved.
//

#import "PanelViewController.h"
#import "ZynqTCP.h"
#import "ZynqCmds.h"

@interface PanelViewController ()

@property ZynqTCP* myTCP;
@property ZynqCmds* myCmds;
@property dispatch_queue_t printLogQueue;

@end

@implementation PanelViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.
    self.printLogQueue = dispatch_queue_create("com.zynqtelnettool.pringlogqueue", DISPATCH_QUEUE_SERIAL);
    self.myTCP = [[ZynqTCP alloc] init];
}
-(void)viewWillAppear{
    
}
-(void)viewDidAppear{
    
}

-(IBAction)openBtnAction:(id)sender{
    if ([openBtn.title isEqualToString:@"Open"]) {
        NSString *ip = [ipField stringValue];
        NSString *port = [portField stringValue];
        double to = [timeoutField doubleValue];
        self.myTCP.timeout = to;
        NSError *err = [self.myTCP connectIP:ip port:port];
        if(err){
            NSLog(@"ERR: %@", [err description]);
            dispatch_async(self.printLogQueue, ^{
                [self performSelectorOnMainThread:@selector(updateLog:) withObject:[err description] waitUntilDone:YES];
            });
        }else{
            [ipField setEnabled:NO];
            [portField setEnabled:NO];
            [timeoutField setEnabled:NO];
            [openBtn setTitle:@"Close"];
            dispatch_async(self.printLogQueue, ^{
                [self performSelectorOnMainThread:@selector(updateLog:) withObject:@"connected successfully!" waitUntilDone:YES];
            });
        }

    }else{
        NSError *err = [self.myTCP disconnect];
        if(err){
            NSLog(@"ERR: %@", [err description]);
            dispatch_async(self.printLogQueue, ^{
                [self performSelectorOnMainThread:@selector(updateLog:) withObject:[err description] waitUntilDone:YES];
            });
        }else{
            [ipField setEnabled:YES];
            [portField setEnabled:YES];
            [timeoutField setEnabled:YES];
            [openBtn setTitle:@"Open"];
            dispatch_async(self.printLogQueue, ^{
                [self performSelectorOnMainThread:@selector(updateLog:) withObject:@"disconnected successfully!" waitUntilDone:YES];
            });
        }
    }
    
}
-(IBAction)sendBtnAction:(id)sender{
    NSString *cmd = [inputTextView.textStorage string];
    [NSThread detachNewThreadWithBlock:^{
        NSError *err = nil;
        NSString *log = [NSString stringWithFormat:@"[TX]%@",cmd];
        dispatch_async(self.printLogQueue, ^{
            [self performSelectorOnMainThread:@selector(updateLog:) withObject:log waitUntilDone:YES];
        });
        NSString *response = [self.myTCP send:cmd withError:&err];
        if(err) NSLog(@"ERR: %@", [err description]);
        NSLog(@"Response: %@", response);
        log = [NSString stringWithFormat:@"[RX]%@",response];
        dispatch_async(self.printLogQueue, ^{
            [self performSelectorOnMainThread:@selector(updateLog:) withObject:log waitUntilDone:YES];
        });
    }];
}
-(IBAction)clearBtnAction:(id)sender{
    logTextView.string  = @"";
}
-(void)updateLog:(NSString *)log{
    NSUInteger textLen = self->logTextView.textStorage.length;
        if (textLen > 500000) {
            [self->logTextView.textStorage setAttributedString:[[NSAttributedString alloc] initWithString:@""]];
        }
    NSMutableString *logStr = [NSMutableString string];
    NSString *dateText = @"";
    //time
    NSDateFormatter *dateFormat=[[NSDateFormatter alloc] init];
    [dateFormat setDateFormat:@"yy/MM/dd HH:mm:ss.SSS "];
    dateText=[dateFormat stringFromDate:[NSDate date]];
    [logStr appendFormat:@"%@%@\r\n",dateText,log];
        // 设置字体颜色NSForegroundColorAttributeName，取值为 UIColor对象，默认值为黑色
        NSMutableAttributedString *textColor = [[NSMutableAttributedString alloc] initWithString:logStr];
    //        [textColor addAttribute:NSForegroundColorAttributeName
    //                          value:[NSColor greenColor]
    //                          range:[@"NSAttributedString设置字体颜色" rangeOfString:@"NSAttributedString"]];
        [textColor addAttribute:NSForegroundColorAttributeName
                          value:[NSColor systemGreenColor]
                          range:NSMakeRange(0, logStr.length)];
        
        //NSAttributedString *attrStr=[[NSAttributedString alloc] initWithString:self.logString];
        textLen = textLen + logStr.length;
        [self->logTextView.textStorage appendAttributedString:textColor];
        [self->logTextView scrollRangeToVisible:NSMakeRange(textLen,0)];
}
@end
