//
//  PPHACustomKeyboardViewController.m
//  AutomatorSampleApp
//
//  Created by Erceg,Boris on 29/01/15.
//  Copyright (c) 2015 PayPal. All rights reserved.
//

#import "PPHACustomKeyboardViewController.h"
#import "PPHAInputView.h"

@interface PPHACustomKeyboardViewController ()
@property (weak, nonatomic) IBOutlet UITextField *textField;
@property (strong, nonatomic) IBOutlet PPHAInputView *inputView;

@end

@implementation PPHACustomKeyboardViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.textField setInputView:self.inputView];
    [self.inputView setInput:self.textField];
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
