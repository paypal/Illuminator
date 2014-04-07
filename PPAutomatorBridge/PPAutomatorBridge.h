//
//  PPAutomatorBridge.h
//  PPHCore
//
//  Created by Erceg,Boris on 10/8/13.
//  Copyright 2013 PayPal. All rights reserved.
//

#import <Foundation/Foundation.h>

#ifdef DEBUG

@class PPAutomatorBridge;
@class PPAutomatorBridgeAction;

////////////////////////////////////////////////////////////////////////////////////////////////////
@protocol PPAutomatorBridgeDelegate <NSObject>

- (NSDictionary *)automationBridge:(PPAutomatorBridge *)bridge receivedAction:(PPAutomatorBridgeAction *)action;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////
@interface PPAutomatorBridgeAction : NSObject
@property (nonatomic, strong) NSString *selector;
@property (nonatomic, strong) NSDictionary *arguments;
- (NSDictionary *)resultFromTarget:(id)target;
@end


////////////////////////////////////////////////////////////////////////////////////////////////////
@interface PPAutomatorBridge : NSObject {

}
+ (instancetype)bridge;

- (void)startAutomationBridgeWithDelegate:(id <PPAutomatorBridgeDelegate>)delegate;
- (void)stopAutomationBridge;
- (NSDictionary *)receivedMessage:(NSString *)message;
@property (nonatomic, assign) BOOL isActivated;
@end

#endif
