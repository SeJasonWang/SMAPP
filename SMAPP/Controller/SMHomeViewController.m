//
//  SMHomeViewController.m
//  SMAPP
//
//  Created by Sichen on 14/4/19.
//  Copyright © 2019 RXP. All rights reserved.
//

#import "SMHomeViewController.h"
#import "SMServiceViewController.h"
#import "SMTableViewCell.h"
#import "SMTableViewHeaderView.h"
#import "HMHomeManager+Share.h"
#import "Const.h"
#import "UIView+Extention.h"
#import "SMAlertView.h"
#import "Masonry.h"

@interface SMHomeViewController () <
HMHomeManagerDelegate,
HMHomeDelegate,
HMAccessoryDelegate
>

@property (nonatomic, strong) NSArray *dataList;

@end

@implementation SMHomeViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    HMHomeManager *namager = [HMHomeManager sharedManager];
    self.title = namager.primaryHome.name;

    namager.delegate = self;

    [self initNavigationItemWithLeftTitle:@"Homes"];
    
    [self initHeaderViewWithCompletionHandler:^(UIButton * _Nonnull leftButton, UIButton * _Nonnull rightButton) {
        [leftButton setTitle:@"Remove Home" forState:UIControlStateNormal];
        [rightButton setTitle:@"Add Home" forState:UIControlStateNormal];
        
        [leftButton addTarget:self action:@selector(removeHome:) forControlEvents:UIControlEventTouchUpInside];
        [rightButton addTarget:self action:@selector(addHome:) forControlEvents:UIControlEventTouchUpInside];
    }];

    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateCurrentAccessories) name:kDidUpdateAccessory object:nil];
}

- (void)initNavigationItemWithLeftTitle:(NSString *)title {
    
    [self.navigationController.navigationBar setTitleTextAttributes:@{NSFontAttributeName : FONT_H2_BOLD}];
    
    UIBarButtonItem *leftButtonItem = [[UIBarButtonItem alloc] initWithTitle:title style:UIBarButtonItemStylePlain target:self action:@selector(leftButtonItemPressed:)];
    [leftButtonItem setTitleTextAttributes:@{NSFontAttributeName : FONT_H2_BOLD, NSForegroundColorAttributeName : HEXCOLOR(0xFFA500)} forState:(UIControlStateNormal)];
    [leftButtonItem setTitleTextAttributes:@{NSFontAttributeName : FONT_H2_BOLD, NSForegroundColorAttributeName : HEXCOLOR(0xFFA500)} forState:(UIControlStateHighlighted)];
    self.navigationItem.leftBarButtonItem = leftButtonItem;
    
//    UIBarButtonItem *rightbuttonItem = [[UIBarButtonItem alloc] initWithTitle:@"Add Accessory" style:UIBarButtonItemStylePlain target:self action:@selector(rightButtonItemPressed:)];
//    [rightbuttonItem setTitleTextAttributes:@{NSFontAttributeName : FONT_H2_BOLD, NSForegroundColorAttributeName : HEXCOLOR(0xFFA500)} forState:(UIControlStateNormal)];
//    [rightbuttonItem setTitleTextAttributes:@{NSFontAttributeName : FONT_H2_BOLD, NSForegroundColorAttributeName : HEXCOLOR(0xFFA500)} forState:(UIControlStateHighlighted)];
//    self.navigationItem.rightBarButtonItem = rightbuttonItem;
}

- (void)initHeaderViewWithCompletionHandler:(void (^)(UIButton *leftButton, UIButton *rightButton))completion {
    UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 0, 54)];
    
    UIButton *leftButton = [[UIButton alloc] init];
    [headerView addSubview:leftButton];
    [leftButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(leftButton.superview).offset(15);
        make.top.equalTo(leftButton.superview).offset(5);
        make.width.equalTo(@120);
        make.height.equalTo(@44);
    }];
    leftButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    [leftButton setTitleColor:HEXCOLOR(0xFFA500) forState:UIControlStateNormal];
    [leftButton setTitleColor:[UIColor grayColor] forState:UIControlStateDisabled];
    [leftButton.titleLabel setFont:FONT_H2_BOLD];
    
    UIButton *rightButton = [[UIButton alloc] init];
    [headerView addSubview:rightButton];
    [rightButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(leftButton.superview).offset(-15);
        make.top.equalTo(leftButton.superview).offset(5);
        make.width.equalTo(@120);
        make.height.equalTo(@44);
    }];

    rightButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentRight;
    [rightButton setTitleColor:HEXCOLOR(0xFFA500) forState:UIControlStateNormal];
    [rightButton.titleLabel setFont:FONT_H2_BOLD];
    
    self.tableView.tableHeaderView = headerView;
    
    completion(leftButton, rightButton);
}

