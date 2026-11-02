import 'package:posture_corrector/core/models/posture_data.dart';
import 'package:posture_corrector/core/models/eod_review_model.dart';
import 'package:posture_corrector/core/models/daily_report_model.dart';

abstract class PostureDataRepository {
  Future<int> saveData(PostureData data);

  Future<void> saveDataList(List<PostureData> dataList);

  Future<List<PostureData>> getAllData();

  Future<List<PostureData>> getDataBetween(
    int startTimestamp,
    int endTimestamp,
  );

  Future<void> clearAllData();

  Future<Duration> calculateTodayUprightDuration(double thresholdAngle);

  Future<List<PostureData>> getUnsyncedData();

  Future<void> markAsSynced(int timestamp);

  Future<bool> isEmpty();

  Future<void> saveSummary({
    required String day,
    required int uprightMs,
    required int steps,
    required int sittingMs,
    required int standingMs,
  });

  Future<Map<int, double>> calculateWeeklyProgress(
    double thresholdAngle,
    int targetMins,
  );

  Future<Map<DateTime, int>> getDailyStatsBetween(DateTime start, DateTime end);

  Future<Map<DateTime, Map<String, dynamic>>> getDailyAllStatsBetween(
    DateTime start,
    DateTime end,
  );

  Future<Map<String, int>> getTodayActivityStats();

  Future<Map<DateTime, int>> getDailyStepsBetween(DateTime start, DateTime end);

  Future<Map<String, dynamic>> calculateWeeklyStatsJson(
    double thresholdAngle,
    int targetMins,
  );

  Future<void> generateMockData();

  Future<void> saveEodReview(EodReview review);

  Future<EodReview?> getEodReviewForDate(String date);

  Future<List<EodReview>> getLastNEodReviews(int n);

  Future<List<EodReview>> getUnsyncedEodReviews();

  Future<void> markEodReviewAsSynced(String date);

  Future<void> saveReport(DailyReport report);

  Future<List<DailyReport>> getAllReports();

  Future<DailyReport?> getReportForDate(String date);
}
