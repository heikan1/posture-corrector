import 'package:flutter/material.dart';
import 'package:posture_corrector/core/repository/ble_service.dart';

class BleDataDisplayWidget extends StatefulWidget {
  const BleDataDisplayWidget({super.key});

  @override
  State<BleDataDisplayWidget> createState() => _BleDataDisplayWidgetState();
}

class _BleDataDisplayWidgetState extends State<BleDataDisplayWidget> {
  final BleService _bleService = BleService();
  bool _isConnecting = false;

  @override
  void dispose() {
    _bleService.disconnect();
    super.dispose();
  }

  void _startConnection() async {
    setState(() => _isConnecting = true);
    await _bleService.connectAndListen();
    setState(() => _isConnecting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blueGrey[50],
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "ESP32 Canlı Veri Akışı",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          StreamBuilder<String>(
            stream: _bleService.dataStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Text(
                  "Veri bekleniyor...",
                  style: TextStyle(color: Colors.grey),
                );
              }
              if (snapshot.hasError) {
                return Text(
                  "Hata: ${snapshot.error}",
                  style: const TextStyle(color: Colors.red),
                );
              }
              if (snapshot.hasData) {
                return Text(
                  snapshot.data!,
                  style: const TextStyle(
                    fontSize: 24,
                    color: Colors.blueAccent,
                    fontWeight: FontWeight.bold,
                  ),
                );
              }
              return const Text("Veri yok.");
            },
          ),

          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: _isConnecting ? null : _startConnection,
            icon: _isConnecting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.bluetooth),
            label: Text(_isConnecting ? "Bağlanılıyor..." : "ESP32'ye Bağlan"),
          ),
        ],
      ),
    );
  }
}
