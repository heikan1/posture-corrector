class PostureData {
  final int timestamp;
  final double pitchUpper;
  final double pitchLower;
  final double deltaPitch;
  final int postureState;
  final bool isVibrating;
  final int stepCount;
  final int sitting;
  final bool isSynced;
  final bool isCharging;
  final int batteryLevel;

  PostureData({
    required this.timestamp,
    required this.pitchUpper,
    required this.pitchLower,
    required this.deltaPitch,
    required this.postureState,
    required this.isVibrating,
    required this.stepCount,
    required this.isCharging,
    required this.batteryLevel,
    this.sitting = 0,
    this.isSynced = false,
  });

  factory PostureData.fromJson(Map<String, dynamic> json) {
    return PostureData(
      timestamp: json['ts'] as int? ?? 0,
      pitchUpper: (json['pu'] as num?)?.toDouble() ?? 0.0,
      pitchLower: (json['pl'] as num?)?.toDouble() ?? 0.0,
      deltaPitch: (json['dp'] as num?)?.toDouble() ?? 0.0,
      postureState: json['st'] as int? ?? 0,
      isVibrating: json['vib'] == true || json['vib'] == 1,
      stepCount: json['stp'] as int? ?? 0,
      sitting: json['sit'] as int? ?? 0,
      isCharging: json['chg'] == true || json['chrg'] == 1,
      batteryLevel: json['bv'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ts': timestamp,
      'pu': pitchUpper,
      'pl': pitchLower,
      'dp': deltaPitch,
      'st': postureState,
      'vib': isVibrating ? 1 : 0,
      'stp': stepCount,
      'sitting': sitting,
      'chg': isCharging ? 1 : 0,
      'bv': batteryLevel,

    };
  }

  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp,
      'pitchUpper': pitchUpper,
      'pitchLower': pitchLower,
      'deltaPitch': deltaPitch,
      'postureState': postureState,
      'isVibrating': isVibrating ? 1 : 0,
      'stepCount': stepCount,
      'sitting': sitting,
      'isSynced': isSynced ? 1 : 0,
    };
  }

  factory PostureData.fromMap(Map<String, dynamic> map) {
    return PostureData(
      timestamp: map['timestamp'] as int? ?? 0,
      pitchUpper: (map['pitchUpper'] as num?)?.toDouble() ?? 0.0,
      pitchLower: (map['pitchLower'] as num?)?.toDouble() ?? 0.0,
      deltaPitch: (map['deltaPitch'] as num?)?.toDouble() ?? 0.0,
      postureState: map['postureState'] as int? ?? 0,
      isVibrating: (map['isVibrating'] as int?) == 1,
      stepCount: map['stepCount'] as int? ?? 0,
      sitting: map['sitting'] as int? ?? 0,
      isSynced: (map['isSynced'] as int?) == 1,
      isCharging: (map['isCharging'] as int?) == 1,
      batteryLevel: map['batteryLevel'] as int? ?? 0,
    );
  }
}
