// lib/utils/time_formatters.dart

// Duration を HH:MM:SS:MS 形式の文字列にフォーマットします。
// ストップウォッチのメイン表示に使用されます。
String formatDisplayTime(Duration duration) {
  String twoDigits(int n) => n.toString().padLeft(2, '0');
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);
  final milliseconds = (duration.inMilliseconds.remainder(1000) ~/ 10);

  return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}:${twoDigits(milliseconds)}';
}

// Duration を HH:MM:SS 形式の文字列にフォーマットします。
// ログダイアログの時刻表示やログエントリの保存に使用されます。
String formatLogTime(Duration duration) {
  String twoDigits(int n) => n.toString().padLeft(2, '0');
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);
  return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
}

// DateTime オブジェクトを YYYY-MM-DD HH:MM:SS 形式の文字列にフォーマットします。
// CSV出力やその他の汎用的な日時表現に使用できます。
String formatDateTime(DateTime dt) {
  String twoDigits(int n) => n.toString().padLeft(2, '0');
  String fourDigits(int n) => n.toString().padLeft(4, '0');
  return "${fourDigits(dt.year)}-${twoDigits(dt.month)}-${twoDigits(dt.day)} ${twoDigits(dt.hour)}:${twoDigits(dt.minute)}:${twoDigits(dt.second)}";
}
