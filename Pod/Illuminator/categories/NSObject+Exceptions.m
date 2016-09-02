//
//  NSObject+Exceptions.m
//  Pods
//
//  Created by Erceg, Boris on 26/10/15.
//
//

#import "UIApplication+Sleep.h"
#import "NSObject+Exceptions.h"

@implementation NSObject (Exceptions)

- (void)protectedSwiftCall:(IlluminatorEmptyBlock)tryBlock catchBlock:(IlluminatorExceptionBlock)catchBlock finally:(IlluminatorEmptyBlock)finallyBlock {
    @try {
        tryBlock();
    }
    @catch (NSException *exception) {
        if (catchBlock) {
            catchBlock(exception);
        }
    }
    @catch (id) {
        if (catchBlock) {
            catchBlock(nil);
        }
    }
    @finally {
        if (finallyBlock) {
            finallyBlock();
        }
    }
}


- (void)repeatedNonblockingSwiftCall:(IlluminatorEmptyBlock)tryBlock shouldContinueBlock:(IlluminatorEmptyBlockConditional)shouldContinueBlock completionBlock:(IlluminatorEmptyBlock)completionBlock  {
    
    BOOL notYetLooped = false;  // guarantee at least one run
    
    while (notYetLooped || shouldContinueBlock()) {
        notYetLooped = true;
        tryBlock();
        KIFSleep(IlluminatorSleepInterval);
    }
    
    completionBlock();
}

@end
