import 'package:posture_corrector/core/models/daily_report_model.dart';
import 'package:posture_corrector/core/repository/firebase_posture_repository.dart';
import 'package:posture_corrector/core/repository/report_data_service.dart';
import 'package:posture_corrector/core/repository/sqlite_posture_repository.dart';
import 'package:posture_corrector/core/utils/app_logger.dart';

class ReportService {
  final SqlitePostureRepository _sqLiteRepo = SqlitePostureRepository();
  final FirebasePostureRepository _firebaseRepo = FirebasePostureRepository();
  final ReportDataService _dataService = ReportDataService();

  static String get yesterday {
    final d = DateTime.now().subtract(const Duration(days: 1));
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<bool> hasEodReview(String date) async {
    final review = await _sqLiteRepo.getEodReviewForDate(date);
    return review != null;
  }

  Future<bool> hasReport(String date) async {

    final local = await _sqLiteRepo.getReportForDate(date);
    if (local != null) return true;

    final remote = await _firebaseRepo.fetchReport(date);
    if (remote != null) {
      await _sqLiteRepo.saveReport(remote);
      return true;
    }

    return false;
  }

  Future<List<DailyReport>> getReports() async {
    await _firebaseRepo.syncReportsToLocal();
    return _sqLiteRepo.getAllReports();
  }

  Future<DailyReport> generateReport(String date) async {

    final hasEod = await hasEodReview(date);
    AppLogger.d('[ReportService] 1. hasEod=$hasEod for date=$date');
    if (!hasEod) {
      throw Exception('eod_required');
    }

    AppLogger.d('[ReportService] 2. Starting sync...');
    await _firebaseRepo.syncOfflineData();
    await _firebaseRepo.syncEodReviews();
    AppLogger.d('[ReportService] 2. Sync done.');

    AppLogger.d('[ReportService] 3. Building payload...');
    final payload = await _dataService.buildReportPayload(date);
    AppLogger.d(
      '[ReportService] 3. Payload built. eodReviews=${(payload['eodReviews'] as List).length}, blocks=${(payload['activityBlocks'] as List).length}',
    );

    AppLogger.d('[ReportService] 4. Calling Cloud Function...');
    late String content;
    try {
      content = await _firebaseRepo.triggerReportGeneration(
        date: date,
        payload: payload,
      );
    } catch (e, st) {
      AppLogger.e('[ReportService] 4. Cloud Function ERROR', e, st);
      rethrow;
    }
    AppLogger.d(
      '[ReportService] 4. Cloud Function returned ${content.length} chars.',
    );

    if (content.isEmpty) {
      throw Exception('empty_response');
    }

    final report = DailyReport(
      id: date,
      date: date,
      content: content,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _sqLiteRepo.saveReport(report);
    AppLogger.i('[ReportService] 5. Report saved to SQLite.');

    return report;
  }
}
