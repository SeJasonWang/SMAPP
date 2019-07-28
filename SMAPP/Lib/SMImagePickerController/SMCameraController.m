//
//  SMCameraController.m
//  SMAPP
//
//  Created by Sichen on 28/7/19.
//  Copyright © 2019 RXP. All rights reserved.
//

#import "SMCameraController.h"
#import <ImageIO/CGImageProperties.h>
#import "UIImage+SMHelper.h"

@implementation SMCameraController (Convenience)

- (CGPoint)convertToPointOfInterestFromViewCoordinates:(CGPoint)viewCoordinates
                                          previewLayer:(AVCaptureVideoPreviewLayer *)previewLayer
                                                 ports:(NSArray<AVCaptureInputPort *> *)ports {
    CGPoint pointOfInterest = CGPointMake(.5f, .5f);
    CGSize frameSize = previewLayer.frame.size;
    
    if ([previewLayer.videoGravity isEqualToString:AVLayerVideoGravityResize]) {
        pointOfInterest = CGPointMake(viewCoordinates.y / frameSize.height, 1.f - (viewCoordinates.x / frameSize.width));
    } else {
        CGRect cleanAperture;
        for (AVCaptureInputPort *port in ports) {
            if (port.mediaType == AVMediaTypeVideo) {
                cleanAperture = CMVideoFormatDescriptionGetCleanAperture([port formatDescription], YES);
                CGSize apertureSize = cleanAperture.size;
                CGPoint point = viewCoordinates;
                
                CGFloat apertureRatio = apertureSize.height / apertureSize.width;
                CGFloat viewRatio = frameSize.width / frameSize.height;
                CGFloat xc = .5f;
                CGFloat yc = .5f;
                
                if ( [previewLayer.videoGravity isEqualToString:AVLayerVideoGravityResizeAspect] ) {
                    if (viewRatio > apertureRatio) {
                        CGFloat y2 = frameSize.height;
                        CGFloat x2 = frameSize.height * apertureRatio;
                        CGFloat x1 = frameSize.width;
                        CGFloat blackBar = (x1 - x2) / 2;
                        if (point.x >= blackBar && point.x <= blackBar + x2) {
                            xc = point.y / y2;
                            yc = 1.f - ((point.x - blackBar) / x2);
                        }
                    } else {
                        CGFloat y2 = frameSize.width / apertureRatio;
                        CGFloat y1 = frameSize.height;
                        CGFloat x2 = frameSize.width;
                        CGFloat blackBar = (y1 - y2) / 2;
                        if (point.y >= blackBar && point.y <= blackBar + y2) {
                            xc = ((point.y - blackBar) / y2);
                            yc = 1.f - (point.x / x2);
                        }
                    }
                } else if ([previewLayer.videoGravity isEqualToString:AVLayerVideoGravityResizeAspectFill]) {
                    if (viewRatio > apertureRatio) {
                        CGFloat y2 = apertureSize.width * (frameSize.width / apertureSize.height);
                        xc = (point.y + ((y2 - frameSize.height) / 2.f)) / y2;
                        yc = (frameSize.width - point.x) / frameSize.width;
                    } else {
                        CGFloat x2 = apertureSize.height * (frameSize.height / apertureSize.width);
                        yc = 1.f - ((point.x + ((x2 - frameSize.width) / 2)) / x2);
                        xc = point.y / frameSize.height;
                    }
                }
                
                pointOfInterest = CGPointMake(xc, yc);
                break;
            }
        }
    }
    
    return pointOfInterest;
}

- (UIImage *)cropImage:(UIImage *)image usingPreviewLayer:(AVCaptureVideoPreviewLayer *)previewLayer {
    CGRect previewBounds = previewLayer.bounds;
    CGRect outputRect = [previewLayer metadataOutputRectOfInterestForRect:previewBounds];
    
    CGImageRef takenCGImage = image.CGImage;
    size_t width = CGImageGetWidth(takenCGImage);
    size_t height = CGImageGetHeight(takenCGImage);
    CGRect cropRect = CGRectMake(outputRect.origin.x * width, outputRect.origin.y * height,
                                 outputRect.size.width * width, outputRect.size.height * height);
    
    CGImageRef cropCGImage = CGImageCreateWithImageInRect(takenCGImage, cropRect);
    image = [UIImage imageWithCGImage:cropCGImage scale:1 orientation:image.imageOrientation];
    CGImageRelease(cropCGImage);
    
    return image;
}

