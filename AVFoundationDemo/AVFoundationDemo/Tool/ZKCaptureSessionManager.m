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
- (NSInteger)cameraCount{
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

@end
