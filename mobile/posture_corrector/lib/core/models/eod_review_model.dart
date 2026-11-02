class EodReview {
  final String date;
  final int energyLevel;
  final int painLevel;
  final String notes;
  final int createdAt;
  final bool isSynced;

  EodReview({
    required this.date,
    required this.energyLevel,
    required this.painLevel,
    required this.notes,
    required this.createdAt,
    this.isSynced = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'date': date,
      'energyLevel': energyLevel,
      'painLevel': painLevel,
      'notes': notes.length > 255 ? notes.substring(0, 255) : notes,
      'createdAt': createdAt,
      'isSynced': isSynced ? 1 : 0,
    };
  }

  factory EodReview.fromMap(Map<String, dynamic> map) {
    return EodReview(
      date: map['date'] as String,
      energyLevel: map['energyLevel'] as int? ?? 3,
      painLevel: map['painLevel'] as int? ?? 1,
      notes: map['notes'] as String? ?? '',
      createdAt: map['createdAt'] as int? ?? 0,
      isSynced: (map['isSynced'] as int?) == 1,
    );
  }

  Map<String, dynamic> toFirestoreMap() {
    return {
      'date': date,
      'energyLevel': energyLevel,
      'painLevel': painLevel,
      'notes': notes,
      'createdAt': createdAt,
    };
  }
}
