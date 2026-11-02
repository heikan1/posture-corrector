import 'package:posture_corrector/core/repository/database_provider.dart';
import 'package:posture_corrector/core/repository/sqlite_posture_repository.dart';
import 'package:posture_corrector/core/utils/app_settings.dart';

const int _kMaxGapMs = 10000;

class ReportDataService {
  final SqlitePostureRepository _repo = SqlitePostureRepository();
  final DatabaseProvider _dbProvider = DatabaseProvider.instance;

  Future<Map<String, dynamic>> buildReportPayload(String date) async {
    final dayStart = _parseDay(date);
    final dayEnd = dayStart.add(const Duration(days: 1));

    final records = await _repo.getDataBetween(
      dayStart.millisecondsSinceEpoch,
      dayEnd.millisecondsSinceEpoch - 1,
    );

    final targetUprightMins = await AppSettings.getTargetDurationMins();
    final targetSteps = await AppSettings.getTargetSteps();
    final targetStandingMins = await AppSettings.getTargetStandingMins();
    final vibrationDelaySecs = await AppSettings.getVibrationDelay();
    final uprightThreshold = await AppSettings.getUprightThreshold();

    final dayStr = date;
    final db = await _dbProvider.database;
    final summaryRows = await db.query(
      DatabaseProvider.summaryTable,
      where: 'day = ?',
      whereArgs: [dayStr],
    );

    int totalUprightMs = 0;
    int maxSteps = 0;
    int totalStandingMs = 0;

    if (summaryRows.isNotEmpty) {
      final s = summaryRows.first;
      totalUprightMs = s['totalUprightMs'] as int? ?? 0;
      maxSteps = s['maxSteps'] as int? ?? 0;
      totalStandingMs = s['totalStandingMs'] as int? ?? 0;
    }

    final heightCm = await AppSettings.getAiHeightCm();
    final weightKg = await AppSettings.getAiWeightKg();
    final painDescription = await AppSettings.getAiPainDescription();
    final workType = await AppSettings.getAiWorkType();
    final workDays = await AppSettings.getAiWorkDays();

    final recentEodReviews = await _repo.getLastNEodReviews(3);
    final eodList = recentEodReviews
        .map((r) => {
              'date': r.date,
              'energyLevel': r.energyLevel,
              'painLevel': r.painLevel,
              'notes': r.notes,
            })
        .toList();

    final blocks = _buildActivityBlocks(records);

    final correctionTimes = _buildCorrectionTimes(
      records,
      vibrationDelaySecs: vibrationDelaySecs,
    );

    final uprightMins = totalUprightMs / 60000;
    final standingMins = totalStandingMs / 60000;
    final uprightCompletionPct =
        targetUprightMins > 0 ? (uprightMins / targetUprightMins).clamp(0.0, 1.0) : 0.0;
    final stepsCompletionPct =
        targetSteps > 0 ? (maxSteps / targetSteps).clamp(0.0, 1.0) : 0.0;
    final standingCompletionPct =
        targetStandingMins > 0 ? (standingMins / targetStandingMins).clamp(0.0, 1.0) : 0.0;

    return {
      'reportDate': date,
      'goals': {
        'uprightTarget_mins': targetUprightMins,
        'uprightAchieved_mins': uprightMins.round(),
        'uprightCompletion_pct': (uprightCompletionPct * 100).round(),
        'stepsTarget': targetSteps,
        'stepsAchieved': maxSteps,
        'stepsCompletion_pct': (stepsCompletionPct * 100).round(),
        'standingTarget_mins': targetStandingMins,
        'standingAchieved_mins': standingMins.round(),
        'standingCompletion_pct': (standingCompletionPct * 100).round(),
      },
      'userProfile': {
        'heightCm': heightCm,
        'weightKg': weightKg,
        'painDescription': painDescription,
        'workType': workType,
        'workDays': workDays,
      },
      'eodReviews': eodList,
      'activityBlocks': blocks,
      'correctionTimes_secs': correctionTimes,
      'deviceSettings': {
        'vibrationDelaySecs': vibrationDelaySecs,
        'uprightThresholdDeg': uprightThreshold,
      },
    };
  }

