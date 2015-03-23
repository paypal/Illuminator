//
//  PPHABridgeDelegate.m
//  AutomatorSampleApp
//
//  Created by Erceg,Boris on 4/9/14.
//  Copyright (c) 2014 PayPal. All rights reserved.
//

#ifdef UIAUTOMATION_BUILD
#import "PPHABridgeDelegate.h"
#import "PPHAAppDelegate.h"

////////////////////////////////////////////////////////////////////////////////////////////////////
@implementation PPHABridgeDelegate

- (NSDictionary *)automationBridge:(PPAutomationBridge *)bridge receivedAction:(PPAutomationBridgeAction *)action {
    return [action resultFromTarget:self];
}

- (NSDictionary *)addRowToMainMenu:(NSDictionary *)parameters {
    //just pass with notification center as example
    [[NSNotificationCenter defaultCenter] postNotificationName:kPPHABridgeNotification object:nil userInfo:parameters];
    return nil;
}


- (NSDictionary *)exampleWithReturnValue:(NSDictionary *)parameters {
    //just return whatever you get
    return parameters;
}

- (NSDictionary *)resetToMainMenu {
    PPHAAppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
    [appDelegate.mainNavController popToRootViewControllerAnimated:NO];
    return nil;
}

@end
#endif