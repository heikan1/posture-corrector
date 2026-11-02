import 'package:sqflite/sqflite.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:posture_corrector/core/models/posture_data.dart';
import 'package:posture_corrector/core/models/eod_review_model.dart';
import 'package:posture_corrector/core/models/daily_report_model.dart';
import 'package:posture_corrector/core/repository/database_provider.dart';
import 'package:posture_corrector/core/repository/posture_data_repository.dart';

class SqlitePostureRepository implements PostureDataRepository {
  final DatabaseProvider _dbProvider = DatabaseProvider.instance;

  String get _userId => FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';

  @override
  Future<int> saveData(PostureData data) async {
    final db = await _dbProvider.database;
    return await db.insert(DatabaseProvider.tableName, {
      ...data.toMap(),
      'userId': _userId,
    });
  }

  @override
  Future<void> saveDataList(List<PostureData> dataList) async {
    if (dataList.isEmpty) return;
    final db = await _dbProvider.database;
    final batch = db.batch();
    for (var data in dataList) {
      batch.insert(DatabaseProvider.tableName, {
        ...data.toMap(),
        'userId': _userId,
      });
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<List<PostureData>> getAllData() async {
    final db = await _dbProvider.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseProvider.tableName,
      where: 'userId = ?',
      whereArgs: [_userId],
      orderBy: 'timestamp DESC',
    );

    return List.generate(maps.length, (i) {
      return PostureData.fromMap(maps[i]);
    });
  }

  @override
  Future<List<PostureData>> getDataBetween(
    int startTimestamp,
    int endTimestamp,
  ) async {
    final db = await _dbProvider.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseProvider.tableName,
      where: 'userId = ? AND timestamp >= ? AND timestamp <= ?',
      whereArgs: [_userId, startTimestamp, endTimestamp],
      orderBy: 'timestamp ASC',
    );

    return List.generate(maps.length, (i) {
      return PostureData.fromMap(maps[i]);
    });
  }

  @override
  Future<void> clearAllData() async {
    final db = await _dbProvider.database;
    await db.delete(
      DatabaseProvider.tableName,
      where: 'userId = ?',
      whereArgs: [_userId],
    );
    await db.delete(
      DatabaseProvider.summaryTable,
      where: 'userId = ?',
      whereArgs: [_userId],
    );
  }

  @override
  Future<Duration> calculateTodayUprightDuration(double thresholdAngle) async {
    final db = await _dbProvider.database;
    final now = DateTime.now();
    final startOfDayMs = DateTime(
      now.year,
      now.month,
      now.day,
    ).millisecondsSinceEpoch;

    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseProvider.tableName,
      where: 'userId = ? AND timestamp >= ?',
      whereArgs: [_userId, startOfDayMs],
      orderBy: 'timestamp ASC',
    );

    if (maps.isEmpty) return Duration.zero;

