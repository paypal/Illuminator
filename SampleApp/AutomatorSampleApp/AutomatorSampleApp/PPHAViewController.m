//
//  PPHAViewController.m
//  AutomatorSampleApp
//
//  Created by Erceg,Boris on 4/9/14.
//  Copyright (c) 2014 PayPal. All rights reserved.
//

#import "PPHAViewController.h"
#import "PPHATableDataObject.h"

#define kCustomKeyboardSegue @"CustomKeyboard"
#define kScreenshotSegue @"Screenshot"
#define kSearchingElementsSegue @"SearchingElements"
#define kWaitForMeSegue @"WaitForMe"

static NSString *cellIdentifier = @"automatorRules";

////////////////////////////////////////////////////////////////////////////////////////////////////
@interface PPHAViewController () <UITableViewDelegate, UITableViewDataSource>
@property (weak, nonatomic) IBOutlet UILabel *label;
@property (weak, nonatomic) IBOutlet UIButton *button;
@property (nonatomic, strong) NSMutableArray *datasource;
@property (weak, nonatomic) IBOutlet UITableView *tableView;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////
@implementation PPHAViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:cellIdentifier];
    
    [self buildDatasource];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    
}

#pragma mark -
#pragma mark helpers

- (void)buildDatasource {
    __weak typeof(self) weakSelf = self;
    NSMutableArray *tableDatasource = [NSMutableArray array];
    [tableDatasource addObject:[PPHATableDataObject tableObjectWithTitle:@"Custom Keyboard" selectionBlock:^{
        [weakSelf performSegueWithIdentifier:kCustomKeyboardSegue sender:weakSelf];
    }]];
    [tableDatasource addObject:[PPHATableDataObject tableObjectWithTitle:@"Screenshot" selectionBlock:^{
        [weakSelf performSegueWithIdentifier:kScreenshotSegue sender:weakSelf];
    }]];
    [tableDatasource addObject:[PPHATableDataObject tableObjectWithTitle:@"Searching Elements" selectionBlock:^{
        [weakSelf performSegueWithIdentifier:kSearchingElementsSegue sender:weakSelf];
    }]];
    [tableDatasource addObject:[PPHATableDataObject tableObjectWithTitle:@"Crash The App" selectionBlock:^{
        
    }]];
    [tableDatasource addObject:[PPHATableDataObject tableObjectWithTitle:@"Wait For Me" selectionBlock:^{
        [weakSelf performSegueWithIdentifier:kWaitForMeSegue sender:weakSelf];
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





