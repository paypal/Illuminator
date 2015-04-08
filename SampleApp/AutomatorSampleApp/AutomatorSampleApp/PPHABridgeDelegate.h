//
//  PPHABridgeDelegate.h
//  AutomatorSampleApp
//
//  Created by Erceg,Boris on 4/9/14.
//  Copyright (c) 2014 PayPal. All rights reserved.
//

@import Foundation;

#define kPPHABridgeNotification @"kPPHABridgeNotification"

#ifdef  UIAUTOMATION_BUILD

#import <Illuminator/PPAutomationBridge.h>

////////////////////////////////////////////////////////////////////////////////////////////////////

@interface PPHABridgeDelegate : NSObject <PPAutomationBridgeDelegate>

@end

#endif
