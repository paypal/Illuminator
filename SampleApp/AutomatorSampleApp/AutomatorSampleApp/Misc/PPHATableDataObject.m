//
//  PPHATableDataObject.m
//  AutomatorSampleApp
//
//  Created by Erceg,Boris on 29/01/15.
//  Copyright (c) 2015 PayPal. All rights reserved.
//

#import "PPHATableDataObject.h"

////////////////////////////////////////////////////////////////////////////////////////////////////
@implementation PPHATableDataObject

+(instancetype)tableObjectWithTitle:(NSString *)title selectionBlock:(void (^)())selectionBlock {
    PPHATableDataObject *tableObject = [[self alloc] init];
    tableObject.title = title;
    tableObject.selectionBlock = selectionBlock;
    return tableObject;
}

@end
