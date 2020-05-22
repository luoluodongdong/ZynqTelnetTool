//
//  PanelViewController.h
//  NITool
//
//  Created by WeidongCao on 2020/5/19.
//  Copyright © 2020 WeidongCao. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface PanelViewController : NSViewController
{
    IBOutlet NSTextField *ipField;
    IBOutlet NSTextField *portField;
    IBOutlet NSTextField *timeoutField;
    IBOutlet NSButton *openBtn;
    
    IBOutlet NSTextView *inputTextView;
    IBOutlet NSButton *sendBtn;
    IBOutlet NSButton *clearBtn;
    
    IBOutlet NSTextView *logTextView;
}

-(IBAction)openBtnAction:(id)sender;
-(IBAction)sendBtnAction:(id)sender;
-(IBAction)clearBtnAction:(id)sender;

@end

NS_ASSUME_NONNULL_END
