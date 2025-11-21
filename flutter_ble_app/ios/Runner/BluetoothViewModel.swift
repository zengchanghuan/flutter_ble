//
//  BluetoothViewModel.swift
//  MixedDemo
//
//  Created by 曾长欢 on 2025/11/20.
//

import Foundation
import Combine // 引入 Combine
import UIKit // 导入 UIKit 是因为 BLEDriver 是通过桥接头文件导入的


// 定义一个连接状态枚举，便于在 Swift UI 中处理不同状态
enum ConnectionState {
    case disconnected     // 初始/断开
    case scanning         // 正在扫描中
    case connecting(String) // 正在连接中 (携带设备名)
    case connected(String)  // 已连接 (携带设备名)
    case servicesReady(String) // ⚠️ 确保这一行存在！
    case failed(String)     // 连接失败 (携带设备名)
}

final class BluetoothViewModel: NSObject, ObservableObject {
    var eventSink: FlutterEventSink?
    
    // 1. @Published 核心数据：设备列表
    @Published var deviceList: [String] = []
    
    // 2. @Published 核心数据：连接状态
    @Published var connectionStatus: ConnectionState = .disconnected
    
    // ... 其他属性和 init 保持不变 ...
    private var driver: BLEDriver?
    private var cancellables = Set<AnyCancellable>()
    
    override init() {
        super.init()
        self.driver = BLEDriver(deviceName: "ViewModel_Managed")
        self.driver?.delegate = self
    }
    
    // MARK: - 供 View 调用的业务方法
    // BluetoothViewModel.swift (在 BluetoothViewModel 内部)

    func startScan() {
        print("[ViewModel] 接收到 View 指令：开始扫描")
        
        // ⚠️ 修正：使用 if let 安全解包 driver
        if let bleDriver = self.driver {
            
            // --- 之前用于测试 Event Channel 的模拟代码，可以暂时保留或删除 ---
            // DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            //     self.didDiscoverDevice(withName: "Simulated BLE Device A", rssi: NSNumber(value: -55))
            // }
            // -------------------------------------------------------------------
            
            // 只有当 driver 存在时，才调用 startScan
            bleDriver.startScan()
            
        } else {
            // 如果 driver 为 nil，打印错误信息
            print("❌ [ViewModel] 错误：BLEDriver 实例尚未初始化。")
        }
    }
    
    // 修复 connectToDevice 签名，以匹配 Method Channel 转发和你的 Dart 端调用
    func connectToDevice(name: String) {
        print("[ViewModel] 接收到 View 指令：连接设备 \(name)")
        self.connectionStatus = .connecting(name)
        // ⚠️ 使用新的方法签名
        self.driver?.connectDevice(name: name)
    }

    // 确保在 AppDelegate 中引用的方法签名是 connect(toDeviceName: name)
    // 既然 AppDelegate 使用的是 connect(toDeviceName: name)，那么我们改回 ViewModel
    func connect(toDeviceName name: String) {
        print("[ViewModel] 接收到 View 指令：连接设备 \(name)")
        self.connectionStatus = .connecting(name)
        self.driver?.connectDevice(name: name)
    }
    
    // 【新增】：添加断开连接方法 (对应 Dart 的 disconnectDevice)
    // 【新增】断开连接的方法
    func disconnectDevice(name: String) {
        print("[ViewModel] 接收到 View 指令：断开设备 \(name)")
        
        // ⚠️ 调用 BLEDriver 中新添加的方法
        self.driver?.disconnectDevice(name)
        
        // 状态更新将在 didDisconnectOrFail 回调中处理
    }
        
    // 假设 1 代表 ON (开灯), 0 代表 OFF (关灯)
    func toggleLight(isOn: Bool) {
        
        // 1. 准备要发送的数据 (单字节)
        var value: UInt8 = isOn ? 1 : 0
        let data = Data(bytes: &value, count: 1)
        
        // 2. 调用 BLEDriver 的写入方法
        // ⚠️ 注意 Swift 签名转换：writeValue:forCharacteristicUUID: 转换为 writeValue(_:forCharacteristicUUID:)
        self.driver?.writeValue(data, forCharacteristicUUID: "1001")
        
        print("[ViewModel] 💡 发起控制指令：\(isOn ? "开灯" : "关灯")")
    }
}


// MARK: - BLEDriverDelegate (ViewModel 接收 OC 的回调)

extension BluetoothViewModel: BLEDriverDelegate {
    
    // 1. 发现设备回调 (已确认的 Swift 签名)
    func didDiscoverDevice(withName name: String, rssi: NSNumber) {
            
            // 构建要发送的数据（Map 类型）
            let deviceData: [String: Any] = [
                "name": name,
                "rssi": rssi.stringValue,
                "type": "deviceDiscovered" // 用于 Flutter 区分消息类型
            ]
            
            // 【核心】如果 EventSink 存在，发送数据
            if let sink = self.eventSink { // ⚠️ 注意：这里使用 self.eventSink
                sink(deviceData)
            }
            
            print("📢 [ViewModel] 发现新设备：\(name) [信号: \(rssi)]，已发送至 Flutter。")
        }
    
    // 2. 连接成功回调 (编译器提示的 Swift 规范名)
    func didConnect(toDevice name: String) {
        print("✅ [ViewModel] 设备 \(name) 连接成功。")
        self.connectionStatus = .connected(name)
        
        self.driver?.stopScan()
        self.deviceList.removeAll()
    }
    
    // 3. 连接失败/断开回调 (编译器提示的 Swift 规范名)
    func didDisconnectOrFail(toConnect name: String) {
        print("🔴 [ViewModel] 设备 \(name) 断开或连接失败。")
        self.connectionStatus = .failed(name)
    }
    
    // 4. 发现服务回调 (新方法，使用最符合规范的 Swift 签名)
    func didDiscoverServices(forDevice name: String) {
        print("✨ [ViewModel] 设备 \(name) 服务和特征已发现，可以开始读写数据了！")
        self.connectionStatus = .servicesReady(name)
    }
}
