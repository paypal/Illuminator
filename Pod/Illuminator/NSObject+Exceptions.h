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

@interface NSObject (Exceptions)

+ (void)pcall:(IlluminatorEmptyBlock)tryBlock catchBlock:(IlluminatorExceptionBlock)catchBlock finally:(IlluminatorEmptyBlock)finallyBlock;
@end
