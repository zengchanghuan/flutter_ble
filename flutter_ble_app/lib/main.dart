// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// 定义与 iOS Swift 端约定好的 Channel 名称
// 必须与 AppDelegate.swift 中的名称保持一致
const MethodChannel bleChannel =
    MethodChannel('com.example.flutter_ble/ble_control');
const EventChannel bleEvents =
    EventChannel('com.example.flutter_ble/ble_events');

void main() {
  runApp(const BleApp());
}

class BleApp extends StatelessWidget {
  const BleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter BLE Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const BleHomePage(),
    );
  }
}

class BleHomePage extends StatefulWidget {
  const BleHomePage({super.key});

  @override
  State<BleHomePage> createState() => _BleHomePageState();
}

class DiscoveredDevice {
  final String name;
  final String rssi;

  DiscoveredDevice(this.name, this.rssi);

  @override
  bool operator ==(Object other) =>
      other is DiscoveredDevice && other.name == name;

  @override
  int get hashCode => name.hashCode;
}

class _BleHomePageState extends State<BleHomePage> {
  // UI 状态变量
  String _statusMessage = "未连接";

  // 【替换】使用 Set 来存储 DiscoveredDevice 对象，自动去重
  Set<DiscoveredDevice> _devices = {};

  //【新增】用于判断连接状态的变量
  bool _isConnected = false;
  String? _connectedDeviceName; // 保存当前连接设备的名称

  // 新增】初始化和监听方法
  @override
  void initState() {
    super.initState();
    _startListeningForDevices();
  }

  // 【新增】启动 Event Channel 监听
  void _startListeningForDevices() {
    // 监听 Event Channel 数据流
    bleEvents.receiveBroadcastStream().listen((dynamic event) {
      if (event is Map) {
        // 处理发现的设备 (保持不变)
        // 检查数据类型并处理发现的设备
        if (event is Map && event['type'] == 'deviceDiscovered') {
          final newDevice = DiscoveredDevice(event['name'], event['rssi']);

          setState(() {
            // 使用 Set 的特性去重并更新 UI
            _devices.add(newDevice);
            _statusMessage = "发现设备: ${_devices.length} 个";
          });
        }

        // ⚠️ 【核心新增】处理连接状态更新
        if (event['type'] == 'connectionStatus') {
          final status = event['status'];
          final deviceName = event['deviceName'];

          setState(() {
            if (status == 'connected_ready') {
              _statusMessage = '✅ 已连接到: $deviceName';
              _isConnected = true;
              _connectedDeviceName = deviceName;
            } else if (status == 'disconnected' || status == 'failed') {
              _statusMessage = '❌ 连接已断开或失败';
              _isConnected = false;
              _connectedDeviceName = null;
              // 重新清空设备列表，准备再次扫描
              _devices.clear();

              // 立即发起一次扫描，让用户看到设备列表恢复
              // 💡 异步调用 startScan，避免阻塞 setState 所在的同步代码块
              WidgetsBinding.instance.addPostFrameCallback((_) {
// 必须检查 mounted，避免在 widget 被销毁后调用 setState
                if (mounted) {
                  startScan();
                }
              });
            }
          });
        }
      }
    }, onError: (error) {
      /// 错误处理
      setState(() {
        _statusMessage = "Event 错误: ${error.message}";
      });
    });
  }

  // MARK: - Flutter -> 原生方法调用 (Method Channel)

// 1. 调用 iOS 原生 startScan 方法
  // lib/main.dart (在 _BleHomePageState 内部)

  Future<void> startScan() async {
    try {
      await bleChannel.invokeMethod('startScan');
      setState(() {
        _statusMessage = '正在扫描...';

        // ⚠️ 【最安全修正】使用 clear() 方法清空 Set
        _devices.clear();
        // 这比赋值 `_devices = {}` 更好，因为它不涉及类型推断，直接操作已有的 Set 对象。
      });
    } on PlatformException catch (e) {
      setState(() {
        _statusMessage = "扫描失败: ${e.message}";
      });
    }
  }

  Future<void> startScan2() async {
    try {
      // 通过 MethodChannel.invokeMethod 调用原生方法
      await bleChannel.invokeMethod('startScan');
      setState(() {
        _statusMessage = '正在扫描...';

        _devices.clear(); // 这是最安全的方式，因为不涉及赋值，只是清空 Set
      });
    } on PlatformException catch (e) {
      // ...
    }
  }

