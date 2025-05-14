// lib/utils/log_data_converter.dart
// import 'package:flutter/material.dart';
import '../models/log_entry.dart';
import '../theme/color_constants.dart'; // デフォルトの色ラベル名のためにインポート

LogEntry convertBackgroundTaskMapToLogEntry(Map<String, dynamic> lapMap) {
  // MyTaskHandler から渡されるキー名に合わせて調整
  final DateTime actualSessionStartTime = DateTime.fromMillisecondsSinceEpoch(
    lapMap['actualSessionStartTimeEpoch'] as int, // MyTaskHandlerがこのキーでエポック時間を送る想定
  );
  final String startTimeFormatted = lapMap['startTimeFormatted'] as String; // MyTaskHandler がこのキーで送る想定
  final String endTimeFormatted = lapMap['endTimeFormatted'] as String;     // MyTaskHandler がこのキーで送る想定
  final String memo = lapMap['memo'] as String? ?? ''; // null または欠損の場合は空文字
  final String colorLabelName = lapMap['colorLabelName'] as String? ?? colorLabels.keys.first; // null または欠損の場合は colorLabels の最初のキー

  final logEntry = LogEntry(
    actualSessionStartTime: actualSessionStartTime,
    startTime: startTimeFormatted,
    endTime: endTimeFormatted,
    memo: memo,
    colorLabelName: colorLabelName,
  );
  logEntry.calculateDuration(); // duration を計算
  return logEntry;
}

List<LogEntry> convertBackgroundTaskLapListToLogEntries(List<dynamic> lapMapListRaw) {
  if (lapMapListRaw.isEmpty) {
    return [];
  }
  return lapMapListRaw
      .map((lapMapRaw) => convertBackgroundTaskMapToLogEntry(lapMapRaw as Map<String, dynamic>))
      .toList();
}