//
//  BLEDriver.m
//  MixedDemo
//
//  Created by 曾长欢 on 2025/11/20.
//

#import "BLEDriver.h"
/**
 “千万不能在 .h 头文件里 import -Swift.h！ 这会造成循环引用（Circular Dependency）。
 因为 Bridge-Header 让 Swift 引用了 OC 的 .h。

 如果 OC 的 .h 又引用了 Swift 生成的 header。

 两者就会互相死锁，导致编译失败。
 */
#import "Runner-Swift.h"
//#import "MixedDemo-Swift.h"
// 1. 遵守 CBCentralManagerDelegate 协议
@interface BLEDriver () <CBCentralManagerDelegate,CBPeripheralDelegate>

@property (nonatomic, strong) CBCentralManager *centralManager;
@property (nonatomic, strong) CBCharacteristic *batteryLevelCharacteristic; // 【新增】保存电量特征
@property (nonatomic, strong) CBCharacteristic *controlCharacteristic; // 【新增】用于控制的特征
@end

@implementation BLEDriver
- (instancetype)initWithDeviceName:(NSString *)name {
    self = [super init];
    if (self) {
        _deviceName = name;
                // 初始化蓝牙中心管理对象
                // queue: nil 代表在主线程回调，实际开发建议放后台线程
                _centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
        _discoveredPeripherals = [[NSMutableDictionary alloc] init];
    }
    return self;
}
- (void)startScan {
    // 检查蓝牙是否开启
    if (self.centralManager.state == CBManagerStatePoweredOn) {
        NSLog(@"[OC底层] 蓝牙状态正常，开始扫描...");
        // ServiceUUIDs 传 nil 代表扫描所有设备
        [self.centralManager scanForPeripheralsWithServices:nil options:nil];
    } else {
        NSLog(@"[OC底层] 蓝牙未就绪，当前状态: %ld", (long)self.centralManager.state);
    }
}

// 【新增】停止扫描实现
- (void)stopScan {
    // 实际调用 CoreBluetooth 的方法
    if (self.centralManager.isScanning) {
        [self.centralManager stopScan];
        NSLog(@"[OC底层驱动] 停止扫描...");
    }
}

// 【新增实现】主动读取电量

- (void)readBatteryLevel {
    if (!self.connectingPeripheral) {
        NSLog(@"[OC底层] ⚠️ 无法读取电量：设备未连接。");
        return;
    }
    if (!self.batteryLevelCharacteristic) {
        NSLog(@"[OC底层] ⚠️ 无法读取电量：未发现电量特征。");
        return;
    }
    
    // 核心：调用 CoreBluetooth 方法进行读取
    [self.connectingPeripheral readValueForCharacteristic:self.batteryLevelCharacteristic];
    NSLog(@"[OC底层] 🔋 再次发起读取电量指令...");
}

// 【新增】断开连接的实现
-(void)disconnectDevice:(NSString *)name {
    // 假设 self.connectedPeripheral 是当前连接的 CBPeripheral 实例
    // 并且 self.centralManager 是 CBCentralManager 实例
    if (self.connectedPeripheral) {
        NSLog(@"[BLEDriver] 正在取消连接到：%@", name);
        [self.centralManager cancelPeripheralConnection:self.connectedPeripheral];
    } else {
        NSLog(@"[BLEDriver] 错误：没有设备连接可以断开。");
        // 即使没有连接，也视为成功，最终状态由系统回调处理
        [self.delegate didDisconnectOrFailToConnect:name];
    }
}
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(nullable NSError *)error {
    if (error) {
        NSLog(@"[OC底层] 🔴 发现特征失败: %@", error.localizedDescription);
        return;
    }
    
    // 1. 遍历发现的特征
    for (CBCharacteristic *characteristic in service.characteristics) {
        
        NSLog(@"[OC底层] 特征 UUID: %@, 属性: %lu", characteristic.UUID.UUIDString, (unsigned long)characteristic.properties);
        
        // 2. 识别电量特征 UUID (2A19)
        if ([characteristic.UUID.UUIDString isEqualToString:@"2A19"]) {
            
            NSLog(@"[OC底层] ✅ 发现电量特征 (2A19)!");
            
            // 3. 保存特征实例
            self.batteryLevelCharacteristic = characteristic;
            
            // 4. 核心：发起读取操作
            // 只有当特征属性包含 CBCharacteristicPropertyRead 时才能读取
            if (characteristic.properties & CBCharacteristicPropertyRead) {
                [peripheral readValueForCharacteristic:characteristic];
                NSLog(@"[OC底层] 🔋 发起读取电量指令...");
            } else {
                 NSLog(@"[OC底层] ⚠️ 电量特征不支持 Read 操作!");
            }
        }
    }
    
    // 通知 Swift 层服务发现已完成，可以进行通信了 (保持不变)
    if (self.delegate && [self.delegate respondsToSelector:@selector(didDiscoverServicesForDevice:)]) {
        [self.delegate didDiscoverServicesForDevice:peripheral.name];
    }
    
    // 🚨 更好的做法：只在 `didDiscoverServices` 中进行特征发现，然后等待所有特征发现的回调完成。
        // 但是，由于你的 ViewModel 是在 `didDiscoverServicesForDevice` 收到通知后才认为连接完成，我们
        // 暂且保留你在 `didDiscoverCharacteristicsForService` 里面的通知代码：
        
        if ([service.UUID.UUIDString isEqualToString:@"你的主要服务UUID"]) { // 假设你主要关注某个服务
             if (self.delegate && [self.delegate respondsToSelector:@selector(didDiscoverServicesForDevice:)]) {
                 [self.delegate didDiscoverServicesForDevice:peripheral.name];
             }
        }
        
        // 如果你没有主要服务 UUID，并且想尽快完成流程，可以暂时放在这里。
}

