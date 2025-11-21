// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// 定义与 iOS Swift 端约定好的 Channel 名称
// 必须与 AppDelegate.swift 中的名称保持一致
const platform = MethodChannel('com.zch.ble/commands');
// 新增】Event Channel，名称必须与 Swift/OC 侧一致
const bleEvents = EventChannel('com.zch.ble/events');

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
      // event 是原生发送的 Map<String, Any> 数据

      // 检查数据类型并处理发现的设备
      if (event is Map && event['type'] == 'deviceDiscovered') {
        final newDevice = DiscoveredDevice(event['name'], event['rssi']);

        setState(() {
          // 使用 Set 的特性去重并更新 UI
          _devices.add(newDevice);
          _statusMessage = "发现设备: ${_devices.length} 个";
        });
      }
      // TODO: 这里可以添加处理连接状态 'connectionStatus' 的逻辑...
    }, onError: (error) {
      // 错误处理
      setState(() {
        _statusMessage = "Event 错误: ${error.message}";
      });
    });
  }

  // MARK: - Flutter -> 原生方法调用 (Method Channel)

  // 1. 调用 iOS 原生 startScan 方法
// lib/main.dart (在 _BleHomePageState 内部)

// 1. 调用 iOS 原生 startScan 方法
  // lib/main.dart (在 _BleHomePageState 内部)

  Future<void> startScan() async {
    try {
      await platform.invokeMethod('startScan');
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
      await platform.invokeMethod('startScan');
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
      await platform.invokeMethod('connectDevice', {'name': name});
    } on PlatformException catch (e) {
      setState(() {
        _statusMessage = "连接失败: ${e.message}";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Flutter BLE Control"),
        actions: [
          // 扫描按钮
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: startScan, // 绑定 startScan 方法
          ),
        ],
      ),
      body: Column(
        children: [
          // 状态显示
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blueGrey.shade100,
            width: double.infinity,
            child: Text(
              '状态: $_statusMessage',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          // 设备列表 (现在是模拟数据)
          Expanded(
            child: ListView.builder(
              // ⚠️ 从 Set 转换为 List
              itemCount: _devices.length,
              itemBuilder: (context, index) {
                final device = _devices.toList()[index];
                return ListTile(
                  title: Text(device.name),
                  subtitle: Text("RSSI: ${device.rssi}"), // 显示信号强度
                  trailing: const Icon(Icons.bluetooth),
                  // 绑定 connectDevice 方法
                  onTap: () => connectDevice(device.name), // 使用实际的设备名
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
