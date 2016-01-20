//
//  ZLCameraManager.m
//  ZLCameraManagerDemo
//
//  Created by zhaoliang on 16/1/14.
//  Copyright © 2016年 zhao. All rights reserved.
//

#import "ZLCameraManager.h"
#import <CoreMotion/CoreMotion.h>
#import <ImageIO/ImageIO.h>
#import "UIImage+FixOrientation.h"

@interface ZLCameraManager ()<AVCaptureFileOutputRecordingDelegate>
//  systemProperty
@property (nonatomic, weak) UIView *preview;
@property (nonatomic, strong) UITapGestureRecognizer *tapGesture;
@property (strong, nonatomic) CALayer *focusBoxLayer;
@property (strong, nonatomic) CAAnimation *focusBoxAnimation;
@property (nonatomic, strong) AVCaptureStillImageOutput *stillImageOutput;
@property (nonatomic, strong) AVCaptureSession *session;
@property (nonatomic, strong) AVCaptureDevice *videoCaptureDevice;
@property (nonatomic, strong) AVCaptureDevice *audioCaptureDevice;
@property (nonatomic, strong) AVCaptureDeviceInput *videoDeviceInput;
@property (nonatomic, strong) AVCaptureDeviceInput *audioDeviceInput;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *captureVideoPreviewLayer;
@property (nonatomic, strong) AVCaptureMovieFileOutput *movieFileOutput;
@property (nonatomic, assign) AVCaptureDevicePosition devicePosition;

//  customProperty
@property (nonatomic, copy) ZLCameraManagerError errorBlock;
@property (nonatomic, copy) ZLCameraManagerDeviceChanged deviceChangedBlock;
@property (nonatomic, copy) NSString *sessionQuality;
@property (nonatomic, assign) ZLCameraPositionType positionType;
@property (nonatomic, assign) ZLCameraVideoType videoType;
@property (nonatomic, assign) ZLCameraAudioType audioType;
@property (nonatomic, assign) ZLCameraMirrorModeType mirrorModeType;

@property (nonatomic, copy) ZLCameraManagerStopRecordingVideo didRecord;
@property (nonatomic, copy) ZLCameraManagerDeviceCurrentOrientation currentDeviceOrientation;

//  motionManager
@property (nonatomic, strong) CMMotionManager *motionManager;
@property (nonatomic, assign) ZLCameraCurrentOrientationType preOrientation;
@property (nonatomic, assign) UIDeviceOrientation outputDeviceOrientation;

@end

NSString *const ZLCameraManagerErrorDomain = @"ZLCameraManagerErrorDomain";

@implementation ZLCameraManager
#pragma mark - initialize
- (instancetype)initWithSessionQuality:(NSString *)sessionQuality positionType:(ZLCameraPositionType)positionType videoType:(ZLCameraVideoType)videoType audioType:(ZLCameraAudioType)audioType
{
    if (self = [super init]) {
        [self setupWithSessionQuality:sessionQuality positionType:positionType videoType:videoType audioType:audioType];
    }
    return self;
}

- (instancetype)initWithSessionQuality:(NSString *)sessionQuality positionType:(ZLCameraPositionType)positionType
{
    return [self initWithSessionQuality:sessionQuality positionType:positionType videoType:ZLCameraVideoTypeImage audioType:ZLCameraAudioTypeOff];
}

- (instancetype)initWithVideoType:(ZLCameraVideoType)videoType audioType:(ZLCameraAudioType)audioType
{
    return [self initWithSessionQuality:AVCaptureSessionPreset640x480 positionType:ZLCameraPositionTypeRear videoType:videoType audioType:audioType];
}
/**
 *  默认分辨率为640*480，后置摄像头，可拍摄音频和视频，可录制声音
 *
 *  @return 实例
 */
- (instancetype)init
{
    return [self initWithSessionQuality:AVCaptureSessionPreset640x480 positionType:ZLCameraPositionTypeRear videoType:ZLCameraVideoTypeBoth audioType:ZLCameraAudioTypeOn];
}