- (void)updateCurrentHomeInfo {
    
    HMHomeManager *manager = [HMHomeManager sharedManager];

    self.navigationItem.title = manager.primaryHome.name;
    manager.primaryHome.delegate = self;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kDidUpdateCurrentHomeInfo object:self];
}

- (void)updateCurrentAccessories {
    
    HMHomeManager *manager = [HMHomeManager sharedManager];
    NSMutableArray *arrM = [NSMutableArray array];
    NSMutableArray *services = [NSMutableArray array];

    for (HMAccessory *accessory in manager.primaryHome.roomForEntireHome.accessories) {
        for (HMService *service in accessory.services) {
            if (service.isUserInteractive) {
                [services addObject:service];
            }
        }
        accessory.delegate = self;
    }
    if (services.count) [arrM addObject:services];
    
    for (HMRoom *room in manager.primaryHome.rooms) {
        services = [NSMutableArray array];
        for (HMAccessory *accessory in room.accessories) {
            for (HMService *service in accessory.services) {
                if (service.isUserInteractive) {
                    [services addObject:service];
                }
            }
            accessory.delegate = self;
        }
        if (services.count) [arrM addObject:services];
    }
    
    self.dataList = [NSArray arrayWithArray:arrM];
    [self.tableView reloadData];
}

#pragma mark - Actions

- (void)leftButtonItemPressed:(id)sender {
    
    HMHomeManager *manager = [HMHomeManager sharedManager];
    
    if (manager.homes.count > 0) {
        
        SMAlertView *alertView = [SMAlertView alertViewWithTitle:nil message:nil style:SMAlertViewStyleActionSheet];
        
        for (HMHome *home in manager.homes) {
            NSString *homeName = home.name;
            __weak typeof(self) weakSelf = self;
            [alertView addAction:[SMAlertAction actionWithTitle:homeName style:SMAlertActionStyleDefault selected:home.isPrimary handler:^(SMAlertAction * _Nonnull action) {
                [manager updatePrimaryHome:home completionHandler:^(NSError * _Nullable error) {
                    if (error) {
                        NSLog(@"Error updating primary home: %@", error);
                    } else {
                        NSLog(@"Primary home updated.");
                        [weakSelf updateCurrentHomeInfo];
                        [weakSelf updateCurrentAccessories];
                    }
                }];
            }]];
        }
        
        [alertView addAction:[SMAlertAction actionWithTitle:@"Cancel" style:SMAlertActionStyleCancel handler:nil]];
        [alertView show];
    }
}

//- (void)rightButtonItemPressed:(id)sender {
//    SMAddAccessoryViewController *vc = [[SMAddAccessoryViewController alloc] init];
//    vc.didAddAccessory = self.didAddAccessory;
//    [self presentViewController:[[UINavigationController alloc] initWithRootViewController:vc] animated:YES completion:nil];
//}

- (void)removeHome:(id)sender {
    
    HMHomeManager *manager = [HMHomeManager sharedManager];

    if (manager.primaryHome) {
        NSString *message = [NSString stringWithFormat:@"Are you sure you want to remove %@?", manager.primaryHome.name];
        SMAlertView *alertView = [SMAlertView alertViewWithTitle:nil message:message style:SMAlertViewStyleActionSheet];
        
        __weak typeof(self) weakSelf = self;
        [alertView addAction:[SMAlertAction actionWithTitle:@"Remove" style:SMAlertActionStyleConfirm
                                                    handler:^(SMAlertAction * _Nonnull action) {
                                                        [manager removeHome:manager.primaryHome completionHandler:^(NSError * _Nullable error) {
                                                            if (error) {
                                                                NSLog(@"%@", error);
                                                            } else {
                                                                if (manager.homes.count) {
                                                                    [manager updatePrimaryHome:manager.homes.firstObject completionHandler:^(NSError * _Nullable error) {
                                                                        [weakSelf updateCurrentHomeInfo];
                                                                        [weakSelf updateCurrentAccessories];
                                                                    }];
                                                                }
                                                            }
                                                        }];
                                                    }]];
        [alertView addAction:[SMAlertAction actionWithTitle:@"Cancel" style:SMAlertActionStyleCancel
                                                    handler:nil]];
        [alertView show];
    }
}

