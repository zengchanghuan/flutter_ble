//
//  BLEDriver.h
//  MixedDemo
//
//  Created by 曾长欢 on 2025/11/20.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h> // 1. 引入蓝牙框架
NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger,DeviceType) {
    DeviceTypeLight,//补光灯
    DeviceTypeGimbal,//云台
};

// 2. 定义代理协议 (让 Swift 来遵守)
@protocol BLEDriverDelegate <NSObject>

- (void)didDiscoverDeviceWithName:(NSString *)name rssi:(NSNumber *)rssi;

// 【新增 1】连接成功
- (void)didConnectToDevice:(NSString *)name;

// 【新增 2】断开连接或连接失败
- (void)didDisconnectOrFailToConnect:(NSString *)name;

// 4. 【关键】发现服务成功的回调 (新增方法)
- (void)didDiscoverServicesForDevice:(NSString *)name;

@end

@interface BLEDriver : NSObject

@property (nonatomic,copy) NSString *deviceName;

// 增加一个属性，用于保存我们正在连接的设备实例
@property (nonatomic, strong) CBPeripheral *connectingPeripheral;
// 3. 添加 delegate 属性 (必须是 weak，防止循环引用)

@property (nonatomic, weak, nullable) id<BLEDriverDelegate> delegate;

// 初始化方法
- (instancetype)initWithDeviceName:(NSString *)name;

// 发送指令的方法
- (void)sendCommand:(NSString *)hexCommand toDevice:(DeviceType)type;

// 新增开始扫描方法
- (void)startScan;

// 【新增】停止扫描
- (void)stopScan;

// 【新增】发起连接（传入设备名作为标识）
- (void)connectToDeviceWithName:(NSString *)deviceName __attribute__((swift_name("connectDevice(name:)")));

// 【新增】主动读取电量特征值
- (void)readBatteryLevel;

// 【新增】写入数据到特定的特征
// characteristicUUIDString: 目标特征的 UUID
// data: 要写入的数据 (NSData)
- (void)writeValue:(NSData *)data forCharacteristicUUID:(NSString *)characteristicUUIDString;

@end

NS_ASSUME_NONNULL_END