  // 2. 调用 iOS 原生 connectDevice 方法
  Future<void> connectDevice(String name) async {
    setState(() {
      _statusMessage = '连接中: $name...';
    });
    try {
      // 传递参数 Map {'name': name}
      await bleChannel.invokeMethod('connectDevice', {'name': name});
    } on PlatformException catch (e) {
      setState(() {
        _statusMessage = "连接失败: ${e.message}";
      });
    }
  }

  Future<void> disconnectDevice(String name) async {
    setState(() {
      _statusMessage = '断开连接中: $name...';
    });
    try {
      // 传递参数 Map {'name': name}
      // 这个方法名 'disconnectDevice' 必须与 AppDelegate.swift 中的 case "disconnectDevice" 匹配
      await bleChannel.invokeMethod('disconnectDevice', {'name': name});

      // 注意：原生层会在断开成功后通过 Event Channel 发送 'disconnected' 状态，
      // 我们的 _startListeningForDevices 会处理后续的 UI 更新。
    } on PlatformException catch (e) {
      setState(() {
        _statusMessage = "断开连接失败: ${e.message}";
      });
    }
  }

  // 4. 【新增】调用原生方法读取电量
  Future<void> readBatteryLevel() async {
    setState(() {
      _statusMessage = '正在读取电量...';
    });
    try {
      // ⚠️ Method Channel 方法名需要与 Native 端约定
      await bleChannel.invokeMethod('readBatteryLevel');
      // Native 会通过 Event Channel 或 UIHelper 返回结果
    } on PlatformException catch (e) {
      setState(() {
        _statusMessage = "读取电量失败: ${e.message}";
      });
    }
  }

  // 5. 【新增】调用原生方法发送控制指令
  Future<void> sendControlCommand() async {
    setState(() {
      _statusMessage = '正在发送开灯指令...';
    });
    try {
      // ⚠️ Method Channel 方法名需要与 Native 端约定
      // 假设我们发送一个简单的 Hex 命令，例如：01 (开)
      await bleChannel.invokeMethod('sendCommand', {
        'command': '01',
        'type': 1 // 假设 1 代表 Light Device Type
      });
      // Native 会通过 Event Channel 或 UIHelper 返回结果
    } on PlatformException catch (e) {
      setState(() {
        _statusMessage = "发送指令失败: ${e.message}";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Flutter BLE Control"),
        actions: [
          // 扫描按钮 (只在未连接时显示)
          if (!_isConnected)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: startScan, // 绑定 startScan 方法
            ),
        ],
      ),
      body: Column(
        children: [
          // 状态显示 (保持不变)
          Container(
            padding: const EdgeInsets.all(16),
            // ...
            child: Text(
              '状态: $_statusMessage',
              // ...
            ),
          ),

          // ⚠️ 【核心修复】根据连接状态显示不同内容
          Expanded(
            child: _isConnected
                ? _buildConnectedView() // 连接成功后显示的视图
                : _buildScanListView(), // 扫描列表视图
          ),
        ],
      ),
    );
  }

  // 扫描列表视图
  Widget _buildScanListView() {
    return ListView.builder(
      itemCount: _devices.length,
      itemBuilder: (context, index) {
        final device = _devices.toList()[index];
        return ListTile(
          title: Text(device.name),
          subtitle: Text("RSSI: ${device.rssi}"),
          trailing: const Icon(Icons.bluetooth_searching),
          onTap: () => connectDevice(device.name),
        );
      },
    );
  }

// 连接成功后的视图 (示例，你需要根据你的需求完善)
// lib/main.dart (在 _BleHomePageState 内部的 _buildConnectedView)

// lib/main.dart (在 _BleHomePageState 内部的 _buildConnectedView)

  Widget _buildConnectedView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text("已连接到: ${_connectedDeviceName ?? '未知设备'}", style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 20),

          // 1. 【新增】读取电量按钮
          ElevatedButton.icon(
            onPressed: readBatteryLevel, // 绑定新的方法
            icon: const Icon(Icons.battery_full),
            label: const Text("读取电量"),
          ),
          const SizedBox(height: 10),

          // 2. 【新增】发送指令按钮
          ElevatedButton.icon(
            onPressed: sendControlCommand, // 绑定新的方法
            icon: const Icon(Icons.lightbulb_outline),
            label: const Text("发送控制指令 (开灯)"),
          ),
          const SizedBox(height: 20),

          // 3. 断开连接按钮 (保持不变)
          ElevatedButton(
            onPressed: _statusMessage.startsWith('断开连接中:')
                ? null
                : () => disconnectDevice(_connectedDeviceName ?? ''),
            child: const Text("断开连接"),
          ),
        ],
      ),
    );
  }
}
