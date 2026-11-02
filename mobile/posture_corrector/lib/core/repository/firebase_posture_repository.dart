import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:posture_corrector/core/models/posture_data.dart';
import 'package:posture_corrector/core/models/daily_report_model.dart';
import 'package:posture_corrector/core/repository/sqlite_posture_repository.dart';
import 'package:posture_corrector/core/utils/app_settings.dart';
import 'package:posture_corrector/core/utils/app_logger.dart';

class FirebasePostureRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'europe-west1',
  );
  final SqlitePostureRepository _sqLiteRepo = SqlitePostureRepository();

  String get _userId {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception("User is not logged in");
    }
    return user.uid;
  }

  CollectionReference<Map<String, dynamic>> get _posturesCollection {
    return _firestore.collection('users').doc(_userId).collection('postures');
  }

  CollectionReference<Map<String, dynamic>> get _eodCollection {
    return _firestore
        .collection('users')
        .doc(_userId)
        .collection('eod_reviews');
  }

  CollectionReference<Map<String, dynamic>> get _reportsCollection {
    return _firestore.collection('users').doc(_userId).collection('my_reports');
  }

  Future<void> syncOfflineData() async {
    try {
      if (_auth.currentUser == null) return;

      final syncEnabled = await AppSettings.getPostureSyncEnabled();
      if (!syncEnabled) return;

      final unsyncedData = await _sqLiteRepo.getUnsyncedData();
      if (unsyncedData.isEmpty) return;

      const int chunkSize = 400;
      int totalSynced = 0;

      for (var i = 0; i < unsyncedData.length; i += chunkSize) {
        int end = (i + chunkSize < unsyncedData.length)
            ? i + chunkSize
            : unsyncedData.length;
        final chunk = unsyncedData.sublist(i, end);

        final batch = _firestore.batch();
        for (final posture in chunk) {
          final docRef = _posturesCollection.doc(posture.timestamp.toString());
          batch.set(docRef, posture.toMap());
        }

        await batch.commit();

        for (final posture in chunk) {
          await _sqLiteRepo.markAsSynced(posture.timestamp);
        }

        totalSynced += chunk.length;
      }

      AppLogger.i("Successfully synced $totalSynced records to Firebase in batches.");
    } catch (e) {
      AppLogger.e("Offline Sync Failed", e);
    }
  }

  Future<List<PostureData>> getWeeklyData([String? targetUserId]) async {
    final uid = targetUserId ?? _userId;
    final oneWeekAgo =
        DateTime.now()
            .subtract(const Duration(days: 7))
            .millisecondsSinceEpoch ~/
        1000;

    final snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('postures')
        .where('timestamp', isGreaterThanOrEqualTo: oneWeekAgo)
        .orderBy('timestamp', descending: false)
        .get();

    return snapshot.docs.map((doc) => PostureData.fromMap(doc.data())).toList();
  }

  Future<void> syncEodReviews() async {
    if (_auth.currentUser == null) return;
    try {
      final unsynced = await _sqLiteRepo.getUnsyncedEodReviews();
      if (unsynced.isEmpty) return;

      final batch = _firestore.batch();
      for (final review in unsynced) {
        batch.set(_eodCollection.doc(review.date), review.toFirestoreMap());
      }
      await batch.commit();

      for (final review in unsynced) {
        await _sqLiteRepo.markEodReviewAsSynced(review.date);
      }
    } catch (e) {
      AppLogger.e("EOD Sync Failed", e);
    }
  }

  Future<String> triggerReportGeneration({
    required String date,
    required Map<String, dynamic> payload,
  }) async {
    if (_auth.currentUser == null) throw Exception("User not logged in");

    try {
      final callable = _functions.httpsCallable('generateDailyReport');
      final result = await callable.call<Map<String, dynamic>>({
        'date': date,
        'userId': _userId,
        'payload': payload,
      });

      final data = result.data;
      return data['content'] as String? ?? '';
    } on FirebaseFunctionsException catch (e) {
      throw Exception("Cloud Function hatası: ${e.message}");
    }
  }

  Future<DailyReport?> fetchReport(String date) async {
    if (_auth.currentUser == null) return null;
    try {
      final doc = await _reportsCollection.doc(date).get();
      if (!doc.exists) return null;
      final data = doc.data()!;
      return DailyReport(
        id: date,
        date: data['date'] as String? ?? date,
        content: data['content'] as String? ?? '',
        createdAt:
            (data['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ??
            DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      AppLogger.e("Rapor çekme hatası", e);
      return null;
    }
  }

  Future<void> syncReportsToLocal() async {
    if (_auth.currentUser == null) return;
    try {
      final snapshot = await _reportsCollection
          .orderBy('createdAt', descending: true)
          .get();

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final report = DailyReport(
          id: doc.id,
          date: data['date'] as String? ?? doc.id,
          content: data['content'] as String? ?? '',
          createdAt:
              (data['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ??
              DateTime.now().millisecondsSinceEpoch,
        );
        await _sqLiteRepo.saveReport(report);
      }
    } catch (e) {
      AppLogger.e("Rapor sync hatası", e);
    }
  }
}
