//
//  UIHelper.m
//  Runner
//
//  Created by 曾长欢 on 2025/11/20.
//


#import "UIHelper.h"
#import <UIKit/UIKit.h> // 需要导入UIKit才能使用GCD（DispatchQueue.main.async）

@implementation UIHelper

// 单例模式的实现
+ (instancetype)shared {
    static UIHelper *sharedHelper = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedHelper = [[self alloc] init];
    });
    return sharedHelper;
}

- (void)showHardwareMessage:(NSString *)message {
    NSLog(@"✅ [OC UI层] 收到回调: %@", message);
    
    // 强制在主线程执行
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"    >>> 正在刷新界面弹窗...");
        // 实际应用中可以写：
        // UIAlertController *alert = [UIAlertController alertControllerWithTitle:...];
    });
}

@end
