// dart:io と path_provider はファイル操作に不要になったためコメントアウトまたは削除
// import 'dart:io'; 
// import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart'; // BuildContext と ScaffoldMessenger のために必要
import 'package:share_plus/share_plus.dart'; // Share機能のために必要
import '../models/log_entry.dart'; // LogEntryモデルのために必要
import './time_formatters.dart'; // formatDateTime 関数のために必要

// LogEntryのリストからCSV形式の文字列を生成します。
String generateLogCsvData(List<LogEntry> logs) {
  final StringBuffer csvBuffer = StringBuffer();
  // CSVヘッダー行
  csvBuffer.writeln('SESSION,START,END,COMMENT,ELAPSED,COLOR_LABEL');

  // 各ログエントリをCSVの行として追加
  // リストの逆順で処理して、CSV上では古いログが上に来るようにする
  for (int i = logs.length - 1; i >= 0; i--) {
    final log = logs[i];
    // メモ内のダブルクォートをエスケープ処理
    final memoField = '"${log.memo.replaceAll('"', '""')}"';
    // セッション開始時刻をフォーマット
    final String formattedActualStartTime = formatDateTime(log.actualSessionStartTime);
    
    csvBuffer.writeln(
        '$formattedActualStartTime,${log.startTime},${log.endTime},$memoField,${log.elapsedTime},${log.colorLabelName}');
  }
  return csvBuffer.toString();
}

// 生成されたログのCSVデータをテキストとして共有します。
Future<void> shareLogsAsCsvText(BuildContext context, List<LogEntry> logs, {String subject = 'ActivityWatch ログデータ'}) async {
  if (logs.isEmpty) {
    // ログがない場合はSnackBarで通知
    // mounted のチェックは、非同期処理の完了前にウィジェットが破棄されるケースを考慮
    if (ScaffoldMessenger.of(context).mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('共有するログがありません。')),
      );
    }
    return;
  }

  try {
    // CSVデータを文字列として生成
    final String csvData = generateLogCsvData(logs);

    // CSVデータをテキストとして共有
    // Share.share() が Future<void> を返す場合、結果の代入は不要
    await Share.share(
      csvData,
      subject: subject, // 共有時の件名 (メールアプリなどで使用される)
    );

    // Share.share() が void を返すため、詳細な共有結果のハンドリングは不可
    // 必要であれば、共有が試みられたことを示すログなどをここに追加できます。

  } catch (e) {
    // エラーハンドリング
    if (ScaffoldMessenger.of(context).mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('データの共有中にエラーが発生しました: $e')),
      );
    }
  }
}
