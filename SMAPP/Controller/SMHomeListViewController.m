//
//  SMHomeListViewController.m
//  SMAPP
//
//  Created by Sichen on 14/5/19.
//  Copyright © 2019 RXP. All rights reserved.
//

#import "SMHomeListViewController.h"
#import "HMHomeManager+Share.h"
#import "Const.h"
#import "SMAlertView.h"
#import "SMHomeListTableViewCell.h"
#import "Masonry.h"
#import "SMHomeSettingViewController.h"
#import "UIViewController+Show.h"

@implementation SMHomeListViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.navigationItem.title = @"Home Settings";
    [self.navigationController.navigationBar setTitleTextAttributes:@{NSFontAttributeName : FONT_H2_BOLD}];

    CGRect frame = self.tableView.frame;
    self.tableView = [[UITableView alloc] initWithFrame:frame style:UITableViewStyleGrouped];
    self.tableView.backgroundColor = COLOR_BACKGROUND;
    self.tableView.tableFooterView = [[UIView alloc] init]; // remove the lines
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadHomes:) name:kDidUpdateHomeName object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadHomes:) name:kDidUpdateHome object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadHomes:) name:kDidUpdatePrimaryHome object:nil];
}

#pragma mark - Notification

- (void)reloadHomes:(NSNotification *)notification {
    [self.tableView reloadData];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    HMHomeManager *manager = [HMHomeManager sharedManager];
    return manager.homes.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    SMHomeListTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kSMHomeListTableViewCell];
    if (!cell) {
        cell = [[SMHomeListTableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:kUITableViewCell];
    }
    
    HMHomeManager *manager = [HMHomeManager sharedManager];
    HMHome *home = manager.homes[indexPath.row];
    cell.leftLabel.text = home.name;
    cell.selectedImageView.hidden = !home.isPrimary;
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 44;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 44;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    UITableViewHeaderFooterView *header = [tableView dequeueReusableHeaderFooterViewWithIdentifier:kUITableViewHeaderView];
    if (!header) {
        header = [[UITableViewHeaderFooterView alloc] initWithReuseIdentifier:kUITableViewHeaderView];
    }
    header.textLabel.text = @"Home list:";
    return header;
}

- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view forSection:(NSInteger)section {
    UITableViewHeaderFooterView *header = (UITableViewHeaderFooterView *)view;
    header.textLabel.font = FONT_BODY_BOLD;
    header.textLabel.textColor = COLOR_TITLE;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    HMHomeManager *manager = [HMHomeManager sharedManager];
    HMHome *home = manager.homes[indexPath.item];
    SMHomeSettingViewController *settingVC = [[SMHomeSettingViewController alloc] initWithHome:home];
    [self.navigationController pushViewController:settingVC animated:YES];
}

@end