- (void)addHome:(id)sender {
    
    __weak HMHomeManager *manager = [HMHomeManager sharedManager];

    SMAlertView *alertView = [SMAlertView alertViewWithTitle:@"Add Home..." message:@"Please make sure the name is unique." style:SMAlertViewStyleAlert];
    
    [alertView addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"Ex. Vacation Home";
    }];
    
    [alertView addAction:[SMAlertAction actionWithTitle:@"Cancel" style:SMAlertActionStyleCancel handler:nil]];
    
    __weak typeof(self) weakSelf = self;
    [alertView addAction:[SMAlertAction actionWithTitle:@"Confirm" style:SMAlertActionStyleConfirm handler:^(SMAlertAction * _Nonnull action) {
        NSString *newName = alertView.textFields.firstObject.text;
        [manager addHomeWithName:newName completionHandler:^(HMHome * _Nullable home, NSError * _Nullable error) {
            if (error) {
                NSLog(@"%@", error);
            } else {
                [manager updatePrimaryHome:home completionHandler:^(NSError * _Nullable error) {
                    [weakSelf updateCurrentHomeInfo];
                    [weakSelf updateCurrentAccessories];
                }];
            }
        }];
    }]];
    [alertView show];
}

#pragma mark - HMHomeManagerDelegate

- (void)homeManagerDidUpdateHomes:(HMHomeManager *)manager {
    if (manager.primaryHome) {
        [self updateCurrentHomeInfo];
        [self updateCurrentAccessories];
    } else {
        SMAlertView *alertView = [SMAlertView alertViewWithTitle:@"No home" message:nil style:SMAlertViewStyleActionSheet];
        [alertView addAction:[SMAlertAction actionWithTitle:@"OK" style:SMAlertActionStyleCancel handler:nil]];
        [alertView show];
    }
}

- (void)homeManager:(HMHomeManager *)manager didAddHome:(HMHome *)home {
    __weak typeof(self)weakSelf = self;
    [[HMHomeManager sharedManager] updatePrimaryHome:home completionHandler:^(NSError * _Nullable error) {
        [weakSelf updateCurrentHomeInfo];
        [weakSelf updateCurrentAccessories];
    }];
    NSLog(@"didAddHome");
}


- (void)homeManager:(HMHomeManager *)manager didRemoveHome:(HMHome *)home {
    NSLog(@"didRemoveHome");
}

- (void)homeManagerDidUpdatePrimaryHome:(HMHomeManager *)manager {
    if (manager.primaryHome) {
        [self updateCurrentHomeInfo];
        [self updateCurrentAccessories];
    } else {
        SMAlertView *alertView = [SMAlertView alertViewWithTitle:@"No home" message:nil style:SMAlertViewStyleActionSheet];
        [alertView addAction:[SMAlertAction actionWithTitle:@"OK" style:SMAlertActionStyleCancel handler:nil]];
        [alertView show];
    }
}

#pragma mark - HMHomeDelegate

- (void)home:(HMHome *)home didAddAccessory:(HMAccessory *)accessory {
    [[NSNotificationCenter defaultCenter] postNotificationName:kDidUpdateAccessory object:self];
}

- (void)home:(HMHome *)home didRemoveAccessory:(HMAccessory *)accessory {
    [[NSNotificationCenter defaultCenter] postNotificationName:kDidUpdateAccessory object:self];
}

- (void)home:(HMHome *)home didUpdateRoom:(HMRoom *)room forAccessory:(HMAccessory *)accessory {
    [[NSNotificationCenter defaultCenter] postNotificationName:kDidUpdateAccessory object:self];
}