    int totalUprightMs = 0;
    for (int i = 1; i < maps.length; i++) {
      if (maps[i - 1]['postureState'] == 0) {
        int diffMs =
            (maps[i]['timestamp'] as int) - (maps[i - 1]['timestamp'] as int);
        if (diffMs > 0 && diffMs < 5000) {
          totalUprightMs += diffMs;
        }
      }
    }
    return Duration(milliseconds: totalUprightMs);
  }

  @override
  Future<List<PostureData>> getUnsyncedData() async {
    final db = await _dbProvider.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseProvider.tableName,
      where: 'userId = ? AND isSynced = ?',
      whereArgs: [_userId, 0],
    );
    return List.generate(maps.length, (i) => PostureData.fromMap(maps[i]));
  }

  @override
  Future<void> markAsSynced(int timestamp) async {
    final db = await _dbProvider.database;
    await db.update(
      DatabaseProvider.tableName,
      {'isSynced': 1},
      where: 'userId = ? AND timestamp = ?',
      whereArgs: [_userId, timestamp],
    );
  }

  @override
  Future<bool> isEmpty() async {
    final db = await _dbProvider.database;
    final countRaw = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM ${DatabaseProvider.tableName} WHERE userId = ?',
        [_userId],
      ),
    );
    if ((countRaw ?? 0) > 0) return false;

    final countSummary = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM ${DatabaseProvider.summaryTable} WHERE userId = ?',
        [_userId],
      ),
    );
    return (countSummary ?? 0) == 0;
  }

  @override
  Future<void> saveSummary({
    required String day,
    required int uprightMs,
    required int steps,
    required int sittingMs,
    required int standingMs,
  }) async {
    final db = await _dbProvider.database;
    await db.insert(DatabaseProvider.summaryTable, {
      'day': day,
      'userId': _userId,
      'totalUprightMs': uprightMs,
      'maxSteps': steps,
      'totalSittingMs': sittingMs,
      'totalStandingMs': standingMs,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  @override
  Future<Map<int, double>> calculateWeeklyProgress(
    double thresholdAngle,
    int targetMins,
  ) async {
    final now = DateTime.now();
    final firstDayOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final startOfMonday = DateTime(
      firstDayOfWeek.year,
      firstDayOfWeek.month,
      firstDayOfWeek.day,
    );
    final targetSecs = targetMins * 60;

    final db = await _dbProvider.database;
    Map<int, double> weeklyStats = {};

    final List<Map<String, dynamic>> summaries = await db.query(
      DatabaseProvider.summaryTable,
      where: "userId = ? AND day >= ?",
      whereArgs: [
        _userId,
        "${startOfMonday.year}-${startOfMonday.month.toString().padLeft(2, '0')}-${startOfMonday.day.toString().padLeft(2, '0')}",
      ],
    );

    Map<String, int> summaryMap = {
      for (var s in summaries) s['day'] as String: s['totalUprightMs'] as int,
    };

    for (int i = 0; i < 7; i++) {
      DateTime day = startOfMonday.add(Duration(days: i));
      String dayStr =
          "${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}";
      bool isToday =
          day.year == now.year && day.month == now.month && day.day == now.day;
      bool isFuture = day.isAfter(now);

      int uprightMs = 0;
      if (isFuture) {
        uprightMs = 0;
      } else if (isToday || !summaryMap.containsKey(dayStr)) {
        await _refreshDailySummary(day);
        final updated = await db.query(
          DatabaseProvider.summaryTable,
          where: 'userId = ? AND day = ?',
          whereArgs: [_userId, dayStr],
        );
        uprightMs = updated.isNotEmpty
            ? (updated[0]['totalUprightMs'] as int)
            : 0;
      } else {
        uprightMs = summaryMap[dayStr]!;
      }

      double progress = targetSecs == 0 ? 0 : (uprightMs / 1000) / targetSecs;
      weeklyStats[i + 1] = progress > 1.0 ? 1.0 : progress;
    }

    return weeklyStats;
  }

  @override
  Future<Map<DateTime, int>> getDailyStatsBetween(
    DateTime start,
    DateTime end,
  ) async {
    final db = await _dbProvider.database;
    Map<DateTime, int> result = {};

    DateTime current = DateTime(start.year, start.month, start.day);
    DateTime last = DateTime(end.year, end.month, end.day);
    final now = DateTime.now();
    final todayKey = DateTime(now.year, now.month, now.day);

    while (current.isBefore(last) || current.isAtSameMomentAs(last)) {
      String dayStr =
          "${current.year}-${current.month.toString().padLeft(2, '0')}-${current.day.toString().padLeft(2, '0')}";

      final List<Map<String, dynamic>> summary = await db.query(
        DatabaseProvider.summaryTable,
        where: 'userId = ? AND day = ?',
        whereArgs: [_userId, dayStr],
      );

      if (summary.isEmpty || current.isAtSameMomentAs(todayKey)) {
        await _refreshDailySummary(current);
        final List<Map<String, dynamic>> updated = await db.query(
          DatabaseProvider.summaryTable,
          where: 'userId = ? AND day = ?',
          whereArgs: [_userId, dayStr],
        );
        if (updated.isNotEmpty) {
          result[current] = updated[0]['totalUprightMs'];
        }
      } else {
        result[current] = summary[0]['totalUprightMs'];
      }
      current = current.add(const Duration(days: 1));
    }
    return result;
  }

  @override
  Future<Map<DateTime, Map<String, dynamic>>> getDailyAllStatsBetween(
    DateTime start,
    DateTime end,
  ) async {
    final db = await _dbProvider.database;
    Map<DateTime, Map<String, dynamic>> result = {};

    DateTime current = DateTime(start.year, start.month, start.day);
    DateTime last = DateTime(end.year, end.month, end.day);
    final now = DateTime.now();
    final todayKey = DateTime(now.year, now.month, now.day);

    while (current.isBefore(last) || current.isAtSameMomentAs(last)) {
      String dayStr =
          "${current.year}-${current.month.toString().padLeft(2, '0')}-${current.day.toString().padLeft(2, '0')}";

      final List<Map<String, dynamic>> summary = await db.query(
        DatabaseProvider.summaryTable,
        where: 'userId = ? AND day = ?',
        whereArgs: [_userId, dayStr],
      );

      if (summary.isEmpty || current.isAtSameMomentAs(todayKey)) {
        await _refreshDailySummary(current);
        final List<Map<String, dynamic>> updated = await db.query(
          DatabaseProvider.summaryTable,
          where: 'userId = ? AND day = ?',
          whereArgs: [_userId, dayStr],
        );
        if (updated.isNotEmpty) {
          result[current] = updated[0];
        }
      } else {
        result[current] = summary[0];
      }
      current = current.add(const Duration(days: 1));
    }
    return result;
  }

  Future<Map<DateTime, Map<String, int>>> _calculateRawDailyDurations(
    DateTime start,
    DateTime end,
  ) async {
    final db = await _dbProvider.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseProvider.tableName,
      columns: ['timestamp', 'postureState', 'sitting'],
      where: 'userId = ? AND timestamp >= ? AND timestamp < ?',
      whereArgs: [
        _userId,
        start.millisecondsSinceEpoch,
        end.millisecondsSinceEpoch,
      ],
      orderBy: 'timestamp ASC',
    );

    Map<DateTime, Map<String, int>> stats = {};
    if (maps.isEmpty) return stats;

    for (int j = 1; j < maps.length; j++) {
      int diffMs =
          (maps[j]['timestamp'] as int) - (maps[j - 1]['timestamp'] as int);
      if (diffMs > 0 && diffMs < 5000) {
        DateTime date = DateTime.fromMillisecondsSinceEpoch(
          maps[j - 1]['timestamp'],
        );
        DateTime dayKey = DateTime(date.year, date.month, date.day);

        stats.putIfAbsent(
          dayKey,
          () => {'upright': 0, 'sitting': 0, 'standing': 0},
        );

        if (maps[j - 1]['postureState'] == 0) {
          stats[dayKey]!['upright'] = (stats[dayKey]!['upright'] ?? 0) + diffMs;
        }

        if (maps[j - 1]['sitting'] == 1) {
          stats[dayKey]!['sitting'] = (stats[dayKey]!['sitting'] ?? 0) + diffMs;
        } else if (maps[j - 1]['sitting'] == 0) {
          stats[dayKey]!['standing'] =
              (stats[dayKey]!['standing'] ?? 0) + diffMs;
        }
      }
    }
    return stats;
  }

  Future<void> _refreshDailySummary(DateTime day) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));

    final durations = await _calculateRawDailyDurations(start, end);
    final dayDurations =
        durations[start] ?? {'upright': 0, 'sitting': 0, 'standing': 0};

    final totalUprightMs = dayDurations['upright'] ?? 0;
    final totalSittingMs = dayDurations['sitting'] ?? 0;
    final totalStandingMs = dayDurations['standing'] ?? 0;

    final stepStats = await _calculateRawDailySteps(start, end);
    final maxSteps = stepStats[start] ?? 0;

    final db = await _dbProvider.database;
    final dayStr =
        "${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}";

    await db.insert(DatabaseProvider.summaryTable, {
      'day': dayStr,
      'userId': _userId,
      'totalUprightMs': totalUprightMs,
      'maxSteps': maxSteps,
      'totalSittingMs': totalSittingMs,
      'totalStandingMs': totalStandingMs,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<Map<String, int>> getTodayActivityStats() async {
    final now = DateTime.now();
    final dayStr =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    final startOfDay = DateTime(now.year, now.month, now.day);

    await _refreshDailySummary(startOfDay);

    final db = await _dbProvider.database;
    final List<Map<String, dynamic>> summary = await db.query(
      DatabaseProvider.summaryTable,
      where: 'day = ?',
      whereArgs: [dayStr],
    );

    if (summary.isNotEmpty) {
      return {
        'maxSteps': summary[0]['maxSteps'] as int,
        'totalSittingMs': summary[0]['totalSittingMs'] as int,
        'totalStandingMs': summary[0]['totalStandingMs'] as int,
      };
    }
    return {'maxSteps': 0, 'totalSittingMs': 0, 'totalStandingMs': 0};
  }

  @override
  Future<Map<DateTime, int>> getDailyStepsBetween(
    DateTime start,
    DateTime end,
  ) async {
    final db = await _dbProvider.database;
    Map<DateTime, int> result = {};

    DateTime current = DateTime(start.year, start.month, start.day);
    DateTime last = DateTime(end.year, end.month, end.day);
    final now = DateTime.now();
    final todayKey = DateTime(now.year, now.month, now.day);

    while (current.isBefore(last) || current.isAtSameMomentAs(last)) {
      String dayStr =
          "${current.year}-${current.month.toString().padLeft(2, '0')}-${current.day.toString().padLeft(2, '0')}";
      final List<Map<String, dynamic>> summary = await db.query(
        DatabaseProvider.summaryTable,
        where: 'userId = ? AND day = ?',
        whereArgs: [_userId, dayStr],
      );

      if (summary.isEmpty || current.isAtSameMomentAs(todayKey)) {
        await _refreshDailySummary(current);
        final List<Map<String, dynamic>> updated = await db.query(
          DatabaseProvider.summaryTable,
          where: 'userId = ? AND day = ?',
          whereArgs: [_userId, dayStr],
        );
        if (updated.isNotEmpty) {
          result[current] = updated[0]['maxSteps'];
        }
      } else {
        result[current] = summary[0]['maxSteps'];
      }
      current = current.add(const Duration(days: 1));
    }
    return result;
  }

  Future<Map<DateTime, int>> _calculateRawDailySteps(
    DateTime start,
    DateTime end,
  ) async {
    final db = await _dbProvider.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseProvider.tableName,
      columns: ['timestamp', 'stepCount'],
      where: 'userId = ? AND timestamp >= ? AND timestamp < ?',
      whereArgs: [
        _userId,
        start.millisecondsSinceEpoch,
        end.millisecondsSinceEpoch,
      ],
      orderBy: 'timestamp ASC',
    );

    Map<DateTime, int> maxSteps = {};
    if (maps.isEmpty) return maxSteps;

    for (var map in maps) {
      DateTime date = DateTime.fromMillisecondsSinceEpoch(
        map['timestamp'] as int,
      );
      DateTime dayKey = DateTime(date.year, date.month, date.day);
      int steps = map['stepCount'] as int;
      if (steps > (maxSteps[dayKey] ?? 0)) {
        maxSteps[dayKey] = steps;
      }
    }
    return maxSteps;
  }

  @override
  Future<Map<String, dynamic>> calculateWeeklyStatsJson(
    double thresholdAngle,
    int targetMins,
  ) async {
    final stats = await calculateWeeklyProgress(thresholdAngle, targetMins);
    final db = await _dbProvider.database;

    final now = DateTime.now();
    await _refreshDailySummary(DateTime(now.year, now.month, now.day));

    final List<Map<String, dynamic>> summaries = await db.query(
      DatabaseProvider.summaryTable,
      where: 'userId = ?',
      whereArgs: [_userId],
    );
    Map<String, int> stepMap = {
      for (var s in summaries) s['day'] as String: s['maxSteps'] as int,
    };
    Map<String, int> standingMap = {
      for (var s in summaries) s['day'] as String: s['totalStandingMs'] as int,
    };
    Map<String, int> sittingMap = {
      for (var s in summaries) s['day'] as String: s['totalSittingMs'] as int,
    };

    final firstDayOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final startOfMonday = DateTime(
      firstDayOfWeek.year,
      firstDayOfWeek.month,
      firstDayOfWeek.day,
    );

    Map<String, dynamic> result = {};
    for (int i = 0; i < 7; i++) {
      DateTime day = startOfMonday.add(Duration(days: i));
      String dayStr =
          "${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}";
      int steps = stepMap[dayStr] ?? 0;
      int standingMs = standingMap[dayStr] ?? 0;
      int standingMins = standingMs ~/ 60000;
      int sittingMs = sittingMap[dayStr] ?? 0;
      int sittingMins = sittingMs ~/ 60000;
      double progress = stats[i + 1] ?? 0.0;

      result["${i + 1}"] = {
        "postureProgress": double.parse(progress.toStringAsFixed(2)),
        "steps": steps,
        "standingMins": standingMins,
        "sittingMins": sittingMins,
        "uprightMins": ((progress * targetMins * 60) / 60).toInt(),
      };
    }
    return result;
  }

  @override
  Future<void> generateMockData() async {
    final db = await _dbProvider.database;
    await db.delete(
      DatabaseProvider.tableName,
      where: 'userId = ?',
      whereArgs: [_userId],
    );
    await db.delete(
      DatabaseProvider.summaryTable,
      where: 'userId = ?',
      whereArgs: [_userId],
    );

    final now = DateTime.now();
    final batch = db.batch();

    for (int i = 0; i < 30; i++) {
      final day = now.subtract(Duration(days: i));
      int targetMins = 40 + (i % 7) * 20;
      DateTime recordTime = DateTime(day.year, day.month, day.day, 10, 0);

      for (int j = 0; j < targetMins * 20; j++) {
        recordTime = recordTime.add(const Duration(seconds: 3));
        batch.insert(DatabaseProvider.tableName, {
          'userId': _userId,
          'timestamp': recordTime.millisecondsSinceEpoch,
          'pitchUpper': 10.0 + (i % 5),
          'pitchLower': 8.0,
          'deltaPitch': 2.0,
          'postureState': (j % 10 == 0) ? 1 : 0,
          'isVibrating': 0,
          'stepCount': j * 10,
          'sitting': (j % 3 == 0) ? 0 : 1,
          'isSynced': 0,
        });
      }
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<void> saveEodReview(EodReview review) async {
    final db = await _dbProvider.database;
    await db.insert(DatabaseProvider.eodReviewsTable, {
      ...review.toMap(),
      'userId': _userId,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<EodReview?> getEodReviewForDate(String date) async {
    final db = await _dbProvider.database;
    final result = await db.query(
      DatabaseProvider.eodReviewsTable,
      where: 'userId = ? AND date = ?',
      whereArgs: [_userId, date],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return EodReview.fromMap(result.first);
  }

  @override
  Future<List<EodReview>> getLastNEodReviews(int n) async {
    final db = await _dbProvider.database;
    final result = await db.query(
      DatabaseProvider.eodReviewsTable,
      where: 'userId = ?',
      whereArgs: [_userId],
      orderBy: 'date DESC',
      limit: n,
    );
    return result.map((m) => EodReview.fromMap(m)).toList();
  }

  @override
  Future<List<EodReview>> getUnsyncedEodReviews() async {
    final db = await _dbProvider.database;
    final result = await db.query(
      DatabaseProvider.eodReviewsTable,
      where: 'userId = ? AND isSynced = ?',
      whereArgs: [_userId, 0],
    );
    return result.map((m) => EodReview.fromMap(m)).toList();
  }

  @override
  Future<void> markEodReviewAsSynced(String date) async {
    final db = await _dbProvider.database;
    await db.update(
      DatabaseProvider.eodReviewsTable,
      {'isSynced': 1},
      where: 'userId = ? AND date = ?',
      whereArgs: [_userId, date],
    );
  }

  @override
  Future<void> saveReport(DailyReport report) async {
    final db = await _dbProvider.database;
    await db.insert(DatabaseProvider.reportsTable, {
      ...report.toMap(),
      'userId': _userId,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<List<DailyReport>> getAllReports() async {
    final db = await _dbProvider.database;
    final result = await db.query(
      DatabaseProvider.reportsTable,
      where: 'userId = ?',
      whereArgs: [_userId],
      orderBy: 'date DESC',
    );
    return result.map((m) => DailyReport.fromMap(m)).toList();
  }

  @override
  Future<DailyReport?> getReportForDate(String date) async {
    final db = await _dbProvider.database;
    final result = await db.query(
      DatabaseProvider.reportsTable,
      where: 'userId = ? AND date = ?',
      whereArgs: [_userId, date],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return DailyReport.fromMap(result.first);
  }
}
