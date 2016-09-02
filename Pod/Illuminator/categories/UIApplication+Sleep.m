//
//  UIApplication+Sleep.m
//  KIF
//
//  Created by Eric Firestone on 5/20/11.
//  Licensed to Square, Inc. under one or more contributor license agreements.
//  See the LICENSE file distributed with this work for the terms under
//  which Square, Inc. licenses this file to you.
//
#import "UIApplication+Sleep.h"
//#import <objc/runtime.h>
//#import <Foundation/Foundation.h>
#import <KIF/UIApplication-KIFAdditions.h>
//#import <KIF/KIF.h>

void KIFSleep(CFTimeInterval seconds) {
    NSLog(@"KIFSleep UIApplicationCurrentRunMode %@ (default %@)", UIApplicationCurrentRunMode, kCFRunLoopDefaultMode);
    CFRunLoopRunInMode(UIApplicationCurrentRunMode ?: kCFRunLoopDefaultMode, seconds, false);
    //CFRunLoopRunInMode([[UIApplication sharedApplication] currentRunLoopMode] ?: kCFRunLoopDefaultMode, seconds, false);
}
