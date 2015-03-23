//
//  PPHAAppDelegate.m
//  AutomatorSampleApp
//
//  Created by Erceg,Boris on 4/9/14.
//  Copyright (c) 2014 PayPal. All rights reserved.
//

#import "PPHAAppDelegate.h"
#import "PPAutomationBridge.h"
#import "PPHABridgeDelegate.h"

////////////////////////////////////////////////////////////////////////////////////////////////////
@interface PPHAAppDelegate ()
#ifdef UIAUTOMATION_BUILD
@property (nonatomic, strong) PPHABridgeDelegate *bridgeDelegate;
#endif
@end

////////////////////////////////////////////////////////////////////////////////////////////////////
@implementation PPHAAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
#ifdef UIAUTOMATION_BUILD
    //Creating bridge delegate object
    self.bridgeDelegate = [PPHABridgeDelegate new];
    //Starting bridge and assigning delegate
    [[PPAutomationBridge bridge] startAutomationBridgeWithDelegate:self.bridgeDelegate];
#endif
    return YES;
}

@end