@end

@interface SMCameraController () <UIGestureRecognizerDelegate>

@property (strong, nonatomic) UIView *preview;
@property (strong, nonatomic) AVCaptureStillImageOutput *stillImageOutput;
@property (strong, nonatomic) AVCaptureSession *session;
@property (strong, nonatomic) AVCaptureDevice *videoCaptureDevice;
@property (strong, nonatomic) AVCaptureDeviceInput *videoDeviceInput;
@property (strong, nonatomic) AVCaptureVideoPreviewLayer *captureVideoPreviewLayer;
@property (strong, nonatomic) UITapGestureRecognizer *tapGesture;
@property (strong, nonatomic) CALayer *focusBoxLayer;
@property (strong, nonatomic) CAAnimation *focusBoxAnimation;
@property (strong, nonatomic) UIPinchGestureRecognizer *pinchGesture;
@property (nonatomic) AVCaptureWhiteBalanceMode whiteBalanceMode;
@property (nonatomic) CGFloat beginGestureScale;
@property (nonatomic) CGFloat effectiveScale;

@end

NSString *const SMCameraErrorDomain = @"SMCameraErrorDomain";

@implementation SMCameraController

#pragma mark - Initialize

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    return [self initWithFlash:SMCameraFlashOff position:SMCameraPositionRear];
}

- (instancetype)initWithFlash:(SMCameraFlash)flash position:(SMCameraPosition)position {
    if (self = [super initWithNibName:nil bundle:nil]) {
        _flash = flash;
        _position = position;
        [self setup];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    if (self = [super initWithCoder:aDecoder]) {
        _flash = SMCameraFlashOff;
        _position = SMCameraPositionRear;
        [self setup];
    }
    return self;
}

- (void)setup {
    _quality = AVCaptureSessionPresetHigh;
    _tapToFocus = YES;
    _zoomingEnabled = YES;
    _fixOrientationAfterCapture = NO;
    _effectiveScale = 1.0f;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor clearColor];
    self.view.autoresizingMask = UIViewAutoresizingNone;
    
    self.preview = [[UIView alloc] initWithFrame:CGRectZero];
    self.preview.backgroundColor = [UIColor clearColor];
    [self.view addSubview:self.preview];
    
    // tap to focus
    self.tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(previewTapped:)];
    self.tapGesture.numberOfTapsRequired = 1;
    [self.tapGesture setDelaysTouchesEnded:NO];
    [self.preview addGestureRecognizer:self.tapGesture];
    
    // pinch to zoom
    if (self.isZoomingEnabled) {
        self.pinchGesture = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handlePinchGesture:)];
        self.pinchGesture.delegate = self;
        [self.preview addGestureRecognizer:self.pinchGesture];
    }
    
    // add focus box to view
    [self addDefaultFocusBox];
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    
    self.preview.frame = CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height);
    
    CGRect bounds = self.preview.bounds;
    self.captureVideoPreviewLayer.bounds = bounds;
    self.captureVideoPreviewLayer.position = CGPointMake(CGRectGetMidX(bounds), CGRectGetMidY(bounds));
    self.captureVideoPreviewLayer.connection.videoOrientation = [SMCameraController orientationForConnection];
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    [super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
    
    // layout subviews is not called when rotating from landscape right/left to left/right
    if (UIInterfaceOrientationIsLandscape(self.interfaceOrientation) && UIInterfaceOrientationIsLandscape(toInterfaceOrientation)) {
        [self.view setNeedsLayout];
    }
}

- (void)dealloc {
    [self stop];
}

#pragma mark - Private Method

