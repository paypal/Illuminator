//
//  PPAutomationBridge.h
//  PPHCore
//
//  Created by Erceg,Boris on 10/8/13.
//  Copyright 2013 PayPal. All rights reserved.
//
//
////////////////////////////////////////////////////////////////////////////////////////////////////
/**
 How To Use:
 
 - Add PPAutomationBridge class to your project
 - Make an object that conforms to PPAutomationBridgeDelegate protocol
 - Implement automationBridge:receivedAction: method (if you want default implementation type @see PPAutomationBridgeDelegate example
 - Start your bridge with startAutomationBridgeWithDelegate:
 
 For more information look at sample app implementation
 */
////////////////////////////////////////////////////////////////////////////////////////////////////

@import Foundation;

#ifdef DEBUG

@class PPAutomationBridge;
@class PPAutomationBridgeAction;

////////////////////////////////////////////////////////////////////////////////////////////////////
/**
 The delegate of PPAutomationBridge object must adopt PPAutomationBridgeDelegate protocol.
 */
@protocol PPAutomationBridgeDelegate <NSObject>

/**
 Enables PPAutomationBridge to send messages to application under test.
 Most general use case scenario is to make this method call [action resultFromTarget:self]; in PPAutomationBridgeDelegate and
 make PPAutomationBridgeDelegate object implement all methods you might get from PPAutomationBridge.

 Example:
    - (NSDictionary *)automationBridge:(PPAutomationBridge *)bridge receivedAction:(PPAutomationBridgeAction *)action {
        return [action resultFromTarget:self];
    }
 
 @param bridge PPAutomationBridge sending a message.
 @param action PPAutomationBridgeAction object describing message bridge wants to send.

 @return NSDictionary presenting data app returns to the testing framework trough bridge. nil is allowed value
 */
- (NSDictionary *)automationBridge:(PPAutomationBridge *)bridge receivedAction:(PPAutomationBridgeAction *)action;

@end


////////////////////////////////////////////////////////////////////////////////////////////////////
/**
 Represents message bridge wants to send to application under test
*/
@interface PPAutomationBridgeAction : NSObject

/**
 String representation of selector you want to excecute on target with resultFromTarget: or get a real 
 selector with NSSelectorFromString.
*/
@property (nonatomic, strong) NSString *selector;

/**
 Arguments passed to selector when calling it.
*/
@property (nonatomic, strong) NSDictionary *arguments;

/**
 Will perform selector on target with arguments and return result.

 @param target target to perform selector on.

 @return returns return value of performing selector on target.
 */
- (NSDictionary *)resultFromTarget:(id)target;

@end


////////////////////////////////////////////////////////////////////////////////////////////////////
/**
 The PPAutomationBridge class provides a singleton instance representing bridge that comunicates with 
 UIAutomation trough socket interface.
 */
@interface PPAutomationBridge : NSObject

/**
 Returns an object representing bridge.
 *
 @return A singleton object that represents the bridge.
 */
+ (instancetype)bridge;

/**
 Starts automation bridge advertising and registers delegate object to recive automation bridge messages
 Does not retain delegate, you have to do it yourself
 *
 @param delegate Object conforming to PPAutomationBridgeDelegate that will recive messages when bridge is called from UIAutomation
 */
- (void)startAutomationBridgeWithDelegate:(id <PPAutomationBridgeDelegate>)delegate;

/**
 Starts automation bridge advertising.
 */
- (void)stopAutomationBridge;

/**
 Perform a check if autoamtion bridge was started or not.
 Bridge is considered activated after it receives first message.
 */
@property (nonatomic, assign) BOOL isActivated;

@end

#endif
