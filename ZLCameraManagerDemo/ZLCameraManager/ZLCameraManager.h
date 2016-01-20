//
//  ZLCameraManager.h
//  ZLCameraManagerDemo
//
//  Created by zhaoliang on 16/1/14.
//  Copyright © 2016年 zhao. All rights reserved.
//

#import <Foundation/Foundation.h>
@import AVFoundation;
@import UIKit;


typedef NS_ENUM(NSUInteger, ZLCameraPositionType) {
    ZLCameraPositionTypeRear,   //  后置摄像头
    ZLCameraPositionTypeFront   //  前置摄像头
};

typedef NS_ENUM(NSUInteger, ZLCameraVideoType) {
    ZLCameraVideoTypeImage,   //  静态图像
    ZLCameraVideoTypeVideo,   //  视频图像
    ZLCameraVideoTypeBoth     //  静态图像和视频图像
};

typedef NS_ENUM(NSUInteger, ZLCameraAudioType) {
    ZLCameraAudioTypeOn,    //  录制音频
    ZLCameraAudioTypeOff    //  不录制音频
};

typedef NS_ENUM(NSUInteger, ZLCameraFlashModeType) {
    ZLCameraFlashModeTypeOff,   //  关闭闪光灯
    ZLCameraFlashModeTypeOn,    //  打开闪光灯
    ZLCameraFlashModeTypeAuto   //  闪光灯自动
};

//  默认为off
typedef NS_ENUM(NSUInteger, ZLCameraMirrorModeType) {
    ZLCameraMirrorModeTypeOff,  //  关闭视频镜像
    ZLCameraMirrorModeTypeOn,   //  打开视频镜像
    ZLCameraMirrorModeTypeAuto  //  视频镜像自动
};

typedef NS_ENUM(NSUInteger, ZLCameraOutputOrientationType) {
    ZLCameraOutputOrientationTypePortrait,   //  画面从上到下（即home键在下方）
    ZLCameraOutputOrientationTypeLandscapeRight, //  画面从左到右（即home键在右方）
    ZLCameraOutputOrientationTypeAuto    //  画面根据手机旋转改变（即home键在下方或者右方）
};

typedef NS_ENUM(NSUInteger, ZLCameraCurrentOrientationType) {
    ZLCameraCurrentOrientationTypePortrait,
    ZLCameraCurrentOrientationTypePortraitUpsideDown,
    ZLCameraCurrentOrientationTypeLandscapeLeft,
    ZLCameraCurrentOrientationTypeLandscapeRight
};

extern NSString *const ZLCameraManagerErrorDomain;

typedef NS_ENUM(NSUInteger, ZLCameraManagerErrorCode) {
    ZLCameraManagerErrorCodeCameraAuthorization = 1000,
    ZLCameraManagerErrorCodeMicrophoneAuthorization,
    ZLCameraManagerErrorCodeSessionNotEnabled,
    ZLCameraManagerErrorCodeVideoNotEnabled
};

@class ZLCameraManager;
typedef void(^ZLCameraManagerRequestCameraAuthorization)(BOOL granted);
typedef void(^ZLCameraManagerDeviceChanged)(ZLCameraManager *cameraManager, AVCaptureDevice *device);
typedef void(^ZLCameraManagerError)(ZLCameraManager *cameraManager, NSError *error);
typedef void(^ZLCameraManagerStopRecordingVideo)(ZLCameraManager *cameraManager, NSURL *outPutFileURL, NSError *error);
typedef void(^ZLCameraManagerCaptureImage)(ZLCameraManager *cameraManager, UIImage *image, NSDictionary *metadata, NSError *error);
typedef void(^ZLCameraManagerDeviceCurrentOrientation)(ZLCameraManager *cameraManager, ZLCameraCurrentOrientationType deviceOrientation);

@interface ZLCameraManager : NSObject
/**
 *  闪光灯模式
 */
@property (nonatomic, assign, readonly) ZLCameraFlashModeType flashMode;
/**
 *  是否正在录制视频  yesOrNo
 */
@property (nonatomic, assign, getter=isRecording) BOOL recording;
/**
 * YES为点击屏幕后在对焦点显示一个方框来提示，NO为不显示此方框
 */
@property (nonatomic, assign) BOOL tapToFocus;
/**
 *  保存到设备上的照片是否进行方向转换(默认为NO)
 */
@property (nonatomic) BOOL fixOrientationAfterCapture;
/**
 *  输出文件的朝向（在初始化方法之后，configurePreviewLayerWithPreview方法前设置）
 */
@property (nonatomic, assign) ZLCameraOutputOrientationType outputOrientationType;
/**
 *  获取相机错误（在此对错误进行处理，比如相机未授权该如何做）
 *
 *  @param errorBlock 存放错误的block
 */