- (void)initialize {
    if (!_session) {
        _session = [[AVCaptureSession alloc] init];
        _session.sessionPreset = self.quality;
        
        // preview layer
        CGRect bounds = self.preview.layer.bounds;
        _captureVideoPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.session];
        _captureVideoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
        _captureVideoPreviewLayer.bounds = bounds;
        _captureVideoPreviewLayer.position = CGPointMake(CGRectGetMidX(bounds), CGRectGetMidY(bounds));
        [self.preview.layer addSublayer:_captureVideoPreviewLayer];
        
        AVCaptureDevicePosition devicePosition;
        switch (self.position) {
            case SMCameraPositionRear:
                if ([self.class isRearCameraAvailable]) {
                    devicePosition = AVCaptureDevicePositionBack;
                } else {
                    devicePosition = AVCaptureDevicePositionFront;
                    _position = SMCameraPositionFront;
                }
                break;
            case SMCameraPositionFront:
                if ([self.class isFrontCameraAvailable]) {
                    devicePosition = AVCaptureDevicePositionFront;
                } else {
                    devicePosition = AVCaptureDevicePositionBack;
                    _position = SMCameraPositionRear;
                }
                break;
            default:
                devicePosition = AVCaptureDevicePositionUnspecified;
                break;
        }
        
        if (devicePosition == AVCaptureDevicePositionUnspecified) {
            self.videoCaptureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        } else {
            self.videoCaptureDevice = [self cameraWithPosition:devicePosition];
        }
        
        NSError *error = nil;
        _videoDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:_videoCaptureDevice error:&error];
        
        if (!_videoDeviceInput) {
            [self passError:error];
            return;
        }
        
        if ([self.session canAddInput:_videoDeviceInput]) {
            [self.session addInput:_videoDeviceInput];
            self.captureVideoPreviewLayer.connection.videoOrientation = [SMCameraController orientationForConnection];
        }
        
        // continiously adjust white balance
        self.whiteBalanceMode = AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance;
        
        // image output
        self.stillImageOutput = [[AVCaptureStillImageOutput alloc] init];
        NSDictionary *outputSettings = [[NSDictionary alloc] initWithObjectsAndKeys: AVVideoCodecJPEG, AVVideoCodecKey, nil];
        [self.stillImageOutput setOutputSettings:outputSettings];
        [self.session addOutput:self.stillImageOutput];
    }
    
    //if we had disabled the connection on capture, re-enable it
    if (![self.captureVideoPreviewLayer.connection isEnabled]) {
        [self.captureVideoPreviewLayer.connection setEnabled:YES];
    }
    
    [self.session startRunning];
}

- (void)passError:(NSError *)error {
    if (self.onError) {
        __weak typeof(self) weakSelf = self;
        self.onError(weakSelf, error);
    }
}

- (AVCaptureConnection *)captureConnection {
    AVCaptureConnection *videoConnection = nil;
    for (AVCaptureConnection *connection in self.stillImageOutput.connections) {
        for (AVCaptureInputPort *port in [connection inputPorts]) {
            if ([[port mediaType] isEqual:AVMediaTypeVideo]) {
                videoConnection = connection;
                break;
            }
        }
        if (videoConnection) {
            break;
        }
    }
    
    return videoConnection;
}

// Find a camera with the specified AVCaptureDevicePosition, returning nil if one is not found
- (AVCaptureDevice *)cameraWithPosition:(AVCaptureDevicePosition)position {
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in devices) {
        if (device.position == position) return device;
    }
    return nil;
}

+ (AVCaptureVideoOrientation)orientationForConnection {
    AVCaptureVideoOrientation videoOrientation = AVCaptureVideoOrientationPortrait;
    
    switch ([[UIApplication sharedApplication] statusBarOrientation]) {
        case UIInterfaceOrientationLandscapeLeft:
            videoOrientation = AVCaptureVideoOrientationLandscapeLeft;
            break;
        case UIInterfaceOrientationLandscapeRight:
            videoOrientation = AVCaptureVideoOrientationLandscapeRight;
            break;
        case UIInterfaceOrientationPortraitUpsideDown:
            videoOrientation = AVCaptureVideoOrientationPortraitUpsideDown;
            break;
        default:
            videoOrientation = AVCaptureVideoOrientationPortrait;
            break;
    }
    
    return videoOrientation;
}

