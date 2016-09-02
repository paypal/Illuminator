//
//  NSObject+Exceptions.h
//  Pods
//
//  Created by Erceg, Boris on 26/10/15.
//
//

#import <Foundation/Foundation.h>

typedef void (^IlluminatorExceptionBlock)(NSException *);
typedef void (^IlluminatorEmptyBlock)();
typedef BOOL (^IlluminatorEmptyBlockConditional)();

NSTimeInterval IlluminatorSleepInterval = 0.1;

@interface NSObject (Exceptions)

+ (void)protectedSwiftCall:(IlluminatorEmptyBlock)tryBlock catchBlock:(IlluminatorExceptionBlock)catchBlock finally:(IlluminatorEmptyBlock)finallyBlock;


+ (void)repeatedNonblockingSwiftCall:(IlluminatorEmptyBlock)tryBlock shouldContinueBlock:(IlluminatorEmptyBlockConditional)shouldContinueBlock completionBlock:(IlluminatorEmptyBlock)completionBlock;
 
@end
