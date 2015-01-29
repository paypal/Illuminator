//
//  PPHATableDataObject.h
//  AutomatorSampleApp
//
//  Created by Erceg,Boris on 29/01/15.
//  Copyright (c) 2015 PayPal. All rights reserved.
//

#import <Foundation/Foundation.h>

////////////////////////////////////////////////////////////////////////////////////////////////////
@interface PPHATableDataObject : NSObject
@property (nonatomic, strong) NSString *title;
@property (nonatomic, copy) void (^selectionBlock)();

+ (instancetype)tableObjectWithTitle:(NSString *)title selectionBlock:(void (^)())selectionBlock;
@end
