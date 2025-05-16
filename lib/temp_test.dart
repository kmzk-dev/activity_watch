// lib/temp_test.dart
import 'package:activity_watch/models/log_entry.dart'; // あなたの LogEntry モデルへのパス
import 'package:activity_watch/theme/color_constants.dart'; // あなたの color_constants.dart へのパス
import 'package:activity_watch/utils/log_data_converter.dart'; // あなたの log_data_converter.dart へのパス

void main() {
  // colorLabels が空でないことを確認 (実際のプロジェクトでは初期化されているはず)
  if (colorLabels.isEmpty) {
    // print("警告: colorLabelsが空です。テストが正しく動作しない可能性があります。");
    // ダミーデータを設定するか、実際の初期化を待つ
    // (例) colorLabels['デフォルト'] = Colors.grey;
    // return;
  }

  // print("--- convertBackgroundTaskMapToLogEntry テスト ---");

  // 正常なMapデータ
  final sampleLapMap = {
    'actualSessionStartTimeEpoch': DateTime.now().millisecondsSinceEpoch,
    'startTimeFormatted': '00:00:00',
    'endTimeFormatted': '00:01:30',
    'memo': 'テストラップ1',
    'colorLabelName': colorLabels.keys.isNotEmpty ? colorLabels.keys.last : 'デフォルト', // colorLabelsが空の場合のフォールバック
  };
  // final entry1 = convertBackgroundTaskMapToLogEntry(sampleLapMap);
  // print('正常系テスト1: memo="${entry1.memo}", elapsedTime="${entry1.elapsedTime}", color="${entry1.colorLabelName}", actualStartTime="${entry1.actualSessionStartTime}"');
  //期待値の確認（目視）

  // memoやcolorLabelNameがnullまたは欠損
  final sampleLapMapMissing = {
    'actualSessionStartTimeEpoch': DateTime.now().subtract(const Duration(minutes: 5)).millisecondsSinceEpoch,
    'startTimeFormatted': '00:02:00',
    'endTimeFormatted': '00:03:00',
    // memo と colorLabelName が欠損
  };
  // final entryMissing = convertBackgroundTaskMapToLogEntry(sampleLapMapMissing);
  // print('欠損テスト: memo="${entryMissing.memo}", elapsedTime="${entryMissing.elapsedTime}", color="${entryMissing.colorLabelName}", actualStartTime="${entryMissing.actualSessionStartTime}"');
  //期待値の確認（目視）

  // calculateDuration()の確認 (例: 10秒のラップ)
  final epoch = DateTime.now().subtract(const Duration(minutes: 10)).millisecondsSinceEpoch;
  final durationTestMap = {
    'actualSessionStartTimeEpoch': epoch,
    'startTimeFormatted': '00:00:00', // セッション開始からの経過時間
    'endTimeFormatted': '00:00:10',   // セッション開始からの経過時間
    'memo': '10秒ラップ',
    'colorLabelName': colorLabels.keys.isNotEmpty ? colorLabels.keys.first : 'デフォルト',
  };
  // final entryDuration = convertBackgroundTaskMapToLogEntry(durationTestMap);
  // print('Durationテスト: memo="${entryDuration.memo}", duration="${entryDuration.duration}", elapsedTime="${entryDuration.elapsedTime}"');
  // 期待値の確認（目視）

  // print("\n--- convertBackgroundTaskLapListToLogEntries テスト ---");
  final List<Map<String, dynamic>> lapMapListRaw = [
    sampleLapMap,
    sampleLapMapMissing,
    durationTestMap,
    { // 別の正常ケース
      'actualSessionStartTimeEpoch': DateTime.now().millisecondsSinceEpoch,
      'startTimeFormatted': '00:05:00',
      'endTimeFormatted': '00:05:45',
      'memo': 'テストラップ2',
      'colorLabelName': colorLabels.keys.length > 1 ? colorLabels.keys.toList()[1] : 'デフォルト',
    }
  ];
  final List<LogEntry> logEntries = convertBackgroundTaskLapListToLogEntries(lapMapListRaw);
  // print('リスト変換テスト: ${logEntries.length}件のLogEntryに変換されました。');
  for (var i = 0; i < logEntries.length; i++) {
    // final log = logEntries[i];
    // print('  Entry $i: memo="${log.memo}", elapsedTime="${log.elapsedTime}", color="${log.colorLabelName}"');
  }
  // 期待値の確認（目視）

  // final List<dynamic> emptyLapMapListRaw = [];
  // final List<LogEntry> emptyLogEntries = convertBackgroundTaskLapListToLogEntries(emptyLapMapListRaw);
  // print('空リスト変換テスト: ${emptyLogEntries.length}件のLogEntryに変換されました。');
  // 期待値の確認（目視）
}