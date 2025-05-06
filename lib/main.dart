// import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(MyApp());
}

const String targetDeviceName = "Yuwell HT-YHW EMU";
Guid temperatureCharUuid = Guid("00002a1c-0000-1000-8000-00805f9b34fb");

class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String status = "กำลังสแกนอุปกรณ์...";
  double? temperature;

  BluetoothDevice? targetDevice;
  BluetoothCharacteristic? tempCharacteristic;

  @override
  void initState() {
    super.initState();
    initBluetooth();
  }

  void initBluetooth() async {
    await Permission.bluetooth.request();
    await Permission.bluetoothScan.request();
    await Permission.bluetoothConnect.request();
    await FlutterBluePlus.adapterState.firstWhere((s) => s == BluetoothAdapterState.on);

    FlutterBluePlus.startScan(timeout: Duration(seconds: 10));
    FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult r in results) {
        if(r.device.name != null && r.device.name!.isNotEmpty) {
          print("ชื่อ: ${r.device.name}, ID: ${r.device.id.id}");
          if (r.device.name == targetDeviceName) {
            // print("พบอุปกรณ์: ${r.device.name}");
            FlutterBluePlus.stopScan();
            connectToDevice(r.device);
            break;
          }
        }
      }
    });
  }

  void connectToDevice(BluetoothDevice device) async {
    setState(() => status = "กำลังเชื่อมต่อ...");
    await device.connect();
    setState(() => status = "เชื่อมต่อแล้ว");

    targetDevice = device;
    discoverServices();
  }

  void discoverServices() async {
    List<BluetoothService> services = await targetDevice!.discoverServices();
    for (BluetoothService service in services) {
      for (BluetoothCharacteristic c in service.characteristics) {
        if (c.uuid == temperatureCharUuid) {
          tempCharacteristic = c;
          await c.setNotifyValue(true);
          c.onValueReceived.listen(handleTemperatureData);
          setState(() => status = "กำลังรอข้อมูลอุณหภูมิ...");
          return;
        }
      }
    }
    setState(() => status = "ไม่พบ characteristic อุณหภูมิ");
  }

  void handleTemperatureData(List<int> data) {
    final temp = parseTemperature(data);
    if (temp != null) {
      setState(() {
        temperature = temp;
        status = "อุณหภูมิ: $temperature °C";
      });
      print("Temperature is: $temperature °C");
    }
  }

  double? parseTemperature(List<int> data) {
    if (data.length < 4) return null;

    final hexList = data.map((e) => e.toRadixString(16).padLeft(2, '0')).toList();
    final hexString = hexList[2] + hexList[1];
    final decimalValue = int.parse(hexString, radix: 16);
    return decimalValue / 100;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text("BLE Thermometer")),
        body: Center(
          child: Text(
            status,
            style: TextStyle(fontSize: 24),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
