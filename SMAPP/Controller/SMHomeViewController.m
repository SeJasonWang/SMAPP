//
//  SMHomeViewController.m
//  SMAPP
//
//  Created by Sichen on 14/4/19.
//  Copyright © 2019 RXP. All rights reserved.
//

#import "SMHomeViewController.h"
#import "SMAccessoryDetailViewController.h"
#import "SMHomeTableViewCell.h"
#import "SMTableViewHeaderView.h"
#import "Const.h"
#import "UIView+Extention.h"
#import "SMAlertView.h"
#import "Masonry.h"
#import "SMAddAccessoryViewController.h"
#import "SMRoomViewController.h"
#import "UIViewController+Show.h"
#import "SMMainViewController.h"

@interface SMHomeViewSectionItem : NSObject

@property (nonatomic, assign, getter=isShowed) BOOL showed;
@property (nonatomic, strong) HMRoom *room;
@property (nonatomic, strong) NSMutableArray *services;

@end

@implementation SMHomeViewSectionItem

+ (instancetype)itemWithServices:(NSMutableArray *)services room:(HMRoom *)room showed:(BOOL)showed {
    SMHomeViewSectionItem *sectionItem = [[SMHomeViewSectionItem alloc] init];
    sectionItem.services = services;
    sectionItem.room = room;
    sectionItem.showed = showed;
    return sectionItem;
}

@end

@interface SMHomeViewController () <
HMHomeManagerDelegate,
HMHomeDelegate,
HMAccessoryDelegate
>

@property (nonatomic, assign) NSInteger currentShowedSection;
@property (nonatomic, strong) NSMutableArray *dataList;

@end

@implementation SMHomeViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.navigationItem.title = @"My Devices";
    
    HMHomeManager *namager = [HMHomeManager sharedManager];    
    namager.delegate = self;

    [self initNavigationItems];
    
    self.tableView.backgroundColor = COLOR_BACKGROUND;
    self.tableView.tableFooterView = [[UIView alloc] init]; // remove the lines
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateCurrentAccessories:) name:kDidUpdateRoomName object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateCurrentAccessories:) name:kDidUpdateRoom object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateCurrentAccessories:) name:kDidUpdateAccessory object:nil];    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateCharacteristicValue:) name:kDidUpdateCharacteristicValue object:nil];
}

- (void)initNavigationItems {
    UIImage *image = [[UIImage imageNamed:@"add"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    UIBarButtonItem *rightbuttonItem = [[UIBarButtonItem alloc] initWithImage:image style:UIBarButtonItemStylePlain target:self action:@selector(rightButtonItemPressed:)];
    self.navigationItem.rightBarButtonItem = rightbuttonItem;
}

- (void)UpdatePrimaryHome {
    HMHomeManager *manager = [HMHomeManager sharedManager];

    manager.primaryHome.delegate = self;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kDidUpdatePrimaryHome object:self userInfo:@{@"home" : manager.primaryHome}];
}

- (void)updateCurrentAccessories {
    
    self.currentShowedSection = -1; // means there is no showed section  by default

    NSUserDefaults *userDefault = [NSUserDefaults standardUserDefaults];
    NSDictionary *showedRoomMap = [userDefault objectForKey:kShowedRoom];
    
    HMHomeManager *manager = [HMHomeManager sharedManager];
    NSString *homeID = manager.primaryHome.uniqueIdentifier.UUIDString;
    self.dataList = [NSMutableArray array];
    NSMutableArray *services = [NSMutableArray array];

    HMRoom *roomForEntireHome = manager.primaryHome.roomForEntireHome;
    for (HMAccessory *accessory in roomForEntireHome.accessories) {
        for (HMService *service in accessory.services) {
            if (service.isUserInteractive) {
                [services addObject:service];
            }
        }
        accessory.delegate = self;
    }
    
    BOOL showed = [roomForEntireHome.uniqueIdentifier.UUIDString isEqualToString:showedRoomMap[homeID]] && services.count;
    [self.dataList addObject:[SMHomeViewSectionItem itemWithServices:services room:roomForEntireHome showed:showed]];
    if (showed) {
        self.currentShowedSection = self.dataList.count - 1;
    }
    
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
        BOOL showed = [room.uniqueIdentifier.UUIDString isEqualToString:showedRoomMap[homeID]] && services.count;
        [self.dataList addObject:[SMHomeViewSectionItem itemWithServices:services room:room showed:showed]];
        if (showed) {
            self.currentShowedSection = self.dataList.count - 1;
        }
    }
    
    [self.tableView reloadData];
}

