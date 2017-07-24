//
//  ZKCaptureSessionManager.m
//  AVFoundationDemo
//
//  Created by MliBo on 2017/7/19.
//  Copyright © 2017年 MliBo. All rights reserved.
//

#import "ZKCaptureSessionManager.h"

@interface ZKCaptureSessionManager ()

@property (nonatomic, strong) dispatch_queue_t   videoQueue;
@property (nonatomic, strong) AVCaptureSession * captureSession;       //捕捉会话
@property (nonatomic,   weak) AVCaptureDeviceInput * activeVideoInput; //当前活跃的摄像头(默认是前置摄像头)
@property (nonatomic, strong) AVCaptureStillImageOutput * imageOutput; //图片输出
@property (nonatomic, strong) AVCaptureMovieFileOutput * movieOutput;  //视频输出
@property (nonatomic, strong) NSURL * outputURL;

@end

static char * ExposureValueChange;

@implementation ZKCaptureSessionManager
#pragma mark - 设置会话
/*
 1.设置captureSession
 2.设置captureDevice (AVMediaTypeVideo)
 3.设置captureDeviceInput (videoInput)
 4.captureSession 添加videoInput
 
 5.设置captureDevice (AVMediaTypeAudio)
 6.设置captureDeviceInput (audioInput)
 7.captureSession 添加audioInput
 
 8.设置AVCaptureStillImageOutput 图片输出
 9.设置图片输出的质量为(@{AVVideoCodecKey:AVVideoCodecJPEG})
 10.captureSession 添加图片输出
 
 11.设置AVCaptureMovieFileOutput  视频输出
 12.captureSession 添加视屏输出
*/

//设置会话列表
- (BOOL)setUpSession:(NSError **)error{
    //初始化session
    self.captureSession = [[AVCaptureSession alloc] init];
    
    //设置图片分辨率
    self.captureSession.sessionPreset = AVCaptureSessionPresetHigh;
    
    //视频设备
    AVCaptureDevice * videoDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    AVCaptureDeviceInput * videoInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:error];
    if (videoInput) {
        if ([self.captureSession canAddInput:videoInput]) {
            [self.captureSession addInput:videoInput];
            self.activeVideoInput = videoInput;
        }
    }else{
        return NO;
    }
    
    //音频设备
    AVCaptureDevice * audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    AVCaptureDeviceInput * audioInput = [AVCaptureDeviceInput deviceInputWithDevice:audioDevice error:error];
    if (audioInput) {
        if ([self.captureSession canAddInput:audioInput]) {
            [self.captureSession addInput:audioInput];
        }
    }else{
        return NO;
    }
    
    //图片输出
    self.imageOutput = [[AVCaptureStillImageOutput alloc] init];
    //设置捕捉到的图片格式为JPEG
    self.imageOutput.outputSettings = @{AVVideoCodecKey:AVVideoCodecJPEG};
    if ([self.captureSession canAddOutput:self.imageOutput]) {
        [self.captureSession addOutput:self.imageOutput];
    }
    
    //视频输出
    self.movieOutput = [[AVCaptureMovieFileOutput alloc] init];
    if ([self.captureSession canAddOutput:self.movieOutput]) {
        [self.captureSession addOutput:self.movieOutput];
    }
    
    self.videoQueue = dispatch_queue_create("zk.videoQueue.com", NULL);
    return YES;
}

//开始会话
- (void)startSession{
    //判断是否正在会话
    if ([self.captureSession isRunning]==NO) {
        dispatch_async(self.videoQueue, ^{
            [self.captureSession startRunning];
        });
    }
}


//停止会话
- (void)stopSession{
    //判断是否正在会话
    if ([self.captureSession isRunning]) {
        dispatch_async(self.videoQueue, ^{
            [self.captureSession stopRunning];
        });
    }
}

#pragma mark - 切换摄像头
- (BOOL)switchCameras{
    if (![self canSwitchCameras]) {
        return NO;
    }
    NSError * error;
    //获得未激活的设备,获得反面摄像头
    AVCaptureDevice * videoDevice = [self inactiveCamera];
    //封装未AVCaptureDeviceInput
    AVCaptureDeviceInput * videoDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:&error];
    
    if (videoDeviceInput) {
        //开始配置 begin
        [self.captureSession beginConfiguration];
        //移除原先的捕捉设备输入
        [self.captureSession removeInput:self.activeVideoInput];
        if ([self.captureSession canAddInput:videoDeviceInput ]) {
            [self.captureSession addInput:videoDeviceInput];
            self.activeVideoInput = videoDeviceInput;
        }else{//重新添加进去
            [self.captureSession addInput:self.activeVideoInput];
        }
        //完成配置 commit
        [self.captureSession commitConfiguration];
    }else{
        //创建AVCaptureDeviceInput出错,设置代理
        if ([self.delegate respondsToSelector:@selector(deviceInputWithDevice:error:)]) {
            [self.delegate deviceConfigurationFailedWithError:error];
        }
        return NO;
    }
    return YES;
}

- (BOOL)canSwitchCameras{
    return self.cameraCount>1;
}

//未激活的摄像头
- (AVCaptureDevice *)inactiveCamera{
    AVCaptureDevice * device = nil;
    if (self.cameraCount>1) {
        if ([self activeCamera].position == AVCaptureDevicePositionBack) {
            device = [self cameraWithPosition:AVCaptureDevicePositionFront];
        }else{
            device = [self cameraWithPosition:AVCaptureDevicePositionBack];
        }
    }
    return device;
}

