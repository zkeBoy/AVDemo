//
//  ViewController.m
//  AVFoundationDemo
//
//  Created by MliBo on 2017/7/17.
//  Copyright © 2017年 MliBo. All rights reserved.
//

#import "ViewController.h"
#import <Masonry.h>
#import "ZKCaptureSessionManager.h"
#import "ZKPreviewView.h"

@interface ViewController ()
@property (weak, nonatomic)   IBOutlet ZKPreviewView *previewView;
@property (strong, nonatomic) ZKCaptureSessionManager * captureManager;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    NSError * error;
    self.captureManager = [[ZKCaptureSessionManager alloc] init]; //这是一个工具类
    if ([self.captureManager setUpSession:&error]) { //设置会话,成功则设置图层
        [self.previewView setSession:self.captureManager.captureSession]; //设置图层
        [self.captureManager startSession]; //开始会话
    }
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