- (void)setupWithSessionQuality:(NSString *)sessionQuality positionType:(ZLCameraPositionType)positionType videoType:(ZLCameraVideoType)videoType audioType:(ZLCameraAudioType)audioType
{
    _sessionQuality = [sessionQuality copy];
    _positionType = positionType;
    _tapToFocus = YES;
    _videoType = videoType;
    _audioType = audioType;
    _fixOrientationAfterCapture = NO;
    _recording = NO;
    _flashMode = ZLCameraFlashModeTypeOff;
    _mirrorModeType = ZLCameraMirrorModeTypeAuto;
    _outputOrientationType = ZLCameraOutputOrientationTypeAuto;
}

#pragma mark - Camera
- (void)configurePreviewLayerWithPreview:(UIView *)preview
{
    [self setupSession];
    
    self.preview = preview;
    if (!_captureVideoPreviewLayer) {
        _captureVideoPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.session];
    }
    [self.preview.layer addSublayer:_captureVideoPreviewLayer];
    [self setupTapGestureOfPreview];
    if (_outputOrientationType == ZLCameraOutputOrientationTypeAuto) {
        [self setupMotionManager];
    } else {
        self.currentDeviceOrientation(self, ZLCameraCurrentOrientationTypePortrait);
    }
}
- (void)setupTapGestureOfPreview
{
    // tap to focus
    self.tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(previewTapped:)];
    self.tapGesture.numberOfTapsRequired = 1;
    [self.tapGesture setDelaysTouchesEnded:NO];
    [self.preview addGestureRecognizer:self.tapGesture];
    
    // add focus box to view
    [self addDefaultFocusBox];
}

- (void)fetchCurrentDeviceOrientation:(ZLCameraManagerDeviceCurrentOrientation)currentOrientation
{
    _currentDeviceOrientation = [currentOrientation copy];
}

#pragma mark - Focus

- (void)previewTapped:(UIGestureRecognizer *)gestureRecognizer
{
    CGPoint touchedPoint = (CGPoint) [gestureRecognizer locationInView:self.preview];
    
    // focus
    CGPoint pointOfInterest = [self convertToPointOfInterestFromViewCoordinates:touchedPoint];
    [self focusAtPoint:pointOfInterest];
    
    // show the box
    if (self.tapGesture) {
        [self showFocusBox:touchedPoint];
    }
    
}

- (void)addDefaultFocusBox
{
    CALayer *focusBox = [[CALayer alloc] init];
    focusBox.cornerRadius = 5.0f;
    focusBox.bounds = CGRectMake(0.0f, 0.0f, 70, 60);
    focusBox.borderWidth = 3.0f;
    focusBox.borderColor = [[UIColor yellowColor] CGColor];
    focusBox.opacity = 0.0f;
    [self.preview.layer addSublayer:focusBox];
    
    CABasicAnimation *focusBoxAnimation = [CABasicAnimation animationWithKeyPath:@"opacity"];
    focusBoxAnimation.duration = 0.75;
    focusBoxAnimation.autoreverses = NO;
    focusBoxAnimation.repeatCount = 0.0;
    focusBoxAnimation.fromValue = [NSNumber numberWithFloat:1.0];
    focusBoxAnimation.toValue = [NSNumber numberWithFloat:0.0];
    
    [self alterFocusBox:focusBox animation:focusBoxAnimation];
}

- (void)alterFocusBox:(CALayer *)layer animation:(CAAnimation *)animation
{
    self.focusBoxLayer = layer;
    self.focusBoxAnimation = animation;
}

- (void)focusAtPoint:(CGPoint)point
{
    AVCaptureDevice *device = self.videoCaptureDevice;
    if (device.isFocusPointOfInterestSupported && [device isFocusModeSupported:AVCaptureFocusModeAutoFocus]) {
        NSError *error;
        if ([device lockForConfiguration:&error]) {
            device.focusPointOfInterest = point;
            device.focusMode = AVCaptureFocusModeAutoFocus;
            [device unlockForConfiguration];
        }
        
        if(error && self.errorBlock) {
            self.errorBlock(self, error);
        }
    }
}

- (void)showFocusBox:(CGPoint)point
{
    if(self.focusBoxLayer) {
        // clear animations
        [self.focusBoxLayer removeAllAnimations];
        
        // move layer to the touc point
        [CATransaction begin];
        [CATransaction setValue: (id) kCFBooleanTrue forKey: kCATransactionDisableActions];
        self.focusBoxLayer.position = point;
        [CATransaction commit];
    }
    
    if(self.focusBoxAnimation) {
        // run the animation
        [self.focusBoxLayer addAnimation:self.focusBoxAnimation forKey:@"animateOpacity"];
    }
}

- (CGPoint)convertToPointOfInterestFromViewCoordinates:(CGPoint)viewCoordinates
{
    AVCaptureVideoPreviewLayer *previewLayer = self.captureVideoPreviewLayer;
    
    CGPoint pointOfInterest = CGPointMake(.5f, .5f);
    CGSize frameSize = previewLayer.frame.size;
    
    if ( [previewLayer.videoGravity isEqualToString:AVLayerVideoGravityResize] ) {
        pointOfInterest = CGPointMake(viewCoordinates.y / frameSize.height, 1.f - (viewCoordinates.x / frameSize.width));
    } else {
        CGRect cleanAperture;
        for (AVCaptureInputPort *port in [self.videoDeviceInput ports]) {
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

- (void)setupSession
{
    if (_session == nil) {
        _session = [[AVCaptureSession alloc] init];
        _session.sessionPreset = self.sessionQuality;
        switch (self.positionType) {
            case ZLCameraPositionTypeRear:
                if([self.class isRearCameraAvailable]) {
                    _devicePosition = AVCaptureDevicePositionBack;
                } else {
                    _devicePosition = AVCaptureDevicePositionFront;
                    _positionType = ZLCameraPositionTypeFront;
                }
                break;
            case ZLCameraPositionTypeFront:
                if([self.class isFrontCameraAvailable]) {
                    _devicePosition = AVCaptureDevicePositionFront;
                } else {
                    _devicePosition = AVCaptureDevicePositionBack;
                    _positionType = ZLCameraPositionTypeRear;
                }
                break;
            default:
                _devicePosition = AVCaptureDevicePositionUnspecified;
                break;
        }
    }
}

- (void)setupMotionManager
{
    if (_motionManager == nil) {
        _motionManager = [[CMMotionManager alloc] init];
    }
    // 2.判断加速计是否可用
    if (_motionManager.isAccelerometerAvailable) {
        _motionManager.deviceMotionUpdateInterval = 1;
        // 4.开始采样
        [_motionManager startDeviceMotionUpdatesToQueue:[NSOperationQueue mainQueue] withHandler:^(CMDeviceMotion * _Nullable motion, NSError * _Nullable error) {
            [self performSelectorOnMainThread:@selector(handleDeviceMotion:) withObject:motion waitUntilDone:YES];
        }];
    }else {
        NSLog(@"加速计不可用");
        _motionManager = nil;
    }
}

static ZLCameraCurrentOrientationType currentOrientation;
- (void)handleDeviceMotion:(CMDeviceMotion *)deviceMotion
{
    double x = deviceMotion.gravity.x;
    double y = deviceMotion.gravity.y;
    self.preOrientation = currentOrientation;
    if (fabs(y) >= fabs(x))
    {
        if (y >= 0){
            //  home在上
            currentOrientation = ZLCameraCurrentOrientationTypePortraitUpsideDown;
            
            _outputOrientationType = ZLCameraOutputOrientationTypePortrait;
        }
        else{
            //  home在下
            currentOrientation = ZLCameraCurrentOrientationTypePortrait;
            _outputOrientationType = ZLCameraOutputOrientationTypePortrait;
        }
    }
    else
    {
        if (x >= 0){
            //  home在左
            currentOrientation = ZLCameraCurrentOrientationTypeLandscapeLeft;
            _outputOrientationType = ZLCameraOutputOrientationTypeLandscapeRight;
        }
        else{
            //  home在右
            currentOrientation = ZLCameraCurrentOrientationTypeLandscapeRight;
            _outputOrientationType = ZLCameraOutputOrientationTypeLandscapeRight;
        }
    }
    if (self.preOrientation != currentOrientation) {
        self.currentDeviceOrientation(self, currentOrientation);
    }
}



- (void)stopDeviceMotion
{
    [_motionManager stopDeviceMotionUpdates];;
}

- (void)setupPreviewFrameWithPreview:(UIView *)preview
{
    CGRect bounds = self.preview.layer.bounds;
    _captureVideoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    _captureVideoPreviewLayer.bounds = bounds;
    _captureVideoPreviewLayer.position = CGPointMake(CGRectGetMidX(bounds), CGRectGetMidY(bounds));
}

- (void)startRunning
{
    [ZLCameraManager requestCameraAuthorization:^(BOOL granted) {
        if(granted) {
            if(self.videoType != ZLCameraVideoTypeImage && self.audioType == ZLCameraAudioTypeOn) {
                [ZLCameraManager requestMicrophoneAuthorization:^(BOOL granted) {
                    if(granted) {
                        [self initialize];
                    }
                    else {
                        NSError *error = [NSError errorWithDomain:ZLCameraManagerErrorDomain
                                                             code:ZLCameraManagerErrorCodeMicrophoneAuthorization
                                                         userInfo:nil];
                        if(self.errorBlock) {
                            self.errorBlock(self, error);
                        }
                    }
                }];
            }
            else {
                [self initialize];
            }
        }
        else {
            NSError *error = [NSError errorWithDomain:ZLCameraManagerErrorDomain
                                                 code:ZLCameraManagerErrorCodeCameraAuthorization
                                             userInfo:nil];
            if(self.errorBlock) {
                self.errorBlock(self, error);
            }
        }
    }];
}

- (void)initialize
{
    
    if(_devicePosition == AVCaptureDevicePositionUnspecified) {
        _videoCaptureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    } else {
        _videoCaptureDevice = [self cameraWithPosition:_devicePosition];
    }
    
    NSError *error = nil;
    _videoDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:_videoCaptureDevice error:&error];
    
    if (!_videoDeviceInput) {
        if(self.errorBlock) {
            self.errorBlock(self, error);
        }
        return;
    }
    
    if([self.session canAddInput:_videoDeviceInput]) {
        [self.session  addInput:_videoDeviceInput];
        self.captureVideoPreviewLayer.connection.videoOrientation = AVCaptureVideoOrientationPortrait;
    }
    
    if(self.videoType != ZLCameraVideoTypeImage) {
        if (self.audioType == ZLCameraAudioTypeOn) {
            _audioCaptureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
            _audioDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:_audioCaptureDevice error:&error];
            if (!_audioDeviceInput) {
                if(self.errorBlock) {
                    self.errorBlock(self, error);
                }
            }
            
            if([self.session canAddInput:_audioDeviceInput]) {
                [self.session addInput:_audioDeviceInput];
            }
        }
        
        _movieFileOutput = [[AVCaptureMovieFileOutput alloc] init];
        [_movieFileOutput setMovieFragmentInterval:kCMTimeInvalid];
        if([self.session canAddOutput:_movieFileOutput]) {
            [self.session addOutput:_movieFileOutput];
        }
    }
    
    if (self.videoType != ZLCameraVideoTypeVideo) {
        self.stillImageOutput = [[AVCaptureStillImageOutput alloc] init];
        NSDictionary *outputSettings = [[NSDictionary alloc] initWithObjectsAndKeys: AVVideoCodecJPEG, AVVideoCodecKey, nil];
        [self.stillImageOutput setOutputSettings:outputSettings];
        [self.session addOutput:self.stillImageOutput];
    }
    
    if (![self.captureVideoPreviewLayer.connection isEnabled]) {
        [self.captureVideoPreviewLayer.connection setEnabled:YES];
    }
    [self.session startRunning];
}

- (void)stopRunning
{
    [self stopDeviceMotion];
    [self.session stopRunning];
}

#pragma mark - Image Capture

- (void)captureImage:(ZLCameraManagerCaptureImage)captureImageBlock realPhysicalPixel:(BOOL)realPhysicalPixel
{
    [self stopDeviceMotion];
    if(!self.session) {
        NSError *error = [NSError errorWithDomain:ZLCameraManagerErrorDomain
                                             code:ZLCameraManagerErrorCodeSessionNotEnabled
                                         userInfo:nil];
        captureImageBlock(self, nil, nil, error);
        return;
    }
    
    AVCaptureConnection *videoConnection = [self captureConnection];
    if (self.outputOrientationType == ZLCameraOutputOrientationTypePortrait) {
        videoConnection.videoOrientation = AVCaptureVideoOrientationPortrait;
    } else if (self.outputOrientationType == ZLCameraOutputOrientationTypeLandscapeRight) {
        videoConnection.videoOrientation = AVCaptureVideoOrientationLandscapeRight;
    }
    [self.stillImageOutput captureStillImageAsynchronouslyFromConnection:videoConnection completionHandler:^(CMSampleBufferRef imageSampleBuffer, NSError *error) {
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
            if(!realPhysicalPixel) {
                image = [self cropImageUsingPreviewBounds:image];
            }
            if(self.fixOrientationAfterCapture) {
                image = [image fixOrientation];
            }
        }
        
        if(captureImageBlock) {
            dispatch_async(dispatch_get_main_queue(), ^{
                captureImageBlock(self, image, metadata, error);
            });
        }
    }];
    [self setupMotionManager];
    
}

- (UIImage *)cropImageUsingPreviewBounds:(UIImage *)image
{
    CGRect previewBounds = self.captureVideoPreviewLayer.bounds;
    CGRect outputRect = [self.captureVideoPreviewLayer metadataOutputRectOfInterestForRect:previewBounds];
    
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

- (void)captureImage:(ZLCameraManagerCaptureImage)captureImageBlock
{
    [self captureImage:captureImageBlock realPhysicalPixel:NO];
}

#pragma mark - Video Capture

- (void)startRecordingWithOutputURL:(NSURL *)url
{
    [self stopDeviceMotion];
    if(self.videoType == ZLCameraVideoTypeImage) {
        NSError *error = [NSError errorWithDomain:ZLCameraManagerErrorDomain
                                             code:ZLCameraManagerErrorCodeVideoNotEnabled
                                         userInfo:nil];
        if(self.errorBlock) {
            self.errorBlock(self, error);
        }
        
        return;
    }
    if (self.flashMode == ZLCameraFlashModeTypeOn) {
        [self enableTorch:YES];
    }
    
    // set video orientation
    for(AVCaptureConnection *connection in [self.movieFileOutput connections]) {
        
        for (AVCaptureInputPort *port in [connection inputPorts]) {
            // get only the video media types
            if ([[port mediaType] isEqual:AVMediaTypeVideo]) {
                if([connection isVideoOrientationSupported]) {
                    
                    if (self.outputOrientationType == ZLCameraOutputOrientationTypePortrait) {
                        connection.videoOrientation = AVCaptureVideoOrientationPortrait;
                    } else if (self.outputOrientationType == ZLCameraOutputOrientationTypeLandscapeRight) {
                        connection.videoOrientation = AVCaptureVideoOrientationLandscapeRight;
                    }
                }
            }
        }
    }
    [self.movieFileOutput startRecordingToOutputFileURL:url recordingDelegate:self];
    
}

- (void)stopRecordingVideo:(ZLCameraManagerStopRecordingVideo)stopRecordingBlock
{
    if(self.videoType == ZLCameraVideoTypeImage) {
        return;
    }
    
    self.didRecord = [stopRecordingBlock copy];
    [self.movieFileOutput stopRecording];
    [self setupMotionManager];
}

- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didStartRecordingToOutputFileAtURL:(NSURL *)fileURL fromConnections:(NSArray *)connections
{
    self.recording = YES;
}

- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL fromConnections:(NSArray *)connections error:(NSError *)error
{
    self.recording = NO;
    [self enableTorch:NO];
    
    if(self.didRecord) {
        self.didRecord(self, outputFileURL, error);
    }
}

- (void)setupDeviceChangedBlock:(ZLCameraManagerDeviceChanged)deviceChangedBlock
{
    _deviceChangedBlock = [deviceChangedBlock copy];
}

- (void)enableTorch:(BOOL)enabled
{
    // check if the device has a toch, otherwise don't even bother to take any action.
    if([self isTorchAvailable]) {
        [self.session beginConfiguration];
        [self.videoCaptureDevice lockForConfiguration:nil];
        if (enabled) {
            [self.videoCaptureDevice setTorchMode:AVCaptureTorchModeOn];
        } else {
            [self.videoCaptureDevice setTorchMode:AVCaptureTorchModeOff];
        }
        [self.videoCaptureDevice unlockForConfiguration];
        [self.session commitConfiguration];
    }
}



//  仅在内部实现set方法，可以使用self.调用此方法
- (void)setCameraPosition:(ZLCameraPositionType)cameraPosition
{
    if(_positionType == cameraPosition || !self.session) {
        return;
    }
    
    if(cameraPosition == ZLCameraPositionTypeRear && ![self.class isRearCameraAvailable]) {
        return;
    }
    
    if(cameraPosition == ZLCameraPositionTypeFront && ![self.class isFrontCameraAvailable]) {
        return;
    }
    
    [self.session beginConfiguration];
    
    // 移除现有input
    [self.session removeInput:self.videoDeviceInput];
    
    // 获取新的input
    AVCaptureDevice *device = nil;
    if(self.videoDeviceInput.device.position == AVCaptureDevicePositionBack) {
        device = [self cameraWithPosition:AVCaptureDevicePositionFront];
    } else {
        device = [self cameraWithPosition:AVCaptureDevicePositionBack];
    }
    
    if(!device) {
        return;
    }
    
    // 添加新的输入到会话
    NSError *error = nil;
    AVCaptureDeviceInput *videoInput = [[AVCaptureDeviceInput alloc] initWithDevice:device error:&error];
    if(error) {
        if(self.errorBlock) {
            self.errorBlock(self, error);
        }
        [self.session commitConfiguration];
        return;
    }
    
    _positionType = cameraPosition;
    
    [self.session addInput:videoInput];
    [self.session commitConfiguration];
    
    self.videoCaptureDevice = device;
    self.videoDeviceInput = videoInput;
    //  设置视频镜像模式
    [self setupMirrorMode];
}

- (void)setupMirrorMode
{
    if(!self.session) {
        return;
    }
    
    AVCaptureConnection *videoConnection = [_movieFileOutput connectionWithMediaType:AVMediaTypeVideo];
    AVCaptureConnection *pictureConnection = [_stillImageOutput connectionWithMediaType:AVMediaTypeVideo];
    
    switch (_mirrorModeType) {
        case ZLCameraMirrorModeTypeOff: {
            if ([videoConnection isVideoMirroringSupported]) {
                [videoConnection setVideoMirrored:NO];
            }
            
            if ([pictureConnection isVideoMirroringSupported]) {
                [pictureConnection setVideoMirrored:NO];
            }
            break;
        }
            
        case ZLCameraMirrorModeTypeOn: {
            if ([videoConnection isVideoMirroringSupported]) {
                [videoConnection setVideoMirrored:YES];
            }
            
            if ([pictureConnection isVideoMirroringSupported]) {
                [pictureConnection setVideoMirrored:YES];
            }
            break;
        }
            
        case ZLCameraMirrorModeTypeAuto: {
            BOOL shouldMirror = (_positionType == ZLCameraPositionTypeFront);
            if ([videoConnection isVideoMirroringSupported]) {
                [videoConnection setVideoMirrored:shouldMirror];
            }
            
            if ([pictureConnection isVideoMirroringSupported]) {
                [pictureConnection setVideoMirrored:shouldMirror];
            }
            break;
        }
    }
}

- (AVCaptureDevice *) cameraWithPosition:(AVCaptureDevicePosition) position
{
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in devices) {
        if (device.position == position) {
            return device;
        }
    }
    return nil;
}

- (AVCaptureConnection *)captureConnection
{
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

- (void)setVideoCaptureDevice:(AVCaptureDevice *)videoCaptureDevice
{
    _videoCaptureDevice = videoCaptureDevice;
    if(videoCaptureDevice.flashMode == AVCaptureFlashModeAuto) {
        _flashMode = ZLCameraFlashModeTypeAuto;
    } else if(videoCaptureDevice.flashMode == AVCaptureFlashModeOn) {
        _flashMode = ZLCameraFlashModeTypeOn;
    } else if(videoCaptureDevice.flashMode == AVCaptureFlashModeOff) {
        _flashMode = ZLCameraFlashModeTypeOff;
    } else {
        _flashMode = ZLCameraFlashModeTypeOff;
    }
    
    if (self.deviceChangedBlock) {
        self.deviceChangedBlock(self, videoCaptureDevice);
    }
}

#pragma mark - Public Method

- (ZLCameraPositionType)switchPosition
{
    
    if(!self.session) {
        return self.positionType;
    }
    
    if(self.positionType == ZLCameraPositionTypeRear) {
        self.cameraPosition = ZLCameraPositionTypeFront;
        NSLog(@"switchRear");
    } else {
        self.cameraPosition = ZLCameraPositionTypeRear;
        NSLog(@"switchFront");
    }
    
    return self.positionType;
}

#pragma mark - Private Method

- (BOOL)updateFlashMode:(ZLCameraFlashModeType)cameraFlashType
{
    if(!self.session)
        return NO;
    
    AVCaptureFlashMode flashMode;
    switch (cameraFlashType) {
        case ZLCameraFlashModeTypeOff: {
            flashMode = AVCaptureFlashModeOff;
            break;
        }
        case ZLCameraFlashModeTypeOn: {
            flashMode = AVCaptureFlashModeOn;
            break;
        }
        case ZLCameraFlashModeTypeAuto: {
            flashMode = AVCaptureFlashModeAuto;
            break;
        }
    }
    
    if([self.videoCaptureDevice isFlashModeSupported:flashMode]) {
        NSError *error;
        if([self.videoCaptureDevice lockForConfiguration:&error]) {
            self.videoCaptureDevice.flashMode = flashMode;
            [self.videoCaptureDevice unlockForConfiguration];
            
            _flashMode = cameraFlashType;
            return YES;
        }
        else {
            if(self.errorBlock) {
                self.errorBlock(self, error);
            }
            return NO;
        }
    }
    else {
        return NO;
    }
}

- (void)fetchCameraError:(ZLCameraManagerError)errorBlock
{
    _errorBlock = [errorBlock copy];
}

- (BOOL)isFlashAvailable
{
    return self.videoCaptureDevice.hasFlash && self.videoCaptureDevice.isFlashAvailable;
}

- (BOOL)isTorchAvailable
{
    return self.videoCaptureDevice.hasTorch && self.videoCaptureDevice.isTorchAvailable;
}

#pragma mark - Class Method
+ (void)requestCameraAuthorization:(ZLCameraManagerRequestCameraAuthorization)cameraAutorizationBlock
{
    if ([AVCaptureDevice respondsToSelector:@selector(requestAccessForMediaType: completionHandler:)]) {
        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
            // return to main thread
            dispatch_async(dispatch_get_main_queue(), ^{
                if(cameraAutorizationBlock) {
                    cameraAutorizationBlock(granted);
                }
            });
        }];
    } else {
        cameraAutorizationBlock(YES);
    }
    
}

+ (void)requestMicrophoneAuthorization:(ZLCameraManagerRequestCameraAuthorization)microphoneAuthorizationBlock
{
    if([[AVAudioSession sharedInstance] respondsToSelector:@selector(requestRecordPermission:)]) {
        [[AVAudioSession sharedInstance] requestRecordPermission:^(BOOL granted) {
            // return to main thread
            dispatch_async(dispatch_get_main_queue(), ^{
                if(microphoneAuthorizationBlock) {
                    microphoneAuthorizationBlock(granted);
                }
            });
        }];
    }
}

+ (BOOL)isFrontCameraAvailable
{
    return [UIImagePickerController isCameraDeviceAvailable:UIImagePickerControllerCameraDeviceFront];
}

+ (BOOL)isRearCameraAvailable
{
    return [UIImagePickerController isCameraDeviceAvailable:UIImagePickerControllerCameraDeviceRear];
}

- (void)dealloc
{
    [self stopRunning];
}

@end
