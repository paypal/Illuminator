//
//  PPHABridgeDelegate.m
//  AutomatorSampleApp
//
//  Created by Erceg,Boris on 4/9/14.
//  Copyright (c) 2014 PayPal. All rights reserved.
//

#import "PPHABridgeDelegate.h"

@implementation PPHABridgeDelegate
- (NSDictionary *)automationBridge:(PPAutomationBridge *)bridge receivedAction:(PPAutomationBridgeAction *)action {
    return [action resultFromTarget:self];
}

@end
