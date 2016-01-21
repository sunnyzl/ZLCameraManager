//
//  ZLCameraViewController.m
//  ZLCameraManagerDemo
//
//  Created by zhaoliang on 16/1/18.
//  Copyright © 2016年 zhao. All rights reserved.
//

#import "ZLCameraViewController.h"
#import "ZLCameraManager.h"
#import "ImageViewController.h"
#import "VideoViewController.h"
#import "UIImage+Resize.h"

@interface ZLCameraViewController ()
@property (weak, nonatomic) IBOutlet UISegmentedControl *segmentControl;
@property (weak, nonatomic) IBOutlet UIView *preview;
@property (weak, nonatomic) IBOutlet UIButton *captureBtn;
@property (strong, nonatomic) ZLCameraManager *cameraManager;
@property (weak, nonatomic) IBOutlet UIButton *flashBtn;

@property (weak, nonatomic) IBOutlet UILabel *errorLabel;
@property (weak, nonatomic) IBOutlet UIButton *switchBtn;
@end

@implementation ZLCameraViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    _cameraManager = [[ZLCameraManager alloc] initWithSessionQuality:AVCaptureSessionPreset640x480 positionType:ZLCameraPositionTypeRear videoType:ZLCameraVideoTypeBoth audioType:ZLCameraAudioTypeOff];
    [_cameraManager configurePreviewLayerWithPreview:_preview];
    [_cameraManager startRunning];
    [_cameraManager fetchCurrentDeviceOrientation:^(ZLCameraManager *cameraManager, ZLCameraCurrentOrientationType deviceOrientation) {
        //  如果需要像系统相机或者微信相机那样根据设备旋转而改变部分控件布局，请在此做操作
        NSLog(@"deviceOrientation:%d", (int)deviceOrientation);
    }];
    
    __weak typeof(self) weakSelf = self;
    [_cameraManager setupDeviceChangedBlock:^(ZLCameraManager *cameraManager, AVCaptureDevice *device) {
        NSLog(@"切换前后置摄像头");
        
        // device changed, check if flash is available
        if([cameraManager isFlashAvailable]) {
            weakSelf.flashBtn.hidden = NO;
            
            if(cameraManager.flashMode == ZLCameraFlashModeTypeOff) {
                weakSelf.flashBtn.selected = NO;
            }
            else {
                weakSelf.flashBtn.selected = YES;
            }
        }
        else {
            weakSelf.flashBtn.hidden = YES;
        }
    }];
    [_cameraManager fetchCameraError:^(ZLCameraManager *cameraManager, NSError *error) {
        NSLog(@"error: %@", error);
        
        if([error.domain isEqualToString:ZLCameraManagerErrorDomain]) {
            if(error.code == ZLCameraManagerErrorCodeCameraAuthorization ||
               error.code == ZLCameraManagerErrorCodeMicrophoneAuthorization) {
                weakSelf.errorLabel.hidden = NO;
                weakSelf.errorLabel.text = @"请进入设置->隐私，进行授权";
            } else {
                weakSelf.errorLabel.hidden = YES;
            }
        }
    }];
}
- (IBAction)flashBtnPressed:(UIButton *)sender {
    if(self.cameraManager.flashMode == ZLCameraFlashModeTypeOff) {
        BOOL done = [self.cameraManager updateFlashMode:ZLCameraFlashModeTypeOn];
        if(done) {
            self.flashBtn.selected = YES;
            self.flashBtn.tintColor = [UIColor yellowColor];
        }
    }
    else {
        BOOL done = [self.cameraManager updateFlashMode:ZLCameraFlashModeTypeOff];
        if(done) {
            self.flashBtn.selected = NO;
            self.flashBtn.tintColor = [UIColor whiteColor];
        }
    }
}
- (IBAction)switchBtnPressed:(UIButton *)sender {
    [self.cameraManager switchPosition];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)segmentClick:(UISegmentedControl *)sender {
    switch (sender.selectedSegmentIndex) {
        case 0:
            NSLog(@"photo");
            break;
        case 1:
            NSLog(@"video");
            break;
    }
}
- (IBAction)captureBtnDidClick:(UIButton *)sender {
    __weak typeof(self) weakSelf = self;
    if (self.segmentControl.selectedSegmentIndex == 0) {
        [self.cameraManager captureImage:^(ZLCameraManager *cameraManager, UIImage *image, NSDictionary *metadata, NSError *error) {
            if (!error) {
                //  可在此对图片进行压缩
                UIImage *newImage = [image resizedImageToSize:CGSizeMake(480, 640)];
                ImageViewController *imageVC = [[ImageViewController alloc] initWithImage:newImage];
                [weakSelf presentViewController:imageVC animated:NO completion:nil];
            } else {
                NSLog(@"error");
            }
        } realPhysicalPixel:NO];
    } else {
        if(!weakSelf.cameraManager.isRecording) {
            weakSelf.segmentControl.hidden = YES;
            weakSelf.flashBtn.hidden = YES;
            weakSelf.switchBtn.hidden = YES;
            
            weakSelf.switchBtn.layer.borderColor = [UIColor redColor].CGColor;
            weakSelf.switchBtn.backgroundColor = [[UIColor redColor] colorWithAlphaComponent:0.5];
            NSURL *outputURL = [[[self applicationDocumentsDirectory]
                                 URLByAppendingPathComponent:@"test1"] URLByAppendingPathExtension:@"mov"];
            [weakSelf.cameraManager startRecordingWithOutputURL:outputURL];
            
        } else {
            weakSelf.segmentControl.hidden = NO;
            weakSelf.flashBtn.hidden = NO;
            weakSelf.switchBtn.hidden = NO;
            
            weakSelf.captureBtn.layer.borderColor = [UIColor whiteColor].CGColor;
            weakSelf.captureBtn.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.5];
            [weakSelf.cameraManager stopRecordingVideo:^(ZLCameraManager *cameraManager, NSURL *outPutFileURL, NSError *error) {
                VideoViewController *vc = [[VideoViewController alloc] initWithVideoUrl:outPutFileURL];
                [weakSelf presentViewController:vc animated:NO completion:nil];
            }];
        }
    }
}

- (NSURL *)applicationDocumentsDirectory
{
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    [_cameraManager setupPreviewFrameWithPreview:_preview];
}

@end
