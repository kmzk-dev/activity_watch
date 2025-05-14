// test/log_data_converter_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:activity_watch/models/log_entry.dart'; // あなたの LogEntry モデルへのパス
import 'package:activity_watch/theme/color_constants.dart'; // あなたの color_constants.dart へのパス
import 'package:activity_watch/utils/log_data_converter.dart'; // あなたの log_data_converter.dart へのパス
// import 'package:flutter/material.dart'; // Colors を使う場合など

void main() {
  // テスト実行前に一度だけ colorLabels にダミーデータを入れるなどの初期化が可能
  setUpAll(() {
    // 必要であれば colorLabels にテスト用の値を設定
    // (例) if (colorLabels.isEmpty) {
    //        colorLabels['デフォルトテスト'] = Colors.grey;
    //        colorLabels['赤テスト'] = Colors.red;
    //      }
    // 注意: colorLabels が const の場合、直接変更はできません。
    // この場合、テスト用に colorLabels をモックするか、
    // color_constants.dart 側でテスト環境を考慮した初期化が必要になるかもしれません。
    // もしくは、テストでは固定のキー名を使い、それが colorLabels に存在することを前提とします。
    // ここでは、colorLabels に 'dark' と 'fire' が存在すると仮定します。
    // 実際のプロジェクトの colorLabels の内容に合わせてください。
    if (!colorLabels.containsKey('dark')) {
      // 実際のテストではエラーにするか、テスト用セットアップを行う
      print("警告: テストに必要な 'dark' キーが colorLabels に存在しません。");
    }
    if (!colorLabels.containsKey('fire')) {
      print("警告: テストに必要な 'fire' キーが colorLabels に存在しません。");
    }
  });

  group('convertBackgroundTaskMapToLogEntry', () {
    test('正常なMapデータからLogEntryに正しく変換されること', () {
      final nowEpoch = DateTime.now().millisecondsSinceEpoch;
      final sampleLapMap = {
        'actualSessionStartTimeEpoch': nowEpoch,
        'startTimeFormatted': '00:00:00',
        'endTimeFormatted': '00:01:30',
        'memo': 'テストラップ',
        'colorLabelName': 'fire', // colorLabels に存在するキーを想定
      };

      final result = convertBackgroundTaskMapToLogEntry(sampleLapMap);

      expect(result.actualSessionStartTime, DateTime.fromMillisecondsSinceEpoch(nowEpoch));
      expect(result.startTime, '00:00:00');
      expect(result.endTime, '00:01:30');
      expect(result.memo, 'テストラップ');
      expect(result.colorLabelName, 'fire');
      expect(result.duration, const Duration(minutes: 1, seconds: 30));
      expect(result.elapsedTime, '00:01:30');
    });

    test('memoとcolorLabelNameがnullまたは欠損している場合にデフォルト値が設定されること', () {
      final nowEpoch = DateTime.now().millisecondsSinceEpoch;
      final sampleLapMapMissing = {
        'actualSessionStartTimeEpoch': nowEpoch,
        'startTimeFormatted': '00:02:00',
        'endTimeFormatted': '00:03:00',
      };

      final result = convertBackgroundTaskMapToLogEntry(sampleLapMapMissing);

      expect(result.actualSessionStartTime, DateTime.fromMillisecondsSinceEpoch(nowEpoch));
      expect(result.startTime, '00:02:00');
      expect(result.endTime, '00:03:00');
      expect(result.memo, '');
      expect(result.colorLabelName, colorLabels.keys.first); // colorLabels の最初のキー
      expect(result.duration, const Duration(minutes: 1));
      expect(result.elapsedTime, '00:01:00');
    });

    test('actualSessionStartTimeEpochからDateTimeが正しく生成されること', () {
      final specificTime = DateTime(2023, 10, 26, 10, 30, 0);
      final specificEpoch = specificTime.millisecondsSinceEpoch;
      final sampleLapMap = {
        'actualSessionStartTimeEpoch': specificEpoch,
        'startTimeFormatted': '00:00:00',
        'endTimeFormatted': '00:00:01',
        'memo': '時刻テスト',
        'colorLabelName': 'dark',
      };
      final result = convertBackgroundTaskMapToLogEntry(sampleLapMap);
      expect(result.actualSessionStartTime, specificTime);
    });

     test('calculateDurationによってdurationが正しく計算されること', () {
         final nowEpoch = DateTime.now().millisecondsSinceEpoch;
         final testCases = [
             {'start': '00:00:00', 'end': '00:00:00', 'expected': Duration.zero, 'expectedStr': '00:00:00'},
             {'start': '00:00:00', 'end': '00:00:59', 'expected': const Duration(seconds: 59), 'expectedStr': '00:00:59'},
             {'start': '00:01:00', 'end': '00:02:30', 'expected': const Duration(minutes: 1, seconds: 30), 'expectedStr': '00:01:30'},
             {'start': '01:00:00', 'end': '02:30:45', 'expected': const Duration(hours: 1, minutes:30, seconds: 45), 'expectedStr': '01:30:45'},
         ];

         for (var tc in testCases) {
             final sampleLapMap = {
                 'actualSessionStartTimeEpoch': nowEpoch,
                 'startTimeFormatted': tc['start'] as String,
                 'endTimeFormatted': tc['end'] as String,
                 'memo': 'Duration Test',
                 'colorLabelName': 'dark',
             };
             final result = convertBackgroundTaskMapToLogEntry(sampleLapMap);
             expect(result.duration, tc['expected'] as Duration, reason: "Start: ${tc['start']}, End: ${tc['end']}");
             expect(result.elapsedTime, tc['expectedStr'] as String, reason: "Start: ${tc['start']}, End: ${tc['end']}");
         }
     });
  });

  group('convertBackgroundTaskLapListToLogEntries', () {
    test('MapのリストがLogEntryのリストに正しく変換されること', () {
      final nowEpoch = DateTime.now().millisecondsSinceEpoch;
      final lapMapListRaw = [
        {
          'actualSessionStartTimeEpoch': nowEpoch,
          'startTimeFormatted': '00:00:00',
          'endTimeFormatted': '00:01:00',
          'memo': 'ラップ1',
          'colorLabelName': 'dark',
        },
        {
          'actualSessionStartTimeEpoch': nowEpoch,
          'startTimeFormatted': '00:01:00',
          'endTimeFormatted': '00:02:30',
          'memo': 'ラップ2',
          // colorLabelName 欠損
        },
      ];

      final results = convertBackgroundTaskLapListToLogEntries(lapMapListRaw);

      expect(results.length, 2);
      // 1つ目の要素の検証
      expect(results[0].memo, 'ラップ1');
      expect(results[0].colorLabelName, 'dark');
      expect(results[0].elapsedTime, '00:01:00');
      // 2つ目の要素の検証
      expect(results[1].memo, 'ラップ2');
      expect(results[1].colorLabelName, colorLabels.keys.first);
      expect(results[1].elapsedTime, '00:01:30');
    });

    test('空のMapリストが空のLogEntryリストに変換されること', () {
      final lapMapListRaw = <dynamic>[]; // 空のリスト
      final results = convertBackgroundTaskLapListToLogEntries(lapMapListRaw);
      expect(results.isEmpty, isTrue);
    });
  });
}