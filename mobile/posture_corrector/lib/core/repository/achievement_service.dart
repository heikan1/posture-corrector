import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Achievement {
  final String id;
  final String title;
  final String description;
  final String icon;

  Achievement(this.id, this.title, this.description, this.icon);
}

class AchievementService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static final List<Achievement> allAchievements = [
    Achievement(
      'posture_5_days',
      '5 Gün Dik Duruş',
      '5 gün boyunca dik duruş hedefini %100 tamamla.',
      '🏆',
    ),
    Achievement(
      'posture_10_days',
      '10 Gün Dik Duruş',
      '10 gün boyunca dik duruş hedefini %100 tamamla.',
      '👑',
    ),
    Achievement('steps_100k', 'Adım Ustası', 'Toplamda 100.000 adım at.', '👟'),
    Achievement(
      'first_friend',
      'Sosyalleşme Vakti',
      'İlk arkadaşını ekle.',
      '🤝',
    ),
  ];

  String get _currentUid {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not logged in");
    return user.uid;
  }

  Future<void> checkAndAwardAchievements({
    required Map<String, dynamic> stats,
    required int friendCount,
  }) async {
    final userDoc = await _firestore.collection('users').doc(_currentUid).get();
    if (!userDoc.exists) return;

    final data = userDoc.data()!;
    final List<dynamic> currentAchievements = data['achievements'] ?? [];
    final List<String> friends = List<String>.from(data['friends'] ?? []);
    final String displayName = data['displayName'] ?? "Bir arkadaşın";
    List<String> newAchievements = [];

    int totalSteps = 0;
    stats.forEach((key, val) {
      if (val is Map && val['steps'] != null) {
        totalSteps += (val['steps'] as num).toInt();
      }
    });

    int completedDays = 0;
    stats.forEach((key, val) {
      if (val is Map &&
          val['postureProgress'] != null &&
          val['postureProgress'] >= 1.0) {
        completedDays++;
      }
    });

    if (completedDays >= 5 && !currentAchievements.contains('posture_5_days')) {
      newAchievements.add('posture_5_days');
    }
    if (completedDays >= 10 &&
        !currentAchievements.contains('posture_10_days')) {
      newAchievements.add('posture_10_days');
    }

    if (totalSteps >= 100000 && !currentAchievements.contains('steps_100k')) {
      newAchievements.add('steps_100k');
    }

    if (friendCount > 0 && !currentAchievements.contains('first_friend')) {
      newAchievements.add('first_friend');
    }

    if (newAchievements.isNotEmpty) {
      final batch = _firestore.batch();
      final docRef = _firestore.collection('users').doc(_currentUid);

      batch.update(docRef, {
        'achievements': FieldValue.arrayUnion(newAchievements),
      });

      for (var achId in newAchievements) {
        final ach = allAchievements.firstWhere((a) => a.id == achId);
        batch.set(
          _firestore
              .collection('users')
              .doc(_currentUid)
              .collection('notifications')
              .doc(),
          {
            'type': 'achievement',
            'title': 'Yeni Başarım Kazanıldı!',
            'message': '${ach.icon} ${ach.title}: ${ach.description}',
            'createdAt': FieldValue.serverTimestamp(),
            'isRead': false,
          },
        );

        for (var friendUid in friends) {
          batch.set(
            _firestore
                .collection('users')
                .doc(friendUid)
                .collection('notifications')
                .doc(),
            {
              'type': 'friend_achievement',
              'title': 'Arkadaşın Başarı Kazandı!',
              'message':
                  '$displayName, "${ach.title}" başarısını kazandı! ${ach.icon}',
              'createdAt': FieldValue.serverTimestamp(),
              'isRead': false,
            },
          );
        }
      }

      await batch.commit();
    }
  }

  Future<List<Achievement>> getUserAchievements() async {
    final userDoc = await _firestore.collection('users').doc(_currentUid).get();
    if (!userDoc.exists) return [];

    final data = userDoc.data()!;
    final List<dynamic> achIds = data['achievements'] ?? [];

    return allAchievements.where((a) => achIds.contains(a.id)).toList();
  }
}