+ (void)requestCameraPermission:(void (^)(BOOL granted))completionBlock {
    if ([AVCaptureDevice respondsToSelector:@selector(requestAccessForMediaType: completionHandler:)]) {
        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
            // return to main thread
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completionBlock) {
                    completionBlock(granted);
                }
            });
        }];
    } else {
        completionBlock(YES);
    }
}

#pragma mark - Public Method

- (void)start {
    [SMCameraController requestCameraPermission:^(BOOL granted) {
        if (granted) {
            [self initialize];
        } else {
            NSError *error = [NSError errorWithDomain:SMCameraErrorDomain
                                                 code:SMCameraErrorCodeCameraPermission
                                             userInfo:nil];
            [self passError:error];
        }
    }];
}

- (void)stop {
    [self.session stopRunning];
    self.session = nil;
}

- (void)capture:(void (^)(SMCameraController *camera, UIImage *image, NSDictionary *metadata, NSError *error))onCapture {
    [self capture:onCapture exactSeenImage:NO];
}

- (void)capture:(void (^)(SMCameraController *camera, UIImage *image, NSDictionary *metadata, NSError *error))onCapture exactSeenImage:(BOOL)exactSeenImage {
    
    [self capture:onCapture exactSeenImage:exactSeenImage animationBlock:^(AVCaptureVideoPreviewLayer *layer) {
        CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"opacity"];
        animation.duration = 0.1;
        animation.autoreverses = YES;
        animation.repeatCount = 0.0;
        animation.fromValue = [NSNumber numberWithFloat:1.0];
        animation.toValue = [NSNumber numberWithFloat:0.1];
        animation.fillMode = kCAFillModeForwards;
        animation.removedOnCompletion = NO;
        [layer addAnimation:animation forKey:@"animateOpacity"];
    }];
}

- (void)capture:(void (^)(SMCameraController *camera, UIImage *image, NSDictionary *metadata, NSError *error))onCapture exactSeenImage:(BOOL)exactSeenImage animationBlock:(void (^)(AVCaptureVideoPreviewLayer *))animationBlock {
    if (!self.session) {
        NSError *error = [NSError errorWithDomain:SMCameraErrorDomain
                                             code:SMCameraErrorCodeSession
                                         userInfo:nil];
        onCapture(self, nil, nil, error);
        return;
    }
    
    // get connection and set orientation
    AVCaptureConnection *videoConnection = [self captureConnection];
    videoConnection.videoOrientation = [SMCameraController orientationForConnection];
    
    BOOL flashActive = self.videoCaptureDevice.flashActive;
    if (!flashActive && animationBlock) {
        animationBlock(self.captureVideoPreviewLayer);
    }
    
    [self.stillImageOutput captureStillImageAsynchronouslyFromConnection:videoConnection completionHandler: ^(CMSampleBufferRef imageSampleBuffer, NSError *error) {
        
        UIImage *image = nil;
        NSDictionary *metadata = nil;
        
        // check if we got the image buffer
        if (imageSampleBuffer != NULL) {
            CFDictionaryRef exifAttachments = CMGetAttachment(imageSampleBuffer, kCGImagePropertyExifDictionary, NULL);
            if(exifAttachments) {
                metadata = (__bridge NSDictionary*)exifAttachments;
            }
            
            NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageSampleBuffer];
            image = [[UIImage alloc] initWithData:imageData];
            
            if (exactSeenImage) {
                image = [self cropImage:image usingPreviewLayer:self.captureVideoPreviewLayer];
            }
            
            if (self.fixOrientationAfterCapture) {
                image = [image sc_fixOrientation];
            }
        }
        
        // trigger the block
        if (onCapture) {
            dispatch_async(dispatch_get_main_queue(), ^{
                onCapture(self, image, metadata, error);
            });
        }
    }];
}

