//
//  SMAccessoryListViewController.m
//  SMAPP
//
//  Created by Jason on 14/5/19.
//  Copyright © 2019 RXP. All rights reserved.
//

#import "SMAccessoryListViewController.h"
#import "Masonry.h"
#import "SMCollectionViewCell.h"
#import "Const.h"
#import "HMHomeManager+Share.h"
#import "SMAccessoryDetailViewController.h"
#import "SMAlertView.h"
#import "UIViewController+Show.h"

@interface SMAccessoryListViewController () <UICollectionViewDelegate, UICollectionViewDataSource>

@property (nonatomic, weak) UICollectionView *collectionView;
@property (nonatomic, strong) NSMutableArray *dataList;

@end

@implementation SMAccessoryListViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.navigationItem.title = @"My Devices";
    
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    CGFloat itemWidth = ([UIScreen mainScreen].bounds.size.width - 40) / 3;
    layout.itemSize = CGSizeMake(itemWidth, itemWidth * 1.33);
    layout.minimumInteritemSpacing = 10;
    layout.minimumLineSpacing = 10;
    layout.sectionInset = UIEdgeInsetsMake(5, 10, 5, 10);
    layout.scrollDirection = UICollectionViewScrollDirectionVertical;
    
    UICollectionView *collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    [self.view addSubview:collectionView];
    [collectionView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(collectionView.superview);
    }];
    
    [collectionView registerClass:[SMCollectionViewCell class] forCellWithReuseIdentifier:kSMCollectionViewCell];
    collectionView.backgroundColor = [UIColor whiteColor];
    collectionView.dataSource = self;
    collectionView.delegate = self;
    collectionView.alwaysBounceVertical = YES; // make collectionView bounce even datasource has only 1 item
    _collectionView = collectionView;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadAccessories:) name:kDidUpdateAccessory object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadAccessories:) name:kDidRemoveAccessory object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadAccessories:) name:kDidUpdatePrimaryHome object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadAccessories:) name:kDidUpdateCharacteristicValue object:nil];
    
    [self updateCurrentAccessories];
}

- (void)reloadAccessories:(NSNotification *)notification {
    [self updateCurrentAccessories];
    [self.collectionView reloadData];
}

- (void)updateCurrentAccessories {
    HMHomeManager *manager = [HMHomeManager sharedManager];
    self.dataList = [NSMutableArray array];
    
    for (HMAccessory *accessory in manager.primaryHome.accessories) {
        for (HMService *service in accessory.services) {
            if (service.isUserInteractive) {
                [self.dataList addObject:service];
            }
        }
    }
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.dataList.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    SMCollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:kSMCollectionViewCell forIndexPath:indexPath];
    
    HMService *service = self.dataList[indexPath.row];
    HMAccessory *accessory = service.accessory;
    
    cell.on = NO;
    for (HMCharacteristic *characteristic in service.characteristics) {
        if ([characteristic.characteristicType isEqualToString:HMCharacteristicTypePowerState] ||
            [characteristic.characteristicType isEqualToString:HMCharacteristicTypeObstructionDetected] ||
            [characteristic.characteristicType isEqualToString:HMCharacteristicTypeTargetLockMechanismState]) {
            cell.on = [characteristic.value boolValue];
            break;
        }
    }
    
    cell.topLabel.text = [NSString stringWithFormat:@"%@ > %@", accessory.room.name, service.name];
    cell.serviceType = service.serviceType;
    
    __weak typeof(self) weakSelf = self;
    cell.editButtonPressed = ^{
        SMAccessoryDetailViewController *vc = [[SMAccessoryDetailViewController alloc] init];
        vc.accessory = accessory;
        [weakSelf.navigationController pushViewController:vc animated:YES];
    };
    
    cell.removeButtonPressed = ^{
        NSString *message = [NSString stringWithFormat:@"Are you sure you want to remove %@ from your home?", accessory.name];
        SMAlertView *alertView = [SMAlertView alertViewWithTitle:nil message:message style:SMAlertViewStyleActionSheet];
        
        [alertView addAction:[SMAlertAction actionWithTitle:@"Remove" style:SMAlertActionStyleConfirm
                                                    handler:^(SMAlertAction * _Nonnull action) {
                                                        HMHomeManager *namager = [HMHomeManager sharedManager];
                                                        [namager.primaryHome removeAccessory:accessory completionHandler:^(NSError * _Nullable error) {
                                                            if (error) {
                                                                [self showError:error];
                                                            } else {
                                                                [[NSNotificationCenter defaultCenter] postNotificationName:kDidRemoveAccessory object:self userInfo:@{@"accessory" : accessory}];
                                                            }
                                                        }];
                                                    }]];
        [alertView addAction:[SMAlertAction actionWithTitle:@"Cancel" style:SMAlertActionStyleCancel
                                                    handler:nil]];
        [alertView show];
        
    };
    
    
    return cell;
}

@end
