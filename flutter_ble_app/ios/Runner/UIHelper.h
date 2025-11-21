//
//  UIHelper.h
//  Runner
//
//  Created by 曾长欢 on 2025/11/20.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIHelper : NSObject
// 单例方法
+ (instancetype)shared;

// 供 OC 调用的方法
- (void)showHardwareMessage:(NSString *)message;
@end

NS_ASSUME_NONNULL_END
