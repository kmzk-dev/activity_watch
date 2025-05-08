import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants/color_constants.dart'; // colorLabels を使用するためにインポート

// データモデル (LogEntry)
class LogEntry {
  final DateTime actualSessionStartTime;
  final String startTime;
  final String endTime;
  String memo;
  Duration? duration;
  String colorLabelName;

  LogEntry({
    required this.actualSessionStartTime,
    required this.startTime,
    required this.endTime,
    required this.memo,
    this.duration,
    this.colorLabelName = 'デフォルト',
  });

  void calculateDuration() {
    try {
      final startTimeDateTime = DateFormat('HH:mm:ss').parse(startTime);
      final endTimeDateTime = DateFormat('HH:mm:ss').parse(endTime);
      duration = endTimeDateTime.difference(startTimeDateTime);
    } catch (e) {
      duration = null;
    }
  }

  Map<String, dynamic> toJson() => {
        'actualSessionStartTime': actualSessionStartTime.toIso8601String(),
        'startTime': startTime,
        'endTime': endTime,
        'memo': memo,
        'duration': duration?.inMilliseconds,
        'colorLabelName': colorLabelName,
      };

  factory LogEntry.fromJson(Map<String, dynamic> json) {
    final int? milliseconds = json['duration'] as int?;
    return LogEntry(
      actualSessionStartTime: DateTime.parse(json['actualSessionStartTime'] as String),
      startTime: json['startTime'] as String,
      endTime: json['endTime'] as String,
      memo: json['memo'] as String,
      duration: milliseconds != null ? Duration(milliseconds: milliseconds) : null,
      colorLabelName: json['colorLabelName'] as String? ?? 'デフォルト',
    );
  }

  String get elapsedTime {
    if (duration == null) {
      return '00:00:00';
    }
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration!.inHours;
    final minutes = duration!.inMinutes.remainder(60);
    final seconds = duration!.inSeconds.remainder(60);
    return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  Color get labelColor {
    return colorLabels[colorLabelName] ?? Colors.black;
  }
}