- (SMCameraPosition)togglePosition {
    
    SMCameraPosition position = self.position == SMCameraPositionRear ? SMCameraPositionFront : SMCameraPositionRear;

    if (!self.session ||
        position == self.position ||
        (position == SMCameraPositionRear && ![self.class isRearCameraAvailable]) ||
        (position == SMCameraPositionFront && ![self.class isFrontCameraAvailable])) {
        return self.position;
    }
    
    [self.session beginConfiguration];
    
    // remove existing input
    [self.session removeInput:self.videoDeviceInput];
    
    // get new input
    AVCaptureDevice *device = nil;
    if (self.videoDeviceInput.device.position == AVCaptureDevicePositionBack) {
        device = [self cameraWithPosition:AVCaptureDevicePositionFront];
    } else {
        device = [self cameraWithPosition:AVCaptureDevicePositionBack];
    }
    
    if (!device) {
        return self.position;
    }
    
    // add input to session
    NSError *error = nil;
    AVCaptureDeviceInput *videoInput = [[AVCaptureDeviceInput alloc] initWithDevice:device error:&error];
    if (error) {
        [self passError:error];
        [self.session commitConfiguration];
        return self.position;
    }
    
    _position = position;
    
    [self.session addInput:videoInput];
    [self.session commitConfiguration];
    
    self.videoCaptureDevice = device;
    self.videoDeviceInput = videoInput;
    
    return self.position;
}

- (BOOL)updateFlashMode:(SMCameraFlash)cameraFlash {
    if (!self.session) {
        return NO;
    }
    
    AVCaptureFlashMode flashMode;
    
    if (cameraFlash == SMCameraFlashOn) {
        flashMode = AVCaptureFlashModeOn;
    } else if (cameraFlash == SMCameraFlashAuto) {
        flashMode = AVCaptureFlashModeAuto;
    } else {
        flashMode = AVCaptureFlashModeOff;
    }
    
    if ([self.videoCaptureDevice isFlashModeSupported:flashMode]) {
        NSError *error;
        if ([self.videoCaptureDevice lockForConfiguration:&error]) {
            self.videoCaptureDevice.flashMode = flashMode;
            [self.videoCaptureDevice unlockForConfiguration];
            
            _flash = cameraFlash;
            return YES;
        } else {
            [self passError:error];
            return NO;
        }
    }
    else {
        return NO;
    }
}

- (BOOL)isFlashAvailable {
    return self.videoCaptureDevice.hasFlash && self.videoCaptureDevice.isFlashAvailable;
}

+ (BOOL)isFrontCameraAvailable {
    return [UIImagePickerController isCameraDeviceAvailable:UIImagePickerControllerCameraDeviceFront];
}

+ (BOOL)isRearCameraAvailable {
    return [UIImagePickerController isCameraDeviceAvailable:UIImagePickerControllerCameraDeviceRear];
}

#pragma mark - Setter

- (void)setVideoCaptureDevice:(AVCaptureDevice *)videoCaptureDevice {
    _videoCaptureDevice = videoCaptureDevice;
    
    if (videoCaptureDevice.flashMode == AVCaptureFlashModeAuto) {
        _flash = SMCameraFlashAuto;
    } else if(videoCaptureDevice.flashMode == AVCaptureFlashModeOn) {
        _flash = SMCameraFlashOn;
    } else if(videoCaptureDevice.flashMode == AVCaptureFlashModeOff) {
        _flash = SMCameraFlashOff;
    } else {
        _flash = SMCameraFlashOff;
    }
    
    _effectiveScale = 1.0f;
    
    // trigger block
    if (self.onDeviceChange) {
        __weak typeof(self) weakSelf = self;
        self.onDeviceChange(weakSelf, videoCaptureDevice);
    }
}

- (void)setWhiteBalanceMode:(AVCaptureWhiteBalanceMode)whiteBalanceMode {
    if ([self.videoCaptureDevice isWhiteBalanceModeSupported:whiteBalanceMode]) {
        NSError *error;
        if ([self.videoCaptureDevice lockForConfiguration:&error]) {
            [self.videoCaptureDevice setWhiteBalanceMode:whiteBalanceMode];
            [self.videoCaptureDevice unlockForConfiguration];
        } else {
            [self passError:error];
        }
    }
}

#pragma mark - Pinch

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    if ([gestureRecognizer isKindOfClass:[UIPinchGestureRecognizer class]]) {
        self.beginGestureScale = self.effectiveScale;
    }
    return YES;
}

