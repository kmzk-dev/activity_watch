import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/log_entry.dart';
import './time_formatters.dart';

// LogEntryのリストからCSV形式の文字列を生成します。
String generateLogCsvData(List<LogEntry> logs) {
  final StringBuffer csvBuffer = StringBuffer();
  // CSVヘッダー行を追加
  csvBuffer.writeln('SessionStartDateTime,PreviousTime,CurrentTime,ElapsedTime,Comment,ColorLabel');
  // 各LogEntryをCSV形式で追加
  for (int i = 0; i < logs.length; i++) {
    final log = logs[i];
    final memoField = '"${log.memo.replaceAll('"', '""')}"'; //メモ内のダブルクォートをエスケープ処理
    final String formattedActualStartTime = formatDateTime(log.actualSessionStartTime); // セッション開始時刻をフォーマット
    
    csvBuffer.writeln(
        '$formattedActualStartTime,${log.startTime},${log.endTime},${log.elapsedTime},$memoField,${log.colorLabelName}');
  }

  return csvBuffer.toString();
}

// 生成されたログのCSVデータをテキストとして共有します。
Future<void> shareLogsAsCsvText(BuildContext context, List<LogEntry> logs, {String subject = 'ActivityWatch ログデータ'}) async {
  try {
    // CSVデータをテキストとして共有
    final String csvData = generateLogCsvData(logs);
    await Share.share(
      csvData,
      subject: subject,
    );
  } catch (e) {
    // Share.share() が void を返すため、詳細な共有結果のハンドリングは不可
  }
}
