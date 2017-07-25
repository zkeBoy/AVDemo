//
//  ZKCaptureSessionManager.m
//  AVFoundationDemo
//
//  Created by MliBo on 2017/7/19.
//  Copyright © 2017年 MliBo. All rights reserved.
//

#import "ZKCaptureSessionManager.h"
#ifdef NSFoundationVersionNumber_iOS_8_0
#import <Photos/Photos.h>
#else
#import <AssetsLibrary/AssetsLibrary.h>
#endif
#import "NSFileManager+THAdditions.h"

@interface ZKCaptureSessionManager ()<AVCaptureFileOutputRecordingDelegate>

@property (nonatomic, strong) dispatch_queue_t   videoQueue;
@property (nonatomic, strong) AVCaptureSession * captureSession;       //捕捉会话
@property (nonatomic,   weak) AVCaptureDeviceInput * activeVideoInput; //当前活跃的摄像头(默认是前置摄像头)
@property (nonatomic, strong) AVCaptureStillImageOutput * imageOutput; //图片输出
@property (nonatomic, strong) AVCaptureMovieFileOutput * movieOutput;  //视频输出
@property (nonatomic, strong) NSURL * outputURL;

@end

static const NSString * ThCameraAdjustingExposureContext;

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
        //标注原配置变化开始
        [self.captureSession beginConfiguration];
        
        //将捕捉会话中的 原捕捉设备移除
        [self.captureSession removeInput:self.activeVideoInput];
        
        //判断新的设备能不能加入
        if ([self.captureSession canAddInput:videoDeviceInput ]) {
            [self.captureSession addInput:videoDeviceInput];
            self.activeVideoInput = videoDeviceInput;
        }else{
            //重新添加进去
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
                               context:&ThCameraAdjustingExposureContext];
            }
            //解锁设备
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
    if (context == &ThCameraAdjustingExposureContext) {
        AVCaptureDevice * ac_device = [self activeCamera];
        if (!ac_device.isAdjustingExposure&&[ac_device isExposureModeSupported:AVCaptureExposureModeLocked]) {
            [object removeObserver:self
                        forKeyPath:@"adjustingExposure"
                           context:&ThCameraAdjustingExposureContext];
            
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
    return [[self activeCamera] hasFlash];
}

//get
- (AVCaptureFlashMode)flashMode{
    return [[self activeCamera] flashMode];
}

//set
- (void)setFlashMode:(AVCaptureFlashMode)flashMode{
    AVCaptureDevice * ac_device = [self activeCamera];
    if ([ac_device isFlashModeSupported:flashMode]) {
        NSError * error;
        if ([ac_device lockForConfiguration:&error]) {
            ac_device.flashMode = flashMode;
            [ac_device unlockForConfiguration];
        }else{
            if ([self.delegate respondsToSelector:@selector(deviceConfigurationFailedWithError:)]) {
                [self.delegate deviceConfigurationFailedWithError:error];
            }
        }
    }
}

#pragma mark - 手电筒
- (BOOL)cameraHasTorch{
    return [[self activeCamera] hasTorch];
}

//get
- (AVCaptureTorchMode)torchMode{
    return [[self activeCamera] torchMode];
}

//set
- (void)setTorchMode:(AVCaptureTorchMode)torchMode{
    AVCaptureDevice * ac_device = [self activeCamera];
    if ([ac_device isTorchModeSupported:torchMode]) {
        NSError * error;
        if ([ac_device lockForConfiguration:&error]) {
            ac_device.torchMode = torchMode;
            [ac_device unlockForConfiguration];
        }else{
            if ([self.delegate respondsToSelector:@selector(deviceConfigurationFailedWithError:)]) {
                [self.delegate deviceConfigurationFailedWithError:error];
            }
        }
    }
}

#pragma mark - 捕捉静态图片
- (void)captureStillImage{
    AVCaptureConnection * connection = [self.imageOutput connectionWithMediaType:AVMediaTypeVideo];
    
    //程序只支持纵向,但用户横向拍照时,需要调整结果照片的方向
    //判断是否支持设置视频方向
    if (connection.isVideoOrientationSupported) {
        connection.videoOrientation = [self currentVideoOrientation];
    }
    [self.imageOutput captureStillImageAsynchronouslyFromConnection:connection completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
        if (imageDataSampleBuffer != NULL) {
            NSData * imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
            UIImage * image = [[UIImage alloc] initWithData:imageData];
            [self writeImageToAssetsLibrary:image];
        }else{
            NSLog(@"create image Fail:%@",[error localizedDescription]);
        }
    }];
}

