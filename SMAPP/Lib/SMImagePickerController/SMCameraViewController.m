//
//  SMCameraViewController.m
//  SMAPP
//
//  Created by Sichen on 28/7/19.
//  Copyright © 2019 RXP. All rights reserved.
//

#import "SMCameraViewController.h"
#import "SMCameraController.h"
#import "SMImagePickerController.h"
#import "SMImageClipViewController.h"

@interface SMCameraViewController ()

@property (nonatomic, weak) SMImagePickerController *picker;

@property (strong, nonatomic) SMCameraController *camera;
@property (strong, nonatomic) UILabel *errorLabel;
@property (strong, nonatomic) UIButton *snapButton;
@property (strong, nonatomic) UIButton *switchButton;
@property (strong, nonatomic) UIButton *flashButton;
@property (strong, nonatomic) UIButton *albumsButton;
@property (strong, nonatomic) UIButton *cancelButton;

@end

@implementation SMCameraViewController

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation {
    return UIInterfaceOrientationPortrait;
}

#pragma mark - Life Cycle

- (instancetype)initWithPicker:(SMImagePickerController *)picker {
    self.picker = picker;
    return [self init];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor blackColor];
    
    [self attachCamera];
    [self attachButtons];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self.camera start];
}

#pragma mark - Private Method

- (void)attachCamera {
    
    CGRect screenRect = [[UIScreen mainScreen] bounds];

    self.camera = [[SMCameraController alloc] init];

    [self.camera willMoveToParentViewController:self];
    self.camera.view.frame = self.view.frame;;
    [self.view addSubview:self.camera.view];
    [self addChildViewController:self.camera];
    [self.camera didMoveToParentViewController:self];
    
    // http://stackoverflow.com/questions/5427656/ios-uiimagepickercontroller-result-image-orientation-after-upload
    // you probably will want to set this to YES, if you are going view the image outside iOS.
    self.camera.fixOrientationAfterCapture = NO;
    
    // take the required actions on a device change
    __weak typeof(self) weakSelf = self;
    [self.camera setOnDeviceChange:^(SMCameraController *camera, AVCaptureDevice * device) {
        
        NSLog(@"Device changed.");
        
        // device changed, check if flash is available
        if (camera.isFlashAvailable) {
            weakSelf.flashButton.hidden = NO;
            
            if (camera.flash == SMCameraFlashOff) {
                weakSelf.flashButton.selected = NO;
            } else {
                weakSelf.flashButton.selected = YES;
            }
        } else {
            weakSelf.flashButton.hidden = YES;
        }
    }];
    
    [self.camera setOnError:^(SMCameraController *camera, NSError *error) {
        
        NSLog(@"Camera error: %@", error);
        
        if ([error.domain isEqualToString:SMCameraErrorDomain]) {
            if (error.code == SMCameraErrorCodeCameraPermission ||
                error.code == SMCameraErrorCodeMicrophonePermission) {
                
                if (weakSelf.errorLabel) {
                    [weakSelf.errorLabel removeFromSuperview];
                }
                
                UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
                label.text = @"We need permission for the camera.\nPlease go to your settings.";
                label.numberOfLines = 2;
                label.lineBreakMode = NSLineBreakByWordWrapping;
                label.backgroundColor = [UIColor clearColor];
                label.font = [UIFont fontWithName:@"AvenirNext-DemiBold" size:13.0f];
                label.textColor = [UIColor whiteColor];
                label.textAlignment = NSTextAlignmentCenter;
                [label sizeToFit];
                label.center = CGPointMake(screenRect.size.width / 2.0f, screenRect.size.height / 2.0f);
                weakSelf.errorLabel = label;
                [weakSelf.view addSubview:weakSelf.errorLabel];
            }
        }
    }];
}

