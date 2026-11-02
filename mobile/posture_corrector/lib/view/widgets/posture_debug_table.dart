import 'package:flutter/material.dart';
import 'package:posture_corrector/core/models/posture_data.dart';

class PostureDebugTable extends StatelessWidget {
  final String rawJson;
  final PostureData? data;

  const PostureDebugTable({super.key, required this.rawJson, this.data});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Debug Data (BLE Stream)",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Table(
            border: TableBorder.all(
              color: colors.outlineVariant.withAlpha(30),
              width: 1,
            ),
            children: [
              _buildRow("Key", "Value", isHeader: true),
              _buildRow("ts (Timestamp)", "${data?.timestamp}"),
              _buildRow(
                "pu (Pitch Upper)",
                "${data?.pitchUpper.toStringAsFixed(1)}°",
              ),
              _buildRow(
                "pl (Pitch Lower)",
                "${data?.pitchLower.toStringAsFixed(1)}°",
              ),
              _buildRow(
                "dp (Delta Pitch)",
                "${data?.deltaPitch.toStringAsFixed(2)}",
              ),
              _buildRow(
                "st (State)",
                data?.postureState == 0
                    ? "Good (0)"
                    : "Bad (${data?.postureState})",
              ),
              _buildRow("vib (Vibration)", " ${data?.isVibrating}"),
              _buildRow("stp (Steps)", "${data?.stepCount}"),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            "Raw JSON:",
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          Text(
            rawJson,
            style: const TextStyle(
              fontSize: 9,
              fontFamily: 'monospace',
              color: Colors.blueGrey,
            ),
          ),
        ],
      ),
    );
  }

  TableRow _buildRow(String label, String value, {bool isHeader = false}) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.all(4.0),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(4.0),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }
}