- (void)handlePinchGesture:(UIPinchGestureRecognizer *)recognizer {
    BOOL allTouchesAreOnThePreviewLayer = YES;
    NSUInteger numTouches = [recognizer numberOfTouches], i;
    for (i = 0; i < numTouches; ++i) {
        CGPoint location = [recognizer locationOfTouch:i inView:self.preview];
        CGPoint convertedLocation = [self.preview.layer convertPoint:location fromLayer:self.view.layer];
        if (![self.preview.layer containsPoint:convertedLocation]) {
            allTouchesAreOnThePreviewLayer = NO;
            break;
        }
    }
    
    if (allTouchesAreOnThePreviewLayer) {
        self.effectiveScale = self.beginGestureScale * recognizer.scale;
        if (self.effectiveScale < 1.0f)
            self.effectiveScale = 1.0f;
        if (self.effectiveScale > self.videoCaptureDevice.activeFormat.videoMaxZoomFactor)
            self.effectiveScale = self.videoCaptureDevice.activeFormat.videoMaxZoomFactor;
        NSError *error = nil;
        if ([self.videoCaptureDevice lockForConfiguration:&error]) {
            [self.videoCaptureDevice rampToVideoZoomFactor:self.effectiveScale withRate:100];
            [self.videoCaptureDevice unlockForConfiguration];
        } else {
            [self passError:error];
        }
    }
}

#pragma mark - Focus

- (void)addDefaultFocusBox {
    CALayer *focusBox = [[CALayer alloc] init];
    focusBox.cornerRadius = 5.0f;
    focusBox.bounds = CGRectMake(0.0f, 0.0f, 70, 60);
    focusBox.borderWidth = 3.0f;
    focusBox.borderColor = [[UIColor yellowColor] CGColor];
    focusBox.opacity = 0.0f;
    [self.view.layer addSublayer:focusBox];
    
    CABasicAnimation *focusBoxAnimation = [CABasicAnimation animationWithKeyPath:@"opacity"];
    focusBoxAnimation.duration = 0.75;
    focusBoxAnimation.autoreverses = NO;
    focusBoxAnimation.repeatCount = 0.0;
    focusBoxAnimation.fromValue = [NSNumber numberWithFloat:1.0];
    focusBoxAnimation.toValue = [NSNumber numberWithFloat:0.0];
    
    self.focusBoxLayer = focusBox;
    self.focusBoxAnimation = focusBoxAnimation;
}

- (void)previewTapped:(UIGestureRecognizer *)gestureRecognizer {
    if (!self.tapToFocus) {
        return;
    }
    
    CGPoint touchedPoint = [gestureRecognizer locationInView:self.preview];
    CGPoint pointOfInterest = [self convertToPointOfInterestFromViewCoordinates:touchedPoint
                                                                   previewLayer:self.captureVideoPreviewLayer
                                                                          ports:self.videoDeviceInput.ports];
    [self focusAtPoint:pointOfInterest];
    [self showFocusBox:touchedPoint];
}

- (void)focusAtPoint:(CGPoint)point {
    AVCaptureDevice *device = self.videoCaptureDevice;
    if (device.isFocusPointOfInterestSupported && [device isFocusModeSupported:AVCaptureFocusModeAutoFocus]) {
        NSError *error;
        if ([device lockForConfiguration:&error]) {
            device.focusPointOfInterest = point;
            device.focusMode = AVCaptureFocusModeAutoFocus;
            [device unlockForConfiguration];
        } else {
            [self passError:error];
        }
    }
}

- (void)showFocusBox:(CGPoint)point {
    if (self.focusBoxLayer) {
        // clear animations
        [self.focusBoxLayer removeAllAnimations];
        
        // move layer to the touch point
        [CATransaction begin];
        [CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];
        self.focusBoxLayer.position = point;
        [CATransaction commit];
    }
    
    if (self.focusBoxAnimation) {
        // run the animation
        [self.focusBoxLayer addAnimation:self.focusBoxAnimation forKey:@"animateOpacity"];
    }
}

@end
