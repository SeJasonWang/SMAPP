//
//  SMTableViewHeaderView.h
//  SMAPP
//
//  Created by Sichen on 5/5/19.
//  Copyright © 2019 RXP. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SMTableViewHeaderView : UITableViewHeaderFooterView

@property (nonatomic, weak, readonly) UIButton *titleButton;
@property (nonatomic, weak, readonly) UIButton *arrowButton;
@property (nonatomic, weak, readonly) UIButton *switchButton;

@property (nonatomic, copy) void(^titleButtonPressed)(void);
@property (nonatomic, copy) void(^arrowButtonPressed)(UIButton *button);
@property (nonatomic, copy) void(^switchButtonPressed)(UIButton *button);

@end

NS_ASSUME_NONNULL_END
