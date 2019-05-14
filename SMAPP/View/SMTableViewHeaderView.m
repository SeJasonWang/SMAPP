//
//  SMTableViewHeaderView.m
//  SMAPP
//
//  Created by Sichen on 5/5/19.
//  Copyright © 2019 RXP. All rights reserved.
//

#import "SMTableViewHeaderView.h"
#import "Const.h"
#import "Masonry.h"

@implementation SMTableViewHeaderView

- (instancetype)initWithReuseIdentifier:(NSString *)reuseIdentifier {
    if (self = [super initWithReuseIdentifier:reuseIdentifier]) {
        [self initSubviews];
    }
    return self;
}

- (void)initSubviews {
        
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.font = FONT_BODY_BOLD;
    [self.contentView addSubview:titleLabel];
    [titleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(titleLabel.superview).offset(15);
        make.top.bottom.equalTo(titleLabel.superview);
    }];
    _titleLabel = titleLabel;
    
    UIButton *arrowButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.contentView addSubview:arrowButton];
    [arrowButton setImage:[UIImage imageNamed:@"arrow-drop-down"] forState:UIControlStateNormal];
    [arrowButton setImage:[UIImage imageNamed:@"arrow"] forState:UIControlStateSelected];
    [arrowButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.top.bottom.equalTo(arrowButton.superview);
        make.width.equalTo(@44);
    }];
    [arrowButton addTarget:self action:@selector(arrowButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
    _arrowButton = arrowButton;
    
    UIView *topLine = [[UIView alloc] init];
    topLine.backgroundColor = [UIColor lightGrayColor];
    [self.contentView addSubview:topLine];
    [topLine mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.top.right.equalTo(topLine.superview);
        make.height.equalTo(@0.5);
    }];
                       
    UIView *bottomLine = [[UIView alloc] init];
    bottomLine.backgroundColor = [UIColor lightGrayColor];
    [self.contentView addSubview:bottomLine];
    [bottomLine mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.bottom.right.equalTo(topLine.superview);
        make.height.equalTo(@0.5);
    }];
}

- (void)arrowButtonPressed:(UIButton *)sender {
    if (self.arrowButtonPressed) {
        sender.selected = !sender.isSelected;
        self.arrowButtonPressed(sender.isSelected);
    }
}

@end
