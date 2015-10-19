//
//  TestTest.m
//  Teletext
//
//  Created by Boris Erceg on 15/10/15.
//  Copyright © 2015 kviksilver. All rights reserved.
//

#import "XCTaggedTestCase.h"

static NSString *tag = nil;

@implementation XCTaggedTestCase

+ (NSArray<NSInvocation *> *)testInvocations {
    
    if (!tag) { return [super testInvocations]; }
    
    NSMutableArray<NSInvocation *> *invocations = [@[] mutableCopy];
    
    [[self testsForTag:tag] enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        SEL selector = NSSelectorFromString(obj);
        NSMethodSignature *signature = [self instanceMethodSignatureForSelector:selector];
        if (signature) {
            NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
            invocation.selector = selector;
            if (invocation) {
                [invocations addObject:invocation];
            }
        }
    }];
    return [invocations copy];
}


+ (NSDictionary<NSString *, NSArray<NSString *> *> *)taggedTests {
    return nil;
}

+ (NSArray<NSString *> *)testsForTag:(NSString *)tag {
    
    NSMutableArray<NSString *> *tests = [@[] mutableCopy];
    [[self taggedTests] enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, NSArray<NSString *> * _Nonnull obj, BOOL * _Nonnull stop) {
        if ([[obj filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id  _Nonnull evaluatedObject, NSDictionary<NSString *,id> * _Nullable bindings) {
            return  [evaluatedObject isEqualToString:tag];
        }]] count]) {
            [tests addObject:key];
        }
    }];
    return tests;
}

@end