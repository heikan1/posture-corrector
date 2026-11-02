import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:posture_corrector/core/models/user_model.dart';

class SocialRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _currentUid {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not logged in");
    return user.uid;
  }

  Future<UserModel?> searchUserByEmail(String email) async {
    final snapshot = await _firestore
        .collection('users')
        .where('email', isEqualTo: email.trim().toLowerCase())
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      return UserModel.fromMap(snapshot.docs.first.data(), snapshot.docs.first.id);
    }
    return null;
  }

  Future<void> sendFriendRequest(String targetUid) async {
    if (targetUid == _currentUid) throw Exception("Kendinize istek gönderemezsiniz.");

    final targetDoc = _firestore.collection('users').doc(targetUid);

    await targetDoc.update({
      'friendRequests': FieldValue.arrayUnion([_currentUid])
    });
  }

  Future<void> acceptFriendRequest(String requesterUid) async {
    final batch = _firestore.batch();

    final myDoc = _firestore.collection('users').doc(_currentUid);
    final requesterDoc = _firestore.collection('users').doc(requesterUid);

    batch.update(myDoc, {
      'friendRequests': FieldValue.arrayRemove([requesterUid]),
      'friends': FieldValue.arrayUnion([requesterUid])
    });

    batch.update(requesterDoc, {
      'friends': FieldValue.arrayUnion([_currentUid])
    });

    await batch.commit();
  }

  Future<void> declineFriendRequest(String requesterUid) async {
    final myDoc = _firestore.collection('users').doc(_currentUid);
    await myDoc.update({
      'friendRequests': FieldValue.arrayRemove([requesterUid])
    });
  }

  Future<void> removeFriend(String friendUid) async {
    final batch = _firestore.batch();

    final myDoc = _firestore.collection('users').doc(_currentUid);
    final friendDoc = _firestore.collection('users').doc(friendUid);

    batch.update(myDoc, {
      'friends': FieldValue.arrayRemove([friendUid])
    });

    batch.update(friendDoc, {
      'friends': FieldValue.arrayRemove([_currentUid])
    });

    await batch.commit();
  }

  Future<List<UserModel>> getFriends() async {
    final myDoc = await _firestore.collection('users').doc(_currentUid).get();
    if (!myDoc.exists) return [];

    final data = myDoc.data()!;
    final List<dynamic> friendUids = data['friends'] ?? [];
    if (friendUids.isEmpty) return [];

    List<UserModel> friends = [];
    for (int i = 0; i < friendUids.length; i += 10) {
      final chunk = friendUids.sublist(i, i + 10 > friendUids.length ? friendUids.length : i + 10);
      final snapshot = await _firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();

      friends.addAll(snapshot.docs.map((doc) => UserModel.fromMap(doc.data(), doc.id)));
    }

    return friends;
  }

  Future<List<UserModel>> getFriendRequests() async {
    final myDoc = await _firestore.collection('users').doc(_currentUid).get();
    if (!myDoc.exists) return [];

    final data = myDoc.data()!;
    final List<dynamic> requestUids = data['friendRequests'] ?? [];
    if (requestUids.isEmpty) return [];

    List<UserModel> requesters = [];
    for (int i = 0; i < requestUids.length; i += 10) {
      final chunk = requestUids.sublist(i, i + 10 > requestUids.length ? requestUids.length : i + 10);
      final snapshot = await _firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();

      requesters.addAll(snapshot.docs.map((doc) => UserModel.fromMap(doc.data(), doc.id)));
    }

    return requesters;
  }

  Future<void> congratulateFriend(String friendUid) async {
    final myName = _auth.currentUser?.displayName ?? "Bir arkadaşın";

    await _firestore.collection('users').doc(friendUid).collection('notifications').add({
      'type': 'congratulation',
      'title': 'Tebrikler!',
      'message': '$myName hedeflerini tamamladığın için seni tebrik etti!',
      'senderUid': _currentUid,
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getNotificationsStream() {
    return _firestore
        .collection('users')
        .doc(_currentUid)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> markAllNotificationsAsRead() async {
    final snapshots = await _firestore
        .collection('users')
        .doc(_currentUid)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .get();

    if (snapshots.docs.isEmpty) return;

    final batch = _firestore.batch();
    for (var doc in snapshots.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  Future<void> markNotificationAsRead(String notificationId) async {
    await _firestore
        .collection('users')
        .doc(_currentUid)
        .collection('notifications')
        .doc(notificationId)
        .update({'isRead': true});
  }
}