- (void)fetchCameraError:(ZLCameraManagerError)errorBlock;
/**
 *  初始化ZLCameraManager
 *
 *  @param sessionQuality 画质（分辨率）
 *  @param positionType   摄像头类型（前置还是后置）
 *  @param videoType      拍摄模式（录像还是静态图片）
 *  @param audioType      音频模式（录像时是否录制声音）
 *
 *  @return 实例
 */
- (instancetype)initWithSessionQuality:(NSString *)sessionQuality positionType:(ZLCameraPositionType) positionType videoType:(ZLCameraVideoType)videoType audioType:(ZLCameraAudioType)audioType;
/**
 *  初始化ZLCameraManager（默认为拍摄静态图片）
 *
 *  @param sessionQuality 画质（分辨率）
 *  @param positionType   摄像头类型（前置还是后置）
 *
 *  @return 实例
 */
- (instancetype)initWithSessionQuality:(NSString *)sessionQuality positionType:(ZLCameraPositionType) positionType;
/**
 *  初始化ZLCameraManager（默认分辨率为640*480，后置摄像头）
 *
 *  @param videoType 拍摄模式（录像还是静态图片）
 *  @param audioType 音频模式（录像时是否录制声音）
 *
 *  @return 实例
 */
- (instancetype)initWithVideoType:(ZLCameraVideoType)videoType audioType:(ZLCameraAudioType)audioType;
/**
 *  开始运行
 */
- (void)startRunning;
/**
 *  停止运行
 */
- (void)stopRunning;
/**
 *  当前设备的方向（用于仿微信和系统相机做响应布局）
 *
 *  @param currentOrientation 设备当前的方向
 */
- (void)fetchCurrentDeviceOrientation:(ZLCameraManagerDeviceCurrentOrientation)currentOrientation;
/**
 *  添加预览层
 *
 *  @param preview     将预览层添加到那个view上
 *  @param previewRect 预览层的frame
 */
- (void)configurePreviewLayerWithPreview:(UIView *)preview;
/**
 *  设置预览层尺寸（在controller的viewWillLayoutSubviews中使用）
 *
 *  @param preview 预览层
 */
- (void)setupPreviewFrameWithPreview:(UIView *)preview;

/**
 * 当前后置摄像头切换时在此block中操作
 */
- (void)setupDeviceChangedBlock:(ZLCameraManagerDeviceChanged)deviceChangedBlock;
/**
 *  获取拍摄的相片
 *
 *  @param captureImageBlock 拍摄的照片放在此block中
 *  @param realPhysicalPixel 是否为真实像素（yes即为真实像素，不做裁剪；no为屏幕像素，做裁剪后导出设备后的像素也为屏幕像素，如果需要导出手机后照片为真实像素，请选择yes）
 */
-(void)captureImage:(ZLCameraManagerCaptureImage)captureImageBlock realPhysicalPixel:(BOOL)realPhysicalPixel;
/**
 *  获取拍摄的相片(并对相片进行裁剪)
 *
 *  @param captureImageBlock 拍摄的照片放在此block中
 */
-(void)captureImage:(ZLCameraManagerCaptureImage)captureImageBlock;
/**
 *  开始录制视频图像
 *
 *  @param url 视频保存地址
 */
- (void)startRecordingWithOutputURL:(NSURL *)url;
/**
 *  停止录像并对录制好的文件进行操作
 *
 *  @param stopRecordingBlock 停止录像后文件信息存放在此block中
 */
- (void)stopRecordingVideo:(ZLCameraManagerStopRecordingVideo)stopRecordingBlock;
/**
 *  切换摄像头
 *
 *  @return 当前摄像头为前置还是后置
 */
- (ZLCameraPositionType)switchPosition;
/**
 *  更新闪光灯模式（主要用于拍摄静态图片为闪光灯，录像为手电筒模式）
 *
 *  @param flashMode 闪光灯模式
 *
 *  @return yesOrNo
 */
- (BOOL)updateFlashMode:(ZLCameraFlashModeType)flashMode;
/**
 *  闪光灯是否可用
 *
 *  @return yesOrNo
 */
- (BOOL)isFlashAvailable;
/**
 *  手电筒是否可用
 *
 *  @return yesOrNo
 */
- (BOOL)isTorchAvailable;
/**
 *  前置摄像头是否可用
 *
 *  @return yesOrNo
 */
+ (BOOL)isFrontCameraAvailable;
/**
 *  后置摄像头是否可用
 *
 *  @return yesOrNo
 */
+ (BOOL)isRearCameraAvailable;

@end