#pragma mark - Notification

- (void)updateCurrentAccessories:(NSNotification *)notification {
    [self updateCurrentAccessories];
}

- (void)updateCharacteristicValue:(NSNotification *)notification {
    HMService *service = [[notification userInfo] objectForKey:@"service"];
    HMCharacteristic *characteristic = [[notification userInfo] objectForKey:@"characteristic"];
    
    for (SMHomeViewSectionItem *item in self.dataList) {
        NSInteger section = [self.dataList indexOfObject:item];
        NSArray *services = item.services;
        for (HMService *item in services) {
            if ([item isEqual:service]) {
                NSInteger row = [services indexOfObject:item];
                SMHomeTableViewCell *cell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:section]];
                
                dispatch_async(dispatch_get_main_queue(), ^(void){
                    cell.lockSwitch.on = [characteristic.value boolValue];
                });
                
                break;
            }
        }
    }
}

#pragma mark - Actions

- (void)switchHome:(id)sender {
    
    HMHomeManager *manager = [HMHomeManager sharedManager];
    
    if (manager.homes.count > 1) {
        
        SMAlertView *alertView = [SMAlertView alertViewWithTitle:nil message:nil style:SMAlertViewStyleAlert];
        
        for (HMHome *home in manager.homes) {
            NSString *homeName = home.name;
            [alertView addAction:[SMAlertAction actionWithTitle:homeName style:SMAlertActionStyleDefault selected:home.isPrimary handler:^(SMAlertAction * _Nonnull action) {
                [self updatePrimaryHome:home];
            }]];
        }
        
        [alertView addAction:[SMAlertAction actionWithTitle:@"Cancel" style:SMAlertActionStyleCancel handler:nil]];
        [alertView show];
    }
}

- (void)updatePrimaryHome:(HMHome *)home {
    
    HMHomeManager *manager = [HMHomeManager sharedManager];
    
    __weak typeof(self) weakSelf = self;
    [manager updatePrimaryHome:home completionHandler:^(NSError * _Nullable error) {
        if (error) {
            [self showError:error];
        } else {
            NSLog(@"Primary home updated.");
            [weakSelf UpdatePrimaryHome];
            [weakSelf updateCurrentAccessories];
        }
    }];
}

- (void)rightButtonItemPressed:(id)sender {    
    [self addDevice];
}

- (void)addHome {
    
    __weak HMHomeManager *manager = [HMHomeManager sharedManager];

    SMAlertView *alertView = [SMAlertView alertViewWithTitle:@"Add Home..." message:@"Please make sure the name is unique." style:SMAlertViewStyleAlert];
    
    [alertView addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"Ex. Vacation Home";
    }];
    
    [alertView addAction:[SMAlertAction actionWithTitle:@"Cancel" style:SMAlertActionStyleCancel handler:nil]];
    
    __weak typeof(self) weakSelf = self;
    [alertView addAction:[SMAlertAction actionWithTitle:@"Save" style:SMAlertActionStyleConfirm handler:^(SMAlertAction * _Nonnull action) {
        NSString *newName = alertView.textFields.firstObject.text;
        [manager addHomeWithName:newName completionHandler:^(HMHome * _Nullable home, NSError * _Nullable error) {
            if (error) {
                [weakSelf showError:error];
            } else {
                [manager updatePrimaryHome:home completionHandler:^(NSError * _Nullable error) {
                    if (error) {
                        [weakSelf showError:error];
                    } else {
                        [weakSelf UpdatePrimaryHome];
                        [weakSelf updateCurrentAccessories];
                    }
                }];
            }
        }];
    }]];
    [alertView show];
}

- (void)addRoom {
    
    HMHomeManager *manager = [HMHomeManager sharedManager];
    
    SMAlertView *alertView = [SMAlertView alertViewWithTitle:@"Add Room..." message:@"Please make sure the name is unique." style:SMAlertViewStyleAlert];
    
    [alertView addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"Ex. Kitchen, Living Room";
    }];
    
    [alertView addAction:[SMAlertAction actionWithTitle:@"Cancel" style:SMAlertActionStyleCancel handler:nil]];
    
    [alertView addAction:[SMAlertAction actionWithTitle:@"Save" style:SMAlertActionStyleConfirm handler:^(SMAlertAction * _Nonnull action) {
        NSString *newName = alertView.textFields.firstObject.text;
        [manager.primaryHome addRoomWithName:newName completionHandler:^(HMRoom * _Nullable room, NSError * _Nullable error) {
            if (error) {
                [self showError:error];
            } else {
                [self updateCurrentAccessories];
            }
        }];
    }]];
    [alertView show];
}

