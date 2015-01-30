//
//  PPHAViewController.m
//  AutomatorSampleApp
//
//  Created by Erceg,Boris on 4/9/14.
//  Copyright (c) 2014 PayPal. All rights reserved.
//

#import "PPHAMainMenuViewController.h"
#import "PPHATableDataObject.h"
#import "PPHABridgeDelegate.h"

#define kCustomKeyboardSegue @"CustomKeyboard"
#define kSearchingElementsSegue @"SearchingElements"
#define kWaitForMeSegue @"WaitForMe"

static NSString *cellIdentifier = @"automatorRules";

////////////////////////////////////////////////////////////////////////////////////////////////////
@interface PPHAMainMenuViewController () <UITableViewDelegate, UITableViewDataSource>
@property (weak, nonatomic) IBOutlet UILabel *label;
@property (weak, nonatomic) IBOutlet UIButton *button;
@property (nonatomic, strong) NSMutableArray *datasource;
@property (weak, nonatomic) IBOutlet UITableView *tableView;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////
@implementation PPHAMainMenuViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:cellIdentifier];
    [self buildDatasource];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(bridgeCallReceived:) name:kPPHABridgeNotification object:nil];
}

-(void)viewDidDisappear:(BOOL)animated {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kPPHABridgeNotification object:nil];
    [super viewDidDisappear:animated];
}



#pragma mark -
#pragma mark bridge

- (void)bridgeCallReceived:(NSNotification *)parameters {
    NSString *title = @"Row Added via Bridge";
    NSDictionary *payload = parameters.userInfo;
    if (payload && payload[@"title"]) {
        title = payload[@"title"];
    }
    [self.datasource addObject:[PPHATableDataObject tableObjectWithTitle:title selectionBlock:nil]];
    [self.tableView reloadData];
}


#pragma mark -
#pragma mark helpers

- (void)buildDatasource {
    __weak typeof(self) weakSelf = self;
    NSMutableArray *tableDatasource = [NSMutableArray array];
    [tableDatasource addObject:[PPHATableDataObject tableObjectWithTitle:@"Searching Elements" selectionBlock:^{
        [weakSelf performSegueWithIdentifier:kSearchingElementsSegue sender:weakSelf];
    }]];
    [tableDatasource addObject:[PPHATableDataObject tableObjectWithTitle:@"Wait For Me" selectionBlock:^{
        [weakSelf performSegueWithIdentifier:kWaitForMeSegue sender:weakSelf];
    }]];
    
    [tableDatasource addObject:[PPHATableDataObject tableObjectWithTitle:@"Crash The App" selectionBlock:^{
        NSString *crashMe = nil;
        NSArray __unused *crashArray = @[crashMe];
    }]];
    
    [tableDatasource addObject:[PPHATableDataObject tableObjectWithTitle:@"Custom Keyboard" selectionBlock:^{
        [weakSelf performSegueWithIdentifier:kCustomKeyboardSegue sender:weakSelf];
    }]];
    
    self.datasource = tableDatasource;
    [self.tableView reloadData];
}

- (PPHATableDataObject *)tableObjectAtIndexPath:(NSIndexPath *)indexPath {
    return [self.datasource objectAtIndex:indexPath.row];
}

#pragma mark -
#pragma mark UITableViewDelegate

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    PPHATableDataObject *tableObject = [self tableObjectAtIndexPath:indexPath];
    if (tableObject.selectionBlock) {
        tableObject.selectionBlock();
    }
}

-(BOOL)tableView:(UITableView *)tableView shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath {
    return [[self tableObjectAtIndexPath:indexPath] selectionBlock] != nil;
}
#pragma mark -
#pragma mark UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.datasource.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier forIndexPath:indexPath];
    cell.textLabel.text = [[self tableObjectAtIndexPath:indexPath] title];
    return cell;
}

@end





