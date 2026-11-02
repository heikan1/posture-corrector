class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final String? photoBase64;
  final String? photoURL;
  final String? bio;
  final List<String> friends;
  final List<String> friendRequests;
  final Map<String, dynamic> weeklyStats;
  final List<String> achievements;
  final int targetDuration;
  final int targetSteps;
  final int targetStandingDuration;

  UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoBase64,
    this.photoURL,
    this.bio,
    this.friends = const [],
    this.friendRequests = const [],
    this.weeklyStats = const {},
    this.achievements = const [],
    this.targetDuration = 120,
    this.targetSteps = 5000,
    this.targetStandingDuration = 60,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String documentId) {
    return UserModel(
      uid: documentId,
      email: map['email'] ?? '',
      displayName: map['displayName'] ?? '',
      photoBase64: map['photoBase64'],
      photoURL: map['photoURL'],
      bio: map['bio'],
      friends: List<String>.from(map['friends'] ?? []),
      friendRequests: List<String>.from(map['friendRequests'] ?? []),
      weeklyStats: Map<String, dynamic>.from(map['weeklyStats'] ?? {}),
      achievements: List<String>.from(map['achievements'] ?? []),
      targetDuration: map['targetDuration'] ?? 120,
      targetSteps: map['targetSteps'] ?? 5000,
      targetStandingDuration: map['targetStandingDuration'] ?? 60,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'photoBase64': photoBase64,
      'photoURL': photoURL,
      'bio': bio,
      'friends': friends,
      'friendRequests': friendRequests,
      'weeklyStats': weeklyStats,
      'achievements': achievements,
      'targetDuration': targetDuration,
      'targetSteps': targetSteps,
      'targetStandingDuration': targetStandingDuration,
    };
  }
}