- (void)addDevice {
    SMAddAccessoryViewController *addVC = [[SMAddAccessoryViewController alloc] init];
    [self.navigationController pushViewController:addVC animated:YES];
}

#pragma mark - HMHomeManagerDelegate

// invokes when app is launched
- (void)homeManagerDidUpdateHomes:(HMHomeManager *)manager {
    if (manager.primaryHome) {
        [self UpdatePrimaryHome];
        [self updateCurrentAccessories];
    } else {
        // load guideView when is no primary home
        UINavigationController *nav = (UINavigationController *)self.parentViewController;
        SMMainViewController *mainVC = (SMMainViewController *)nav.parentViewController;
        [mainVC loadImage:YES];
    }
}

// invokes when other apps did add a home, such as Home
- (void)homeManager:(HMHomeManager *)manager didAddHome:(HMHome *)home {
    typeof(self)weakSelf = self;
    [[HMHomeManager sharedManager] updatePrimaryHome:home completionHandler:^(NSError * _Nullable error) {
        if (error) {
            [self showError:error];
        } else {
            [weakSelf UpdatePrimaryHome];
            [weakSelf updateCurrentAccessories];
        }
    }];
}

// invokes when other apps did remove a home, such as Home
// after invoking this function, the system will invokes homeManagerDidUpdatePrimaryHome:
- (void)homeManager:(HMHomeManager *)manager didRemoveHome:(HMHome *)home {
    if (home.isPrimary) {
        [[NSNotificationCenter defaultCenter] postNotificationName:kDidUpdatePrimaryHome object:self userInfo:@{@"remove" : @"1"}];
    }
}

// invokes when a new home is assigned to the primary home
- (void)homeManagerDidUpdatePrimaryHome:(HMHomeManager *)manager {
    if (manager.primaryHome) {
        [self UpdatePrimaryHome];
        [self updateCurrentAccessories];
    }
}

// Only invokes when other apps did some changes
#pragma mark - HMHomeDelegate

- (void)homeDidUpdateName:(HMHome *)home {
    [[NSNotificationCenter defaultCenter] postNotificationName:kDidUpdateHomeName object:self userInfo:@{@"home" : home}];
}

- (void)home:(HMHome *)home didAddAccessory:(HMAccessory *)accessory {
    [[NSNotificationCenter defaultCenter] postNotificationName:kDidUpdateAccessory object:self userInfo:@{@"accessory" : accessory}];
}

- (void)home:(HMHome *)home didRemoveAccessory:(HMAccessory *)accessory {
    [[NSNotificationCenter defaultCenter] postNotificationName:kDidUpdateAccessory object:self userInfo:@{@"accessory" : accessory}];
}

- (void)home:(HMHome *)home didUpdateRoom:(HMRoom *)room forAccessory:(HMAccessory *)accessory {
    [[NSNotificationCenter defaultCenter] postNotificationName:kDidUpdateAccessory object:self userInfo:@{@"accessory" : accessory}];
}

- (void)home:(HMHome *)home didAddRoom:(HMRoom *)room {
    [[NSNotificationCenter defaultCenter] postNotificationName:kDidUpdateRoom object:self userInfo:@{@"room" : room}];
}


- (void)home:(HMHome *)home didRemoveRoom:(HMRoom *)room {
    [[NSNotificationCenter defaultCenter] postNotificationName:kDidUpdateRoom object:self userInfo:@{@"room" : room}];
}


- (void)home:(HMHome *)home didUpdateNameForRoom:(HMRoom *)room {
    [[NSNotificationCenter defaultCenter] postNotificationName:kDidUpdateRoomName object:self userInfo:@{@"home" : home, @"room" : room}];
}

#pragma mark - HMAccessoryDelegate

- (void)accessoryDidUpdateName:(HMAccessory *)accessory {
    [[NSNotificationCenter defaultCenter] postNotificationName:kDidUpdateAccessory object:self userInfo:@{@"accessory" : accessory}];
}

