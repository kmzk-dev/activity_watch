import 'log_entry.dart'; // LogEntry クラスを使用するためにインポート

// データモデル (SavedLogSession)
class SavedLogSession {
  final String id;
  final String title;
  final String? sessionComment;
  final DateTime saveDate;
  final List<LogEntry> logEntries; // LogEntry を使用

  SavedLogSession({
    required this.id,
    required this.title,
    this.sessionComment,
    required this.saveDate,
    required this.logEntries,
  });

  SavedLogSession copyWith({
    String? title,
    String? sessionComment,
  }) {
    return SavedLogSession(
      id: id,
      title: title ?? this.title,
      sessionComment: sessionComment ?? this.sessionComment,
      saveDate: saveDate,
      logEntries: logEntries,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'sessionComment': sessionComment,
        'saveDate': saveDate.toIso8601String(),
        // LogEntry の toJson を使用
        'logEntries': logEntries.map((log) => log.toJson()).toList(),
      };

  factory SavedLogSession.fromJson(Map<String, dynamic> json) => SavedLogSession(
        id: json['id'] as String,
        title: json['title'] as String,
        sessionComment: json['sessionComment'] as String?,
        saveDate: DateTime.parse(json['saveDate'] as String),
        // LogEntry の fromJson を使用
        logEntries: (json['logEntries'] as List<dynamic>)
            .map((logJson) => LogEntry.fromJson(logJson as Map<String, dynamic>))
            .toList(),
      );
}