//获取方向
- (AVCaptureVideoOrientation)currentVideoOrientation{
    AVCaptureVideoOrientation orientation;
    switch ([UIDevice currentDevice].orientation) {
        case UIDeviceOrientationPortrait:
            orientation = AVCaptureVideoOrientationPortrait;
            break;
        case UIDeviceOrientationLandscapeLeft:
            orientation = AVCaptureVideoOrientationLandscapeLeft;
            break;
        case UIDeviceOrientationLandscapeRight:
            orientation = AVCaptureVideoOrientationLandscapeRight;
            break;
        default:
            orientation = AVCaptureVideoOrientationPortraitUpsideDown;
            break;
    }
    return orientation;
}

- (void)writeImageToAssetsLibrary:(UIImage *)image{
#ifdef NSFoundationVersionNumber_iOS_8_0
    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        [PHAssetChangeRequest creationRequestForAssetFromImage:image];
    } completionHandler:^(BOOL success, NSError * _Nullable error) {
        if(success){
            //发送通知
            [self postNotifictionWithObject:image];
        }else{
            //保存失败
            NSLog(@"save image to camera fail:%@",[error localizedDescription]);
            //代理回掉
        }
    }];
#else
    ALAssetsLibrary * library = [[ALAssetsLibrary alloc] init];
    [library writeImageToSavedPhotosAlbum:image.CGImage
                              orientation:(NSUInteger)image.imageOrientation
                          completionBlock:^(NSURL *assetURL, NSError *error) {
                              if (!error) {
                                  //success
                                  [self postNotifictionWithObject:image];
                              }else{
                                  //fail
                                  NSLog(@"save image to camera fail:%@",[error localizedDescription]);
                              }
                          }];
#endif
}

- (void)postNotifictionWithObject:(UIImage *)image{
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:THThumbnailCreatedNotification object:image];
    });
}

#pragma mark - 录制视频
//开始录制视频
- (void)startRecording{
    if ([self isRecording]==NO) {
        //获取当前视频捕捉链接信息,用于捕捉视频数据配置一些核心属性
        AVCaptureConnection * videoConnection = [self.movieOutput connectionWithMediaType:AVMediaTypeVideo];
        //判断是否支持设置videoOrientation
        if ([videoConnection isVideoOrientationSupported]) {
            videoConnection.videoOrientation = [self currentVideoOrientation];
        }
        
        //判断是否支持视频稳定,可以显著提高视屏质量
        if ([videoConnection isVideoOrientationSupported]) {
            //开启视频防抖模式
#ifdef NSFoundationVersionNumber_iOS_8_0
            videoConnection.preferredVideoStabilizationMode = AVCaptureVideoStabilizationModeCinematic;
#else
            videoConnection.enablesVideoStabilizationWhenAvailable = YES;
#endif
        }
        
        AVCaptureDevice * device = [self activeCamera];
        //摄像头可以进行平滑对焦模式操作,即减慢摄像头镜头对焦速度,当用户移动拍摄时摄像头会尝试快速自动对焦
        if (device.isSmoothAutoFocusEnabled) {
            NSError * error;
            //先锁定设备 防止其他应用来抢占设备资源
            if ([device lockForConfiguration:&error]) {
                device.smoothAutoFocusEnabled = YES;
                [device unlockForConfiguration];
            }else{
                if ([self.delegate respondsToSelector:@selector(deviceConfigurationFailedWithError:)]) {
                    [self.delegate deviceConfigurationFailedWithError:error];
                }
            }
        }
        
        self.outputURL = [self uniqueURL];
        
        //在捕捉输出上调用方法
        //参数1:录制保存路径
        //参数2:代理
        [self.movieOutput startRecordingToOutputFileURL:[NSURL fileURLWithPath:[self getVideoFilePath]] recordingDelegate:self];
    }
}

//停止录制视频
- (void)stopRecording{
    if (self.isRecording) {
        [self.movieOutput stopRecording];
    }
}

//获取录制状态
- (BOOL)isRecording{
    return self.movieOutput.isRecording;
}

//录制时间
- (CMTime)recordedDuration{
    return self.movieOutput.recordedDuration;
}

