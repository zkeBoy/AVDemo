//
//  ZKPreviewView.m
//  AVFoundationDemo
//
//  Created by MliBo on 2017/7/19.
//  Copyright © 2017年 MliBo. All rights reserved.
//

#import "ZKPreviewView.h"

@interface ZKPreviewView ()

@property (nonatomic, strong) UITapGestureRecognizer * singleTapRecognizer;      //单击手势
@property (nonatomic, strong) UITapGestureRecognizer * doubleTapRecognizer;      //双击手势
@property (nonatomic, strong) UITapGestureRecognizer * doubleDoubleTapRecognizer;//

@end

@implementation ZKPreviewView

- (id)initWithFrame:(CGRect)frame{
    self = [super initWithFrame:frame];
    if (self) {
        [self setupView];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder{
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self setupView];
    }
    return self;
}

+ (Class)layerClass{
    return [AVCaptureVideoPreviewLayer class];
}

- (AVCaptureSession *)session{
    return [(AVCaptureVideoPreviewLayer*)self.layer session];
}

- (void)setSession:(AVCaptureSession *)session{
    [(AVCaptureVideoPreviewLayer *)self.layer setSession:session];
}

- (void)setupView{
    self.backgroundColor = [UIColor clearColor];
    
    //添加手势
}

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
}
*/

@end
