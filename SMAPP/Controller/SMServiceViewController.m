//
//  SMServiceViewController.m
//  SMAPP
//
//  Created by Sichen on 14/4/19.
//  Copyright © 2019 RXP. All rights reserved.
//

#import "SMServiceViewController.h"
#import "Const.h"
#import "UIViewController+Show.h"

@interface SMServiceViewController ()

@end

@implementation SMServiceViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.navigationItem.title = self.service.name;
    
    [self.tableView reloadData];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateCharacteristicValue:) name:kDidUpdateCharacteristicValue object:nil];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.service.characteristics.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kUITableViewCell];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:kUITableViewCell];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.textLabel.font = FONT_BODY;
        cell.textLabel.textColor = COLOR_TITLE;
    }
    HMCharacteristic *characteristic = self.service.characteristics[indexPath.row];
    if (characteristic.value != nil) {
        cell.textLabel.text = [NSString stringWithFormat:@"%@", characteristic.value];
    } else {
        cell.textLabel.text = @"";
    }
    
    cell.detailTextLabel.text = characteristic.localizedDescription;
    
    if ([characteristic.characteristicType isEqualToString:HMCharacteristicTypePowerState] ||
        [characteristic.characteristicType isEqualToString:HMCharacteristicTypeObstructionDetected] ||
        [characteristic.characteristicType isEqualToString:HMCharacteristicTypeTargetLockMechanismState]) {
        
        BOOL lockState = [characteristic.value boolValue];
        
        UISwitch *lockSwitch = [[UISwitch alloc] init];
        lockSwitch.on = lockState;
        [lockSwitch addTarget:self action:@selector(changeLockState:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = lockSwitch;
    } else if ([characteristic.characteristicType isEqualToString:HMCharacteristicTypeSaturation] ||
               [characteristic.characteristicType isEqualToString:HMCharacteristicTypeBrightness] ||
               [characteristic.characteristicType isEqualToString:HMCharacteristicTypeHue] ||
               [characteristic.characteristicType isEqualToString:HMCharacteristicTypeTargetTemperature] ||
               [characteristic.characteristicType isEqualToString:HMCharacteristicTypeTargetRelativeHumidity] ||
               [characteristic.characteristicType isEqualToString:HMCharacteristicTypeCoolingThreshold] ||
               [characteristic.characteristicType isEqualToString:HMCharacteristicTypeHeatingThreshold] ||
               [characteristic.characteristicType isEqualToString:HMCharacteristicTypeTargetPosition]) {
        UISlider *slider = [[UISlider alloc] init];
        slider.bounds = CGRectMake(0, 0, 125, slider.bounds.size.height);
        slider.maximumValue = [characteristic.metadata.maximumValue floatValue];
        slider.minimumValue = [characteristic.metadata.minimumValue floatValue];
        slider.value = [characteristic.value integerValue];
        slider.continuous = YES;
        [slider addTarget:self action:@selector(changeSliderValue:) forControlEvents:UIControlEventValueChanged];
        
        cell.accessoryView = slider;
    }
    
    return cell;
}

- (void)changeLockState:(id)sender {
    
    CGPoint switchOriginInTableView = [sender convertPoint:CGPointZero toView:self.tableView];
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:switchOriginInTableView];
    
    HMCharacteristic *characteristic = self.service.characteristics[indexPath.row];
    
    if ([characteristic.characteristicType isEqualToString:HMCharacteristicTypeTargetLockMechanismState]  ||
        [characteristic.characteristicType isEqualToString:HMCharacteristicTypePowerState] ||
        [characteristic.characteristicType isEqualToString:HMCharacteristicTypeObstructionDetected]) {
        
        BOOL changedLockState = ![characteristic.value boolValue];
        
        [characteristic writeValue:[NSNumber numberWithBool:changedLockState] completionHandler:^(NSError *error) {
            if (error) {
                [self showError:error];
            } else {
                dispatch_async(dispatch_get_main_queue(), ^(void) {
                    [self.tableView cellForRowAtIndexPath:indexPath].textLabel.text = [NSString stringWithFormat:@"%@", characteristic.value];
                });
                
                [[NSNotificationCenter defaultCenter] postNotificationName:kDidUpdateCharacteristicValue
                                                                    object:self
                                                                  userInfo:@{@"accessory": self.service.accessory,
                                                                             @"service": self.service,
                                                                             @"characteristic": characteristic}];
                
            }
        }];
    }
}

- (void)changeSliderValue:(id)sender {
    
    UISlider *slider = (UISlider*)sender;
    
    NSLog(@"%f", slider.value);
    
    CGPoint sliderOriginInTableView = [sender convertPoint:CGPointZero toView:self.tableView];
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:sliderOriginInTableView];
    
    HMCharacteristic *characteristic = self.service.characteristics[indexPath.row];
    
    [characteristic writeValue:[NSNumber numberWithInteger:slider.value] completionHandler:^(NSError *error) {
        if (error) {
            [self showError:error];
        } else {
            dispatch_async(dispatch_get_main_queue(), ^(void) {
                [self.tableView cellForRowAtIndexPath:indexPath].textLabel.text = [NSString stringWithFormat:@"%.0f", slider.value] ;
            });
            
            [[NSNotificationCenter defaultCenter] postNotificationName:kDidUpdateCharacteristicValue
                                                                object:self
                                                              userInfo:@{@"accessory": self.service.accessory,
                                                                         @"service": self.service,
                                                                         @"characteristic": characteristic}];
        }
    }];
}

- (void)updateCharacteristicValue:(NSNotification *)notification {
    
    if ([notification.object isEqual:self]) {
        return;
    }
    
    HMCharacteristic *characteristic = [[notification userInfo] objectForKey:@"characteristic"];
    
    if ([self.service.characteristics containsObject:characteristic]) {
        NSInteger index = [self.service.characteristics indexOfObject:characteristic];
        
        UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:index inSection:0]];
        
        dispatch_async(dispatch_get_main_queue(), ^(void){
            cell.textLabel.text = [NSString stringWithFormat:@"%@", characteristic.value];
            if ([cell.accessoryView isKindOfClass:[UISwitch class]]) {
                UISwitch *lockSwitch = (UISwitch *)cell.accessoryView;
                lockSwitch.on = [characteristic.value boolValue];
            } else if ([cell.accessoryView isKindOfClass:[UISlider class]]) {
                UISlider *slider = (UISlider *)cell.accessoryView;
                slider.value = [characteristic.value integerValue];
            }
        });
    }
}

@end
