// ios/Runner/AppDelegate.swift

import UIKit
import Flutter

@UIApplicationMain
class AppDelegate: FlutterAppDelegate,FlutterStreamHandler {
    
    // 声明 ViewModel 实例，它将是 Flutter 指令的实际执行者
    // 确保 BluetoothViewModel 已经被拖入项目且桥接成功
    private lazy var viewModel = BluetoothViewModel()
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        
        // 1. 获取 FlutterViewController 和 BinaryMessenger
        let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
        
        // 设定唯一的 Channel 名称，Flutter 端必须使用相同名称
        let bleMethodChannel = FlutterMethodChannel(name: "com.zch.ble/commands",
                                                    binaryMessenger: controller.binaryMessenger)
        
        // 2. 处理 Flutter 发来的方法调用 (Method Call Handler)
        bleMethodChannel.setMethodCallHandler({
            [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
            
            // 确保 ViewModel 存在
            guard let self = self else {
                result(FlutterError(code: "UNAVAILABLE", message: "iOS module not ready", details: nil))
                return
            }

            // 根据方法名 (call.method) 执行对应的原生逻辑
            switch call.method {
            case "startScan":
                self.viewModel.startScan()
                // 成功返回 nil (空)
                result(nil)
                
            case "connectDevice":
                // 接收 Flutter 传入的参数 (Map)
                guard let args = call.arguments as? [String: Any],
                      let name = args["name"] as? String else {
                    result(FlutterError(code: "INVALID_ARG", message: "Missing device name", details: nil))
                    return
                }
                self.viewModel.connect(toDeviceName: name)
                result(nil)
                
            default:
                // 收到无法识别的方法调用
                result(FlutterMethodNotImplemented)
            }
        })
        
        // 3. 设置 Flutter Event Channel (用于原生向 Flutter 发送数据流)
        let bleEventChannel = FlutterEventChannel(name: "com.zch.ble/events",
                                                  binaryMessenger: controller.binaryMessenger)

        // ⚠️ 【新增】设置 AppDelegate 为 Event Channel 的代理
        bleEventChannel.setStreamHandler(self)

        // 注册插件（保持不变）
        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    
    // MARK: - FlutterStreamHandler (Event Channel 代理方法)
      
      // ⚠️ 【新增】协议要求方法：当 Flutter 开始监听时调用
      func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
          // 【核心】将 Event Sink 传递给 ViewModel
          self.viewModel.eventSink = events
          print("✅ [AppDelegate] Flutter Event Channel 已启动监听。")
          return nil
      }

      // ⚠️ 【新增】协议要求方法：当 Flutter 停止监听时调用
      func onCancel(withArguments arguments: Any?) -> FlutterError? {
          // 清除 Event Sink
          self.viewModel.eventSink = nil
          print("❌ [AppDelegate] Flutter Event Channel 已停止监听。")
          return nil
      }
}