// 【新增】读取到特征值后的回调
- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(nullable NSError *)error {
    if (error) {
        NSLog(@"[OC底层] 🔴 读取特征值失败: %@", error.localizedDescription);
        return;
    }
    
    // 1. 确认是电量特征 (2A19) 的回调
    if ([characteristic.UUID.UUIDString isEqualToString:@"2A19"]) {
        
        // 2. 解析电量数据
        // 电量值是一个单字节（UInt8）数据，0-100
        NSData *data = characteristic.value;
        uint8_t batteryLevel;
        [data getBytes:&batteryLevel length:sizeof(uint8_t)];
        
        // 3. 将结果通知 Swift 层
        // ⚠️ 为了简化，我们暂时复用 sendCommand 的代理，或者创建一个新的代理方法
        
        // 3a. 【简易处理】复用 UIHelper 通知 UI
        UIHelper *helper = [UIHelper shared];
        NSString *message = [NSString stringWithFormat:@"🔋 硬件电量: %d%%", batteryLevel];
        [helper showHardwareMessage:message];
        
        NSLog(@"[OC底层] 🔋 读取成功，电量: %d%%", batteryLevel);
    }
}

// 【新增】连接实现
// 【修复：使用真正的 CoreBluetooth 连接】
// ios/Runner/BLEDriver.m

- (void)connectToDeviceWithName:(NSString *)deviceName {
    NSLog(@"[OC底层驱动] 尝试连接设备: %@", deviceName);
    
    [self stopScan];
    
    // 【修复】从字典中查找对应的 CBPeripheral 实例
    CBPeripheral *targetPeripheral = [self.discoveredPeripherals objectForKey:deviceName];
    
    if (targetPeripheral) {
        // 3. 调用 CoreBluetooth 方法连接
        [self.centralManager connectPeripheral:targetPeripheral options:nil];
        
        // ⚠️ 可选：保存到 connectingPeripheral (如果你需要)
        self.connectingPeripheral = targetPeripheral;
        
        NSLog(@"[OC底层] ⚡️ 发起实际的 CoreBluetooth 连接请求到: %@", deviceName);
    } else {
        NSLog(@"[OC底层] ❌ 连接失败：未找到名为 %@ 的 CBPeripheral 实例 (不在字典中)。", deviceName);
        [self.delegate didDisconnectOrFailToConnect:deviceName];
    }
}

- (void)sendCommand:(NSString *)hexCommand toDevice:(DeviceType)type {
    NSString *typeString = (type == DeviceTypeLight) ? @"补光灯" : @"云台";
    NSLog(@"[OC底层] 正在向 [%@] 发送指令: %@", typeString, hexCommand);
    
    // --- 模拟硬件延时回复 ---
    // 使用 GCD 模拟 2 秒后收到硬件数据
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        NSLog(@"[OC底层] ⚡️ 收到硬件响应数据！准备通知 Swift...");
        
        // 1. 调用 Swift 单例
        // 注意：Swift 的 UIHelper.shared 在这里变成了 [UIHelper shared]
        UIHelper *helper = [UIHelper shared];
        
        // 2. 调用 Swift 方法
        // 注意：showHardwareMessage(_ message:) 变成了 showHardwareMessage:
        [helper showHardwareMessage:@"亮度调节完毕 (from OC)"];
        
    });
}

