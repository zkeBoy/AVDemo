//
//  ZKPreviewView.h
//  AVFoundationDemo
//
//  Created by MliBo on 2017/7/19.
//  Copyright © 2017年 MliBo. All rights reserved.
//  预览视图

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@protocol ZKPreviewViewDelegate <NSObject>


@end

@interface ZKPreviewView : UIView

@property (nonatomic,   weak) id <ZKPreviewViewDelegate> delegate;
@property (nonatomic, strong) AVCaptureSession * session;

@end