- (void)attachButtons {
    
    CGRect screenRect = [[UIScreen mainScreen] bounds];

    // snap button
    self.snapButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.snapButton.frame = CGRectMake((screenRect.size.width - 70.0f) / 2, screenRect.size.height - 85.0f, 70.0f, 70.0f);
    self.snapButton.clipsToBounds = YES;
    self.snapButton.layer.cornerRadius = self.snapButton.frame.size.width / 2.0f;
    self.snapButton.layer.borderColor = [UIColor whiteColor].CGColor;
    self.snapButton.layer.borderWidth = 2.0f;
    self.snapButton.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.5];
    self.snapButton.layer.rasterizationScale = [UIScreen mainScreen].scale;
    self.snapButton.layer.shouldRasterize = YES;
    [self.snapButton addTarget:self action:@selector(snapButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.snapButton];
    
    // flash button
    self.flashButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.flashButton.frame = CGRectMake((screenRect.size.width - 36.0f) / 2, 5.0f, 36.0f, 44.0f);
    self.flashButton.tintColor = [UIColor whiteColor];
    [self.flashButton setImage:[UIImage imageNamed:[@"SMImagePickerController.bundle" stringByAppendingPathComponent:@"camera-flash.png"]] forState:UIControlStateNormal];
    self.flashButton.imageEdgeInsets = UIEdgeInsetsMake(10.0f, 10.0f, 10.0f, 10.0f);
    [self.flashButton addTarget:self action:@selector(flashButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.flashButton];
    
    // switch button
    if ([SMCameraController isFrontCameraAvailable] && [SMCameraController isRearCameraAvailable]) {
        self.switchButton = [UIButton buttonWithType:UIButtonTypeSystem];
        self.switchButton.frame = CGRectMake(screenRect.size.width - 54.0f, 5.0f, 49.0f, 42.0f);
        self.switchButton.tintColor = [UIColor whiteColor];
        [self.switchButton setImage:[UIImage imageNamed:[@"SMImagePickerController.bundle" stringByAppendingPathComponent:@"camera-switch.png"]] forState:UIControlStateNormal];
        self.switchButton.imageEdgeInsets = UIEdgeInsetsMake(10.0f, 10.0f, 10.0f, 10.0f);
        [self.switchButton addTarget:self action:@selector(switchButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:self.switchButton];
    }
    
    // albums button
    self.albumsButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.albumsButton.frame = CGRectMake(screenRect.size.width - 80.0f, screenRect.size.height - 80.0f, 60.0f, 60.0f);
    [self.albumsButton setImage:[UIImage imageNamed:[@"SMImagePickerController.bundle" stringByAppendingPathComponent:@"photo_pics.png"]] forState:UIControlStateNormal];
    [self.albumsButton addTarget:self action:@selector(albumsButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.albumsButton];
    
    // cancel button
    self.cancelButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.cancelButton.frame = CGRectMake(20.0f, screenRect.size.height - 80.0f, 60.0f, 60.0f);
    [self.cancelButton setImage:[UIImage imageNamed:[@"SMImagePickerController.bundle" stringByAppendingPathComponent:@"cancel.png"]] forState:UIControlStateNormal];
    [self.cancelButton addTarget:self.picker action:@selector(cancel) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.cancelButton];
}

#pragma mark - Action

- (void)snapButtonPressed:(UIButton *)button {
    __weak typeof(self) weakSelf = self;
    
    [self.camera capture:^(SMCameraController *camera, UIImage *image, NSDictionary *metadata, NSError *error) {
        if (!error) {
            SMImageClipViewController *clip = [[SMImageClipViewController alloc] initWithImage:image picker:weakSelf.picker];
            if (!weakSelf.picker.allowsEditing) clip.preview = YES;
            [clip willMoveToParentViewController:weakSelf.picker];
            clip.view.frame = weakSelf.picker.view.frame;
            [weakSelf.picker.view addSubview:clip.view];
            [weakSelf.picker addChildViewController:clip];
            [camera didMoveToParentViewController:weakSelf];
            [weakSelf.picker updateStatusBarHidden:YES animation:NO];
        }
        else {
            NSLog(@"An error has occured: %@", error);
        }
    } exactSeenImage:YES];
}

- (void)flashButtonPressed:(UIButton *)button {
    if (self.camera.flash == SMCameraFlashOff) {
        BOOL done = [self.camera updateFlashMode:SMCameraFlashOn];
        if (done) {
            self.flashButton.selected = YES;
            self.flashButton.tintColor = [UIColor yellowColor];
        }
    } else {
        BOOL done = [self.camera updateFlashMode:SMCameraFlashOff];
        if (done) {
            self.flashButton.selected = NO;
            self.flashButton.tintColor = [UIColor whiteColor];
        }
    }
}

- (void)switchButtonPressed:(UIButton *)button {
    [self.camera togglePosition];
}

- (void)albumsButtonPressed:(UIButton *)button {
    [self.picker presentAlbums];
}

@end
