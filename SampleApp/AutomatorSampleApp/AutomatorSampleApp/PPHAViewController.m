//
//  PPHAViewController.m
//  AutomatorSampleApp
//
//  Created by Erceg,Boris on 4/9/14.
//  Copyright (c) 2014 PayPal. All rights reserved.
//

#import "PPHAViewController.h"

@interface PPHAViewController ()
@property (weak, nonatomic) IBOutlet UILabel *label;
@property (weak, nonatomic) IBOutlet UIButton *button;

@end

@implementation PPHAViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.labelText = @"Button Pressed";
    self.label.text = nil;
	// Do any additional setup after loading the view, typically from a nib.
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(setLabelTextFromNotificationDict:) name:@"bridgeNotification" object:nil];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)setLabelTextFromNotificationDict:(NSNotification *)notification {
    self.labelText = notification.userInfo[@"labelText"];
}

- (IBAction)buttonPressed:(id)sender {
    if (self.label.text) {
        self.label.text = nil;
        [self.button setTitle:@"Press Button" forState:UIControlStateNormal];
    } else {
        [self.button setTitle:@"Clear Label" forState:UIControlStateNormal];
        [self.label setText:self.labelText];
    }
    
}


@end