  List<Map<String, dynamic>> _buildActivityBlocks(
    List<dynamic> records,
  ) {
    if (records.length < 2) return [];

    final List<Map<String, dynamic>> blocks = [];

    int blockStartIdx = 0;
    int blockSittingState = records[0].sitting as int;

    void closeBlock(int endIdx) {
      if (endIdx <= blockStartIdx) return;

      int durationMs = 0;
      double sumDeltaPitch = 0;
      int stepCount = 0;
      int validIntervals = 0;

      for (int k = blockStartIdx + 1; k <= endIdx; k++) {
        final int gap =
            (records[k].timestamp as int) - (records[k - 1].timestamp as int);
        if (gap > 0 && gap <= _kMaxGapMs) {
          durationMs += gap;
          sumDeltaPitch += (records[k - 1].deltaPitch as double).abs();
          validIntervals++;
        }
      }

      if (durationMs < 30000) return;

      if (blockSittingState == 0) {
        stepCount = (records[endIdx].stepCount as int) -
            (records[blockStartIdx].stepCount as int);
        if (stepCount < 0) stepCount = 0;
      }

      final double avgDeltaPitch =
          validIntervals > 0 ? sumDeltaPitch / validIntervals : 0.0;

      blocks.add({
        'type': blockSittingState == 1 ? 'sitting' : 'standing',
        'duration_secs': durationMs ~/ 1000,
        'avgPostureAngle_deg': double.parse(avgDeltaPitch.toStringAsFixed(2)),
        'steps': stepCount,
      });
    }

    for (int i = 1; i < records.length; i++) {
      final int gap =
          (records[i].timestamp as int) - (records[i - 1].timestamp as int);
      final int currentSitting = records[i].sitting as int;

      if (gap > _kMaxGapMs || currentSitting != blockSittingState) {
        closeBlock(i - 1);
        blockStartIdx = i;
        blockSittingState = currentSitting;
      }
    }

    closeBlock(records.length - 1);

    return blocks;
  }

  List<int> _buildCorrectionTimes(
    List<dynamic> records, {
    required int vibrationDelaySecs,
  }) {
    if (records.length < 2) return [];

    final List<int> correctionTimes = [];
    final int vibrationDelayMs = vibrationDelaySecs * 1000;

    int? badPostureStartMs;
    bool waitingForDelay = false;
    int? alertIssuedMs;

    for (int i = 1; i < records.length; i++) {
      final int prevTs = records[i - 1].timestamp as int;
      final int currTs = records[i].timestamp as int;
      final int gap = currTs - prevTs;

      if (gap > _kMaxGapMs) {
        badPostureStartMs = null;
        waitingForDelay = false;
        alertIssuedMs = null;
        continue;
      }

      final int prevState = records[i - 1].postureState as int;
      final int currState = records[i].postureState as int;

      if (prevState == 0 && currState == 1) {
        badPostureStartMs = currTs;
        waitingForDelay = true;
        alertIssuedMs = null;
      }

      if (waitingForDelay && badPostureStartMs != null && alertIssuedMs == null) {
        if (currTs - badPostureStartMs >= vibrationDelayMs) {
          alertIssuedMs = currTs;
        }
      }

      if (prevState == 1 && currState == 0 && alertIssuedMs != null) {
        final int correctionTimeMs = currTs - alertIssuedMs;
        if (correctionTimeMs > 0 && correctionTimeMs <= 300000) {

          correctionTimes.add(correctionTimeMs ~/ 1000);
        }

        badPostureStartMs = null;
        waitingForDelay = false;
        alertIssuedMs = null;
      }

      if (currState == 0 && badPostureStartMs != null && alertIssuedMs == null) {

        badPostureStartMs = null;
        waitingForDelay = false;
      }
    }

    return correctionTimes;
  }

  DateTime _parseDay(String date) {
    final parts = date.split('-');
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }
}
