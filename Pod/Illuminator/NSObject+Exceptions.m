//
//  NSObject+Exceptions.m
//  Pods
//
//  Created by Erceg, Boris on 26/10/15.
//
//

#import "NSObject+Exceptions.h"

@implementation NSObject (Exceptions)

+ (void)tryBlock:(IlluminatorEmptyBlock)tryBlock catchBlock:(IlluminatorExceptionBlock)catchBlock finally:(IlluminatorEmptyBlock)finallyBlock {
    @try {
        tryBlock();
    }
    @catch (NSException *exception) {
        if (catchBlock) {
            catchBlock(exception);
        }
    }
    @finally {
        if (finallyBlock) {
            finallyBlock();
        }
    }
}


+ (void)throwException:(NSException *)exception {
    @throw exception;
}
@end