- (NSURL *)uniqueURL {
    /*
    NSFileManager * manager = [NSFileManager defaultManager];
    NSString * path = [manager temporaryDirectoryWithTemplateString:@"kamera.xxxxx"];
    if (path) {
        NSString * filePath = [path stringByAppendingPathComponent:@"kamera_movie.mov"];
        return [NSURL fileURLWithPath:filePath];
    }*/
    return [NSURL fileURLWithPath:[self getVideoFilePath]];
}

- (NSString *)getVideoFilePath{
    NSString * path = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    path = [path stringByAppendingPathComponent:@"videoFolder"];
    NSFileManager * fileManager = [NSFileManager defaultManager];
    BOOL isDir = NO;
    BOOL isExist = [fileManager fileExistsAtPath:path isDirectory:&isDir];
    if (!(isExist&&isDir)) {
        BOOL create = [fileManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
        if (create) {
            NSLog(@"create success!!!");
        }
    }
    NSDateFormatter * d = [[NSDateFormatter alloc] init];
    d.dateFormat = @"yyyyMMddHHmmss";
    NSString * time = [d stringFromDate:[NSDate dateWithTimeIntervalSinceNow:0]];
    NSString * fileName = [[path stringByAppendingPathComponent:time] stringByAppendingString:@".mov"];
    return fileName;
}

#pragma mark - AVCaptureFileOutputRecordingDelegate
//开始录制
- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didStartRecordingToOutputFileAtURL:(NSURL *)fileURL fromConnections:(NSArray *)connections {
    NSLog(@"开始录制...");
}

//录制结束
- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL fromConnections:(NSArray *)connections error:(NSError *)error {
    if (error) {
        //错误
        if ([self.delegate respondsToSelector:@selector(mediaCaptureFailedWithError:)]) {
            [self.delegate mediaCaptureFailedWithError:error];
        }
    }else{
        //写入
        [self writeVideoToAssetsLibrary:[self outputURL]];
    }
    self.outputURL = nil;
}

#pragma mark - 写入捕捉到的视频
//写入捕捉到的视频
- (void)writeVideoToAssetsLibrary:(NSURL *)videoURL{
#ifdef NSFoundationVersionNumber_iOS_8_0
    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:videoURL];
    } completionHandler:^(BOOL success, NSError * _Nullable error) {
        if (success) {
            //用于界面展示的视屏缩略图
            [self generateThumbnailForVideoAtURL:videoURL];
        }else{
            if ([self.delegate respondsToSelector:@selector(assetLibraryWriteFailedWithError:)]) {
                [self.delegate assetLibraryWriteFailedWithError:error];
            }
        }
    }];
#else
    ALAssetsLibrary * library = [[ALAssetsLibrary alloc] init];
    //写入资源库之前,检查视屏是否可以被写入
    if ([library videoAtPathIsCompatibleWithSavedPhotosAlbum:videoURL]) {
        [library writeVideoAtPathToSavedPhotosAlbum:videoURL completionBlock:^(NSURL *assetURL, NSError *error) {
            if(!error){
                [self generateThumbnailForVideoAtURL:videoURL];
            }else{
                if ([self.delegate respondsToSelector:@selector(assetLibraryWriteFailedWithError:)]) {
                    [self.delegate assetLibraryWriteFailedWithError:error];
                }
            }
        }];
    }
#endif
}

//获取视频左下脚的缩略图
- (void)generateThumbnailForVideoAtURL:(NSURL *)videoURL{
    dispatch_async(self.videoQueue, ^{
        AVAsset * asset = [AVAsset assetWithURL:videoURL];
        AVAssetImageGenerator * imageGenerator = [AVAssetImageGenerator assetImageGeneratorWithAsset:asset];
        //设置宽度为100 高度为0 根据视屏的宽高比来计算图片的高度
        imageGenerator.maximumSize = CGSizeMake(100.0f, .0f);
        //捕捉视频缩略图绘考虑视频的变化(如视频的方向变化)如果不设置 缩略图的方法有可能出错
        imageGenerator.appliesPreferredTrackTransform = YES;
        //获取CGImageRef图片 注意需要自己管理内存,获取指定时间的图片
        CGImageRef imageRef = [imageGenerator copyCGImageAtTime:kCMTimeZero actualTime:NULL error:nil];
        UIImage * image = [UIImage imageWithCGImage:imageRef];
        CGImageRelease(imageRef);
        [self postNotifictionWithObject:image];
    });
}

@end