- (void)accessory:(HMAccessory *)accessory didUpdateNameForService:(HMService *)service {
    [[NSNotificationCenter defaultCenter] postNotificationName:kDidUpdateAccessory object:self userInfo:@{@"accessory" : accessory, @"service" : accessory}];
}

- (void)accessoryDidUpdateServices:(HMAccessory *)accessory {
    [[NSNotificationCenter defaultCenter] postNotificationName:kDidUpdateAccessory object:self userInfo:@{@"accessory" : accessory}];
}

- (void)accessoryDidUpdateReachability:(HMAccessory *)accessory {
    for (SMHomeViewSectionItem *item in self.dataList) {
        NSInteger section = [self.dataList indexOfObject:item];
        NSArray *services = item.services;
        
        for (HMService *service in services) {
            if ([service.accessory isEqual:accessory]) {
                NSInteger row = [services indexOfObject:service];
                SMHomeTableViewCell *cell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:section]];
                cell.available = accessory.reachable;
                if (!cell.lockSwitch.isHidden) {
                    
                    cell.lockSwitch.enabled = cell.isAvailable;
                    
                    for (HMCharacteristic *characteristic in service.characteristics) {
                        if ([characteristic.characteristicType isEqualToString:HMCharacteristicTypePowerState] ||
                            [characteristic.characteristicType isEqualToString:HMCharacteristicTypeObstructionDetected] ||
                            [characteristic.characteristicType isEqualToString:HMCharacteristicTypeTargetLockMechanismState]) {
                            cell.lockSwitch.on = [characteristic.value boolValue];
                        }
                        break;
                    }
                }
            }
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

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.dataList.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    SMHomeViewSectionItem *item = self.dataList[section];
    return item.services.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    SMHomeTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kSMHomeTableViewCell];
    if (!cell) {
        cell = [[SMHomeTableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:kSMHomeTableViewCell];
    }
    
    SMHomeViewSectionItem *item = self.dataList[indexPath.section];
    HMService *service = item.services[indexPath.row];
    
    cell.leftLabel.text = service.name;
    cell.button.selected = NO;
    cell.available = service.accessory.reachable;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.lockSwitch.hidden = YES;
    [cell.lockSwitch addTarget:self action:@selector(changeLockState:) forControlEvents:UIControlEventValueChanged];

    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSDictionary *floorPlansMap = [userDefaults objectForKey:kShowedFloorPlan];
    NSDictionary *servicesMap = [floorPlansMap objectForKey:[HMHomeManager sharedManager].primaryHome.uniqueIdentifier.UUIDString];
    for (HMAccessory *accessory in [HMHomeManager sharedManager].primaryHome.accessories) {
        for (HMService *item in accessory.services) {
            NSDictionary *coordinateMap = [servicesMap objectForKey:service.uniqueIdentifier.UUIDString];
            if (coordinateMap && [item.uniqueIdentifier.UUIDString isEqualToString:service.uniqueIdentifier.UUIDString]) {
                cell.button.selected = YES;
            }
        }
    }
    
    cell.buttonPressed = ^(UIButton *sender) {
        [[NSNotificationCenter defaultCenter] postNotificationName:kDidStartLayoutAccessory object:self userInfo:@{@"service" : service, @"status" : @(sender.isSelected)}];
    };
    
    for (HMCharacteristic *characteristic in service.characteristics) {
        if ([characteristic.characteristicType isEqualToString:HMCharacteristicTypePowerState] ||
            [characteristic.characteristicType isEqualToString:HMCharacteristicTypeObstructionDetected] ||
            [characteristic.characteristicType isEqualToString:HMCharacteristicTypeTargetLockMechanismState]) {

            cell.lockSwitch.hidden = NO;
            cell.lockSwitch.enabled = service.accessory.isReachable;
            cell.lockSwitch.on = [characteristic.value boolValue];
            break;
        }
    }
    return cell;
}

