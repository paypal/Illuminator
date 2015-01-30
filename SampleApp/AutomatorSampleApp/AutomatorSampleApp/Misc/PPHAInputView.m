//
//  PPHAInputView.m
//  AutomatorSampleApp
//
//  Created by Erceg,Boris on 29/01/15.
//  Copyright (c) 2015 PayPal. All rights reserved.
//

#import "PPHAInputView.h"

////////////////////////////////////////////////////////////////////////////////////////////////////
@interface PPHAInputView ()
@property (strong, nonatomic) IBOutlet UIView *contentView;
@property (nonatomic, strong) NSArray *buttonMapping;
@end

////////////////////////////////////////////////////////////////////////////////////////////////////
@implementation PPHAInputView
-(void)awakeFromNib {
    [[NSBundle mainBundle] loadNibNamed:@"PPHAInputView" owner:self options:nil];
    [self addSubview:self.contentView];
    self.buttonMapping = @[@"A",@"B",@"CD"];
}

- (IBAction)buttonTapped:(UIButton *)sender {
    NSUInteger index = sender.tag - 1000;
    NSString *text = self.buttonMapping[index];
    [self.input insertText:text];
}
@end
