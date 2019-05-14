//
//  SMHomeSettingViewController.h
//  SMAPP
//
//  Created by Jason on 6/5/19.
//  Copyright © 2019 RXP. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "HMHomeManager+Share.h"

NS_ASSUME_NONNULL_BEGIN

@interface SMHomeSettingViewController : UITableViewController

- (instancetype)initWithHome:(HMHome *)home;
@end

NS_ASSUME_NONNULL_END
