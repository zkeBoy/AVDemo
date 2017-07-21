//
//  ZKCaptureSessionManager.h
//  AVFoundationDemo
//
//  Created by MliBo on 2017/7/19.
//  Copyright © 2017年 MliBo. All rights reserved.
//

/**
 1.捕捉会话    AVCaptureSession
 2.捕捉设备    AVCaptureDevice
 3.捕捉设备输入 AVCaptureDeviceInputs
 
 4.捕捉设备输出
 AVCaptureOut
 * AVCaptureStillImageOuput 静态照片
 * AVCaptureMovieFileOuput  视频
 
 //用来直接访问硬件捕捉到的数字样本
 * AVCaptureAudioDataOuput
 * AVCaptureVideoDataOuput
 
 5.捕捉设备的连接 AVCaptureConnection
 6.捕捉设备的预览 AVCaptureVideoPreviewLayer
 */

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
//处理一些列错误的代理
@protocol ZKCaptureSessionManagerDelegate <NSObject>
- (void)deviceConfigurationFailedWithError:(NSError *)error; //切换摄像头出错
- (void)mediaCaptureFailedWithError:(NSError *)error;
- (void)assetLibraryWriteFailedWithError:(NSError *)error;
@end

@interface ZKCaptureSessionManager : NSObject
@property (nonatomic, weak) id <ZKCaptureSessionManagerDelegate> delegate;
@property (nonatomic, strong, readonly) AVCaptureSession * captureSession;


- (BOOL)setUpSession:(NSError **)error;

- (void)startSession;

- (void)stopSession;

@property (nonatomic, readonly) NSInteger cameraCount; //摄像头个数

- (BOOL)switchCameras; //切换摄像头


@end