- (void)writeValue:(NSData *)data forCharacteristicUUID:(NSString *)characteristicUUIDString {
    
    if (!self.connectingPeripheral) {
        NSLog(@"[OC底层] ⚠️ 写入失败：设备未连接。");
        return;
    }
    
    CBCharacteristic *targetCharacteristic = nil;
    
    // 根据 UUID 找到对应的特征实例
    if ([characteristicUUIDString isEqualToString:@"1001"]) {
        targetCharacteristic = self.controlCharacteristic;
    }
    // 可以在这里添加其他特征的判断逻辑
    
    if (!targetCharacteristic) {
        NSLog(@"[OC底层] ⚠️ 写入失败：未找到 UUID 为 %@ 的目标特征。", characteristicUUIDString);
        return;
    }
    
    // 核心：执行写入操作
    // CBCharacteristicWriteWithResponse: 等待硬件响应，更安全
    // CBCharacteristicWriteWithoutResponse: 更快，但不保证送达
    [self.connectingPeripheral writeValue:data
                        forCharacteristic:targetCharacteristic
                                     type:CBCharacteristicWriteWithResponse];
                                     
    NSLog(@"[OC底层] 💡 已向特征 %@ 发起写入指令: %@", characteristicUUIDString, data);
}

#pragma mark - CBCentralManagerDelegate (连接状态处理)

// 【核心修复：服务发现成功或失败后的回调】
// 这个方法是 CoreBluetooth 要求必须实现的，否则 API MISUSE 警告就会出现！
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(nullable NSError *)error {
    if (error) {
        NSLog(@"[OC底层] 🔴 发现服务失败: %@", error.localizedDescription);
        // 通知 Swift 层连接失败或断开
        [self.delegate didDisconnectOrFailToConnect:peripheral.name];
        return;
    }
    
    // 成功发现服务
    NSLog(@"[OC底层] ✅ 发现 %lu 个服务。开始发现特征...", (unsigned long)peripheral.services.count);
    
    // 遍历服务，并发现特征
    for (CBService *service in peripheral.services) {
        // nil 代表发现当前服务中的所有特征
        [peripheral discoverCharacteristics:nil forService:service];
    }
}


// 【修复：连接成功的回调】
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    NSLog(@"[OC底层] 🟢 设备连接成功: %@", peripheral.name);
    
    // 1. 设置连接成功的设备属性并设置代理
    self.connectedPeripheral = peripheral;
    peripheral.delegate = self;
    
    // 2. 【核心修复】发起服务发现：nil 代表发现所有服务
    [peripheral discoverServices:nil];
    NSLog(@"[OC底层] 🔍 开始发现设备的服务...");
    
    // 3. ⚠️ 移除过早通知 Swift 层的代码！ (等待服务发现完成再通知)
    /* if (self.delegate && [self.delegate respondsToSelector:@selector(didConnectToDevice:)]) {
         [self.delegate didConnectToDevice:peripheral.name];
    }
    */
}

// 【新增】连接失败的回调
- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(nullable NSError *)error {
    NSLog(@"[OC底层] 🔴 设备连接失败: %@, 错误: %@", peripheral.name, error);
    
    // 通知 Swift 层连接失败
    if (self.delegate && [self.delegate respondsToSelector:@selector(didDisconnectOrFailToConnect:)]) {
        [self.delegate didDisconnectOrFailToConnect:peripheral.name];
    }
}

// 【新增】断开连接的回调
- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(nullable NSError *)error {
    NSLog(@"[OC底层] 🟡 设备已断开连接: %@", peripheral.name);

    // 通知 Swift 层断开连接
    if (self.delegate && [self.delegate respondsToSelector:@selector(didDisconnectOrFailToConnect:)]) {
        [self.delegate didDisconnectOrFailToConnect:peripheral.name];
    }
}

// 必须实现的协议方法：状态改变回调
- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    if (central.state == CBManagerStatePoweredOn) {
        NSLog(@"[OC底层] 蓝牙已开启");
    } else {
        NSLog(@"[OC底层] 蓝牙不可用");
    }
}

// 发现设备的回调
- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *,id> *)advertisementData RSSI:(NSNumber *)RSSI {
    
    // 过滤掉没有名字的设备 (为了演示好看点)
    NSString *foundName = peripheral.name;
    if (!foundName) {
        foundName = @"未知设备 (No Name)";
    }
    
    // 【核心新增】保存 CBPeripheral 实例
        [self.discoveredPeripherals setObject:peripheral forKey:foundName];
    
    //  通过 Delegate 通知 Swift
    if (self.delegate && [self.delegate respondsToSelector:@selector(didDiscoverDeviceWithName:rssi:)]) {
        [self.delegate didDiscoverDeviceWithName:foundName rssi:RSSI];
    }
}
@end
