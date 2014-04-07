//
//  PPAutomationBridge.h
//  PPHCore
//
//  Created by Erceg,Boris on 10/8/13.
//  Copyright 2013 PayPal. All rights reserved.
//

#import <Foundation/Foundation.h>

#ifdef DEBUG

@class PPAutomationBridge;
@class PPAutomationBridgeAction;

////////////////////////////////////////////////////////////////////////////////////////////////////
@protocol PPAutomationBridgeDelegate <NSObject>

- (NSDictionary *)automationBridge(PPAutomationBridge *)bridge receivedAction:(PPAutomationBridgeAction *)action;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////
@interface PPAutomationBridgeAction : NSObject
@property (nonatomic, strong) NSString *selector;
@property (nonatomic, strong) NSDictionary *arguments;
- (NSDictionary *)resultFromTarget:(id)target;
@end


////////////////////////////////////////////////////////////////////////////////////////////////////
@interface PPAutomationBridge : NSObject {

}
+ (instancetype)bridge;

- (void)startAutomationBridgeWithDelegate:(id <PPAutomationBridgeDelegate>)delegate;
- (void)stopAutomationBridge;
- (NSDictionary *)receivedMessage:(NSString *)message;
@property (nonatomic, assign) BOOL isActivated;
@end

#endif
