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
@property (nonatomic, strong) PPHABridgeDelegate *bridgeDelegate;
@end

////////////////////////////////////////////////////////////////////////////////////////////////////
@implementation PPHAAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    //Creating bridge delegate object
    self.bridgeDelegate = [PPHABridgeDelegate new];
    //Starting bridge and assigning delegate
    [[PPAutomationBridge bridge] startAutomationBridgeWithDelegate:self.bridgeDelegate];
    
    return YES;
}

@end
