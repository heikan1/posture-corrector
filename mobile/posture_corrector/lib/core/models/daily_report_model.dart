class DailyReport {
  final String id;
  final String date;
  final String content;
  final int createdAt;

  DailyReport({
    required this.id,
    required this.date,
    required this.content,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date,
      'content': content,
      'createdAt': createdAt,
    };
  }

  factory DailyReport.fromMap(Map<String, dynamic> map) {
    return DailyReport(
      id: map['id'] as String? ?? map['date'] as String? ?? '',
      date: map['date'] as String? ?? '',
      content: map['content'] as String? ?? '',
      createdAt: map['createdAt'] as int? ?? 0,
    );
  }
}