- (void)changeLockState:(id)sender {
    CGPoint switchOriginInTableView = [sender convertPoint:CGPointZero toView:self.tableView];
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:switchOriginInTableView];

    SMHomeViewSectionItem *item = self.dataList[indexPath.section];
    HMService *service = item.services[indexPath.row];

    for (HMCharacteristic *characteristic in service.characteristics) {
        if ([characteristic.characteristicType isEqualToString:HMCharacteristicTypeTargetLockMechanismState]  ||
            [characteristic.characteristicType isEqualToString:HMCharacteristicTypePowerState] ||
            [characteristic.characteristicType isEqualToString:HMCharacteristicTypeObstructionDetected]) {
            
            BOOL changedLockState = ![characteristic.value boolValue];
            
            [characteristic writeValue:[NSNumber numberWithBool:changedLockState] completionHandler:^(NSError *error) {
                if (error) {
                    [self showError:error];
                } else {
                    dispatch_async(dispatch_get_main_queue(), ^(void) {
                        NSLog(@"Changed Lock State: %@", characteristic.value);
                    });
                    
                    [[NSNotificationCenter defaultCenter] postNotificationName:kDidUpdateCharacteristicValue
                                                                        object:self
                                                                      userInfo:@{@"accessory": service.accessory,
                                                                                 @"service": service,
                                                                                 @"characteristic": characteristic}];
                }
            }];
            break;
        }
    }
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    SMAccessoryDetailViewController *viewController = [[SMAccessoryDetailViewController alloc] init];
    SMHomeViewSectionItem *item = self.dataList[indexPath.section];
    HMService *service = item.services[indexPath.row];
    viewController.accessory = service.accessory;
    [self.navigationController pushViewController:viewController animated:YES];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    SMHomeViewSectionItem *item = self.dataList[indexPath.section];
    return item.isShowed ? 44 : 0;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 44;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    SMTableViewHeaderView *header = [tableView dequeueReusableHeaderFooterViewWithIdentifier:kSMTableViewHeaderView];
    if (!header) {
        header = [[SMTableViewHeaderView alloc] initWithReuseIdentifier:kSMTableViewHeaderView];
        [header.titleButton setTitleColor:COLOR_ORANGE forState:UIControlStateNormal];
    }
    
    SMHomeViewSectionItem *item = self.dataList[section];
    [header.titleButton setTitle:item.room.name forState:UIControlStateNormal];
    header.arrowButton.selected = item.isShowed;
    
    __weak typeof(self) weakSelf = self;
    
    header.titleButtonPressed = ^{
        SMRoomViewController *roomVC = [[SMRoomViewController alloc] initWithRoom:item.room];
        [weakSelf.navigationController pushViewController:roomVC animated:YES];
    };
    
    header.arrowButtonPressed = ^(UIButton *sender) {
        
        if (item.services.count) {
            sender.selected = !sender.isSelected;
            
            // update the item status
            item.showed = sender.isSelected;
            
            // reload the current section
            [tableView reloadSections:[NSIndexSet indexSetWithIndex:section] withRowAnimation:UITableViewRowAnimationAutomatic];
            
            NSUserDefaults *userDefault = [NSUserDefaults standardUserDefaults];
            NSString *homeID = [HMHomeManager sharedManager].primaryHome.uniqueIdentifier.UUIDString;
            
            if (item.isShowed) {
                // reload the showed section
                if (weakSelf.currentShowedSection >= 0) {
                    NSInteger currentShowedSection = weakSelf.currentShowedSection;
                    SMHomeViewSectionItem *currentItem = weakSelf.dataList[currentShowedSection];
                    currentItem.showed = NO;
                    
                    [tableView reloadSections:[NSIndexSet indexSetWithIndex:currentShowedSection] withRowAnimation:UITableViewRowAnimationAutomatic];
                }
                
                NSMutableDictionary *roomsMap = [NSMutableDictionary dictionaryWithDictionary:[userDefault objectForKey:kShowedRoom]];
                [roomsMap setObject:item.room.uniqueIdentifier.UUIDString forKey:homeID];
                [userDefault setObject:roomsMap forKey:kShowedRoom];
                
                weakSelf.currentShowedSection = section;
            } else {
                
                NSMutableDictionary *roomsMap = [NSMutableDictionary dictionaryWithDictionary:[userDefault objectForKey:kShowedRoom]];
                [roomsMap removeObjectForKey:homeID];
                [userDefault setObject:roomsMap forKey:kShowedRoom];
                
                weakSelf.currentShowedSection = -1;
            }
        } else {
            [weakSelf showText:@"No accessories in this room.\n You can go 'My Devices' -> 'Ddit Icon' to assign an accessory to this room.'" duration:3.0];
        }
    };
    return header;
}

@end