//当前激活的摄像头
- (AVCaptureDevice *)activeCamera{
    return self.activeVideoInput.device;
}

//当前摄像头的个数
- (NSUInteger)cameraCount{
    return [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo].count;
}

//根据传入的位置去拿摄像头
- (AVCaptureDevice *)cameraWithPosition:(AVCaptureDevicePosition)position{
    NSArray * devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice * device in devices) {
        if (device.position == position) {
            return device;
        }
    }
    return nil;
}

#pragma mark - 聚焦 
- (BOOL)cameraSupportsTapToFocus{
    //询问激活中的摄像头是否支持兴趣点聚焦
    return [[self activeCamera] isFocusPointOfInterestSupported];
}

- (void)focusAtPoint:(CGPoint)point{
    AVCaptureDevice * ac_device = [self activeCamera];
    //是否支持兴趣点对焦 && 是否自动聚焦模式
    if (ac_device.isFocusPointOfInterestSupported&&[ac_device isFocusModeSupported:AVCaptureFocusModeAutoFocus]) {
        NSError * error;
        //锁定设备
        if ([ac_device lockForConfiguration:&error]) {
            ac_device.focusPointOfInterest = point;
            ac_device.focusMode = AVCaptureFocusModeAutoFocus;
            //释放该锁定
            [ac_device unlockForConfiguration];
        }else{
            //错误时,则返回给错误处理代理
            if ([self.delegate respondsToSelector:@selector(deviceConfigurationFailedWithError:)]) {
                [self.delegate deviceConfigurationFailedWithError:error];
            }
        }
    }
}

#pragma mark - 曝光 
- (BOOL)cameraSupportsTapToExpose{
    //询问激活的摄像头是否支持兴趣点曝光
    return [[self activeCamera] isExposurePointOfInterestSupported];
}

- (void)exposeAtPoint:(CGPoint)point{
    AVCaptureDevice * ac_device = [self activeCamera];
    if (ac_device.isExposurePointOfInterestSupported&&[ac_device isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure]) {
        NSError * error;
        //锁定设备
        if ([ac_device lockForConfiguration:&error]) {
            ac_device.exposurePointOfInterest = point;
            ac_device.exposureMode = AVCaptureExposureModeContinuousAutoExposure;
            if ([ac_device isExposureModeSupported:AVCaptureExposureModeLocked]) {
                [ac_device addObserver:self
                            forKeyPath:@"adjustingExposure"
                               options:NSKeyValueObservingOptionNew
                               context:ExposureValueChange];
            }
            [ac_device unlockForConfiguration];
        }else{
            if ([self.delegate respondsToSelector:@selector(deviceConfigurationFailedWithError:)]) {
                [self.delegate deviceConfigurationFailedWithError:error];
            }
        }
    }
}

#pragma mark - 重置聚焦 曝光的方法
- (void)resetFocusAndExposureModes{
    AVCaptureDevice * ac_device = [self activeCamera];
    
    AVCaptureFocusMode focusMode = AVCaptureFocusModeAutoFocus;
    BOOL canResetFocus = ac_device.isFocusPointOfInterestSupported&&[ac_device isFocusModeSupported:focusMode];
    
    AVCaptureExposureMode exposureMode = AVCaptureExposureModeContinuousAutoExposure;
    BOOL canResetExposure = ac_device.isExposurePointOfInterestSupported&&[ac_device isExposureModeSupported:exposureMode];
    CGPoint centerPoint = CGPointMake(0.5f, 0.5f);
    NSError * error;
    
    //锁定设备
    if ([ac_device lockForConfiguration:&error]) {
        //聚焦可以设置,设置聚焦
        if (canResetFocus) {
            ac_device.focusMode = focusMode;
            ac_device.focusPointOfInterest = centerPoint;
        }
        //曝光度可以设置,设置曝光度
        if (canResetExposure) {
            ac_device.exposureMode = exposureMode;
            ac_device.exposurePointOfInterest = centerPoint;
        }
        
        //解锁设备
        [ac_device unlockForConfiguration];
    }else{
        if ([self.delegate respondsToSelector:@selector(deviceConfigurationFailedWithError:)]) {
            [self.delegate deviceConfigurationFailedWithError:error];
        }
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context{
    if (context == ExposureValueChange) {
        AVCaptureDevice * ac_device = [self activeCamera];
        if (ac_device.isAdjustingExposure&&[ac_device isExposureModeSupported:AVCaptureExposureModeLocked]) {
            [object removeObserver:self
                        forKeyPath:@"adjustingExposure"
                           context:ExposureValueChange];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                NSError * error;
                if ([ac_device lockForConfiguration:&error]) {
                    ac_device.exposureMode = AVCaptureExposureModeLocked;
                    [ac_device unlockForConfiguration];
                }else{
                    if ([self.delegate respondsToSelector:@selector(deviceConfigurationFailedWithError:)]) {
                        [self.delegate deviceConfigurationFailedWithError:error];
                    }
                }
            });
        }
    }
}

#pragma mark - 闪光灯
- (BOOL)cameraHasFlash{
    return YES;
}

#pragma mark - 手电筒
- (BOOL)cameraHasTorch{
    return YES;
}

@end
