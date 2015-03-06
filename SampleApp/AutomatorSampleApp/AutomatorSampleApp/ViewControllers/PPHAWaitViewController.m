//
//  PPHAWaitViewController.m
//  AutomatorSampleApp
//
//  Created by Erceg,Boris on 30/01/15.
//  Copyright (c) 2015 PayPal. All rights reserved.
//

#import "PPHAWaitViewController.h"

////////////////////////////////////////////////////////////////////////////////////////////////////
@interface PPHAWaitViewController ()
@property (weak, nonatomic) IBOutlet UILabel *messageLabel;
@property (nonatomic, strong) NSTimer *timer;
@end

////////////////////////////////////////////////////////////////////////////////////////////////////
@implementation PPHAWaitViewController

-(void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    self.timer = [NSTimer scheduledTimerWithTimeInterval:5 target:self selector:@selector(showLabel) userInfo:nil repeats:NO];
}
-(void)viewDidDisappear:(BOOL)animated {
    [self.timer invalidate];
    self.timer = nil;
    [super viewDidDisappear:animated];
}

- (void)showLabel {
    UILabel *newLabel = [[UILabel alloc] init];
    [newLabel setTranslatesAutoresizingMaskIntoConstraints:NO];
    newLabel.text = @"Thanks for waiting";
    newLabel.textAlignment = NSTextAlignmentCenter;
    [newLabel sizeToFit];
    [self.view addSubview:newLabel];
    UILabel *messageLabel = self.messageLabel;
    NSDictionary *bindings = NSDictionaryOfVariableBindings(newLabel, messageLabel);
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-20-[newLabel]-20-|" options:NSLayoutFormatAlignAllCenterX metrics:nil views:bindings]];
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[messageLabel]-20-[newLabel]" options:NSLayoutFormatAlignAllCenterX metrics:nil views:bindings]];
}

@end