#pragma mark - HMAccessoryDelegate

- (void)accessoryDidUpdateReachability:(HMAccessory *)accessory {
    for (HMRoom *room in self.dataList) {
        NSInteger section = [self.dataList indexOfObject:room];
        if ([room.accessories containsObject:accessory]) {
            NSUInteger row = [room.accessories indexOfObject:accessory];
            
            SMTableViewCell *cell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:section]];
            cell.available = accessory.reachable;
        }
    }
}

- (void)accessory:(HMAccessory *)accessory service:(HMService *)service didUpdateValueForCharacteristic:(HMCharacteristic *)characteristic {
    [[NSNotificationCenter defaultCenter] postNotificationName:kDidUpdateCharacteristicValue
                                                        object:self
                                                      userInfo:@{@"accessory": accessory,
                                                                 @"service": service,
                                                                 @"characteristic": characteristic}];
}

- (void)accessoryDidUpdateServices:(HMAccessory *)accessory {
    
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.dataList.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSArray *services = self.dataList[section];
    return services.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    SMTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kSMTableViewCell];
    if (!cell) {
        cell = [[SMTableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:kSMTableViewCell];
    }
    
    NSArray *services = self.dataList[indexPath.section];
    HMService *service = services[indexPath.row];
    
    cell.leftLabel.text = service.name;
    cell.available = service.accessory.reachable;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;

    for (HMCharacteristic *characteristic in service.characteristics) {
        if ([characteristic.characteristicType isEqualToString:HMCharacteristicTypePowerState] ||
            [characteristic.characteristicType isEqualToString:HMCharacteristicTypeObstructionDetected] ||
            [characteristic.characteristicType isEqualToString:HMCharacteristicTypeTargetLockMechanismState]) {

            UISwitch *lockSwitch = [[UISwitch alloc] init];
            lockSwitch.on = [characteristic.value boolValue];
            lockSwitch.enabled = service.accessory.isReachable;
            [lockSwitch addTarget:self action:@selector(changeLockState:) forControlEvents:UIControlEventValueChanged];
            
            cell.accessoryView = lockSwitch;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            
            break;
        }
    }    
    return cell;
}

- (void)changeLockState:(id)sender {
    CGPoint switchOriginInTableView = [sender convertPoint:CGPointZero toView:self.tableView];
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:switchOriginInTableView];

    NSArray *services = self.dataList[indexPath.section];
    HMService *service = services[indexPath.row];

    for (HMCharacteristic *characteristic in service.characteristics) {
        if ([characteristic.characteristicType isEqualToString:HMCharacteristicTypeTargetLockMechanismState]  ||
            [characteristic.characteristicType isEqualToString:HMCharacteristicTypePowerState] ||
            [characteristic.characteristicType isEqualToString:HMCharacteristicTypeObstructionDetected]) {
            
            BOOL changedLockState = ![characteristic.value boolValue];
            
            [characteristic writeValue:[NSNumber numberWithBool:changedLockState] completionHandler:^(NSError *error) {
                if (error == nil) {
                    dispatch_async(dispatch_get_main_queue(), ^(void) {
                        NSLog(@"Changed Lock State: %@", characteristic.value);
                    });
                } else {
                    NSLog(@"error in writing characterstic: %@", error);
                }
            }];
            break;
        }
    }
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    SMTableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    
    if (cell.selectionStyle == UITableViewCellSelectionStyleDefault) {
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        
        SMServiceViewController *viewController = [[SMServiceViewController alloc] init];
        viewController.service = self.dataList[indexPath.section][indexPath.row];
        [self.navigationController pushViewController:viewController animated:YES];
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 44;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 44;
}

- (nullable UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    SMTableViewHeaderView *header = [tableView dequeueReusableHeaderFooterViewWithIdentifier:kSMTableViewHeaderView];
    if (!header) {
        header = [[SMTableViewHeaderView alloc] initWithReuseIdentifier:kSMTableViewHeaderView];
    }
    
    NSArray *services = self.dataList[section];
    header.titleLabel.text = ((HMService *)services.firstObject).accessory.room.name;
    return header;
}

@end
