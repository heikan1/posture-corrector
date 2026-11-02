import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:posture_corrector/core/utils/app_logger.dart';

class BleService {
  static final BleService _instance = BleService._internal();

  factory BleService() {
    return _instance;
  }

  BleService._internal();

  final String targetDeviceName = "Posture_BLE";
  final String targetCharacteristicUuid =
      "beb5483e-36e1-4688-b7f5-ea07361b26a8";

  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _targetCharacteristic;

  final StreamController<bool> _connectionStateController =
      StreamController<bool>.broadcast();
  Stream<bool> get connectionStateStream => _connectionStateController.stream;
  bool get isConnected => _connectedDevice != null;

  final StreamController<String> _dataStreamController =
      StreamController<String>.broadcast();
  Stream<String> get dataStream => _dataStreamController.stream;

  Future<bool> connectAndListen() async {
    if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
      SmartDialog.showToast(
        "Lütfen sensöre bağlanmak için Bluetooth'unuzu açın!",
      );
      return false;
    }

    bool deviceFound = false;
    Completer<bool> connectionCompleter = Completer<bool>();

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));

    FlutterBluePlus.scanResults.listen((results) async {
      for (ScanResult r in results) {
        if (r.device.platformName == targetDeviceName) {
          deviceFound = true;

          await FlutterBluePlus.stopScan();
          _connectedDevice = r.device;

          AppLogger.i("Cihaz bulundu, bağlanılıyor...");

          try {
            await _connectedDevice!.connect(
              license: License.free,
              autoConnect: false,
              timeout: const Duration(seconds: 10),
            );

            await Future.delayed(const Duration(milliseconds: 600));

            try {
              await _connectedDevice!.requestMtu(512);
            } catch (e) {
              AppLogger.w("MTU Artırma Hatası: $e");
            }

            await _discoverServices();
            _connectionStateController.add(true);
            if (!connectionCompleter.isCompleted) {
              connectionCompleter.complete(true);
            }
          } catch (e) {
            AppLogger.e("Bağlantı veya Keşif Hatası", e);
            if (!connectionCompleter.isCompleted) {
              connectionCompleter.complete(false);
            }
          }
          break;
        }
      }
    });

    FlutterBluePlus.isScanning.listen((isScanning) {
      if (!isScanning && !deviceFound && !connectionCompleter.isCompleted) {
        connectionCompleter.complete(false);
      }
    });

    return connectionCompleter.future;
  }

  Future<void> _discoverServices() async {
    if (_connectedDevice == null) return;

    List<BluetoothService> services = await _connectedDevice!
        .discoverServices();

    for (BluetoothService service in services) {
      for (BluetoothCharacteristic characteristic in service.characteristics) {
        if (characteristic.uuid.toString() == targetCharacteristicUuid) {
          _targetCharacteristic = characteristic;

          await _targetCharacteristic!.setNotifyValue(true);

          _targetCharacteristic!.onValueReceived.listen((value) {
            if (value.isNotEmpty) {
              String receivedText = utf8.decode(value);
              _dataStreamController.add(receivedText);
            }
          });
        }
      }
    }
  }

  void disconnect() {
    _connectedDevice?.disconnect();
    _connectedDevice = null;
    _connectionStateController.add(false);
  }

  Future<void> sendData(String jsonData) async {
    if (_targetCharacteristic != null) {
      try {
        await _targetCharacteristic!.write(
          utf8.encode(jsonData),
          withoutResponse: true,
        );
        AppLogger.d("Data sent to BLE: $jsonData");
      } catch (e) {
        AppLogger.e("Error sending data to BLE", e);
      }
    } else {
      AppLogger.w("Cannot send data: Target characteristic is null.");
    }
  }
}
