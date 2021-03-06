//
//  SMHomeTableViewCell.h
//  SMAPP
//
//  Created by Sichen on 14/5/19.
//  Copyright © 2019 RXP. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SMHomeTableViewCell : UITableViewCell

@property (nonatomic, weak) UIButton *button;
@property (nonatomic, weak) UISwitch *lockSwitch;
@property (nonatomic, weak) UILabel *leftLabel;
@property (nonatomic, weak) UILabel *rightLabel;

@property (nonatomic, copy) void(^buttonPressed)(UIButton *sender);

@property (nonatomic, assign, getter=isAvailable) BOOL available;

@end

NS_ASSUME_NONNULL_END
