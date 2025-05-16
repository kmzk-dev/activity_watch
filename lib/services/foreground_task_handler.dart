// lib/services/foreground_task_handler.dart
import 'dart:async';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import '../utils/time_formatters.dart';
import '../theme/color_constants.dart';

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(MyTaskHandler());
}

class MyTaskHandler extends TaskHandler {
  DateTime? _actualSessionStartTime;
  List<Map<String, dynamic>> _lapLogs = [];
  DateTime? _lastLapEndTime;

  Timer? _timer; // onRepeatEvent の代わりに Timer を使用する例 (より正確な時間管理のため)

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _actualSessionStartTime = DateTime.now();
    _lapLogs = [];
    _lastLapEndTime = _actualSessionStartTime;

    // print('MyTaskHandler: onStart - Service started. Actual start time: $_actualSessionStartTime, Lap logs initialized.');
    _startSendingTimeUpdates(); // 時間更新を開始
  }

  void _startSendingTimeUpdates() {
    _timer?.cancel(); // 既存のタイマーがあればキャンセル
    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) { // 更新頻度を調整 (例: 100ms)
      if (_actualSessionStartTime == null) {
        timer.cancel();
        return;
      }
      final Duration elapsedTime = DateTime.now().difference(_actualSessionStartTime!);
      final String formattedTime = formatDisplayTime(elapsedTime);

      FlutterForegroundTask.sendDataToMain({
        'formattedTime': formattedTime,
        'isServiceCurrentlyRunning': true,
      });
      FlutterForegroundTask.updateService(
        notificationTitle: 'ストップウォッチ実行中 (Clone)',
        notificationText: formattedTime,
      );
    });
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Timerベースの更新に移行したため、このメソッドは実質不要になるが、
    // ForegroundTaskOptions.eventAction を設定している場合は呼び出される。
    // print('MyTaskHandler: onRepeatEvent at $timestamp (This might be redundant if using manual Timer)');
  }


  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    _timer?.cancel(); // タイマーを停止
    // print('MyTaskHandler: onDestroy at $timestamp (isTimeout: $isTimeout)');
    // _actualSessionStartTime = null; // 状態は維持する可能性も（アプリ再開時のため）
    // _lapLogs はクリアしない（UIが最後に取得できるように）
    // _lastLapEndTime = null;

    // UIにサービスが完全に停止したことを通知（オプション）
    // FlutterForegroundTask.sendDataToMain({'serviceDefinitelyStopped': true});
  }

  void _recordLapInternal(bool isFinalLap) {
    if (_actualSessionStartTime == null || _lastLapEndTime == null) {
      // print('MyTaskHandler: Cannot record lap, service not properly started.');
      return;
    }

    final DateTime currentLapTime = DateTime.now();
    final Duration overallElapsedTime = currentLapTime.difference(_actualSessionStartTime!);

    final String lapStartTimeFormatted = formatLogTime(_lastLapEndTime!.difference(_actualSessionStartTime!));
    final String lapEndTimeFormatted = formatLogTime(overallElapsedTime);

    final newLapLog = {
      'actualSessionStartTimeEpoch': _actualSessionStartTime!.millisecondsSinceEpoch,
      'startTimeFormatted': lapStartTimeFormatted,
      'endTimeFormatted': lapEndTimeFormatted,
      'memo': isFinalLap ? '最終ラップ' : '', // 最終ラップの場合、メモを区別（任意）
      'colorLabelName': colorLabels.keys.first,
    };
    _lapLogs.add(newLapLog);
    _lastLapEndTime = currentLapTime; // 次のラップのために終了時刻を更新 (最終ラップでない場合)

    // print('MyTaskHandler: Lap recorded (isFinal: $isFinalLap). New lap: $newLapLog');
    // print('MyTaskHandler: All lap logs count: ${_lapLogs.length}');

    FlutterForegroundTask.sendDataToMain({'lapLogsUpdate': List<Map<String, dynamic>>.from(_lapLogs)});
    // print('MyTaskHandler: Sent lapLogsUpdate to UI.');
  }


  @override
  void onReceiveData(Object data) {
    // print('MyTaskHandler: Received data from UI: $data');
    if (data is! Map<String, dynamic>) {
      // print('MyTaskHandler: Received data is not a Map. Ignoring.');
      return;
    }

    final Map<String, dynamic> actionData = data;
    final String? action = actionData['action'] as String?;

    if (action == 'recordLap') {
      _recordLapInternal(false); // 通常のラップ記録
    } else if (action == 'stopAndRecordFinalLap') {
      // ===>>> 修正: 停止時に最終ラップを記録 <<<===
      if (_actualSessionStartTime != null && _lastLapEndTime != null) {
        // 最後の区間をラップとして記録
        // 既に _lastLapEndTime が現在の時刻に近い場合（ほぼ同時に停止とラップ指示が来たなど）は、
        // 非常に短いラップが記録される可能性がある。必要であれば最小時間を設けるなどの調整を検討。
        _recordLapInternal(true); // 最終ラップとして記録
      }
      // 最終的な状態をUIに送る
      final String finalFormattedTime = _actualSessionStartTime != null
          ? formatDisplayTime(DateTime.now().difference(_actualSessionStartTime!))
          : '00:00:00:00';

      FlutterForegroundTask.sendDataToMain({
        'lapLogsUpdate': List<Map<String, dynamic>>.from(_lapLogs), // 最終ラップを含むログ
        'formattedTime': finalFormattedTime, // 最終的な経過時間
        'serviceStopped': true, // UIにサービス停止を明確に伝える
        'isServiceCurrentlyRunning': false,
      });
      // print('MyTaskHandler: Recorded final lap, sent final state, and stopping service.');
      FlutterForegroundTask.stopService(); // サービスを停止
    }
    else if (action == 'editLap') {
      final String? originalStartTime = actionData['originalStartTimeFormatted'] as String?;
      final String? originalEndTime = actionData['originalEndTimeFormatted'] as String?;
      final String? updatedMemo = actionData['updatedMemo'] as String?;
      final String? updatedColorLabelName = actionData['updatedColorLabelName'] as String?;

      if (originalStartTime == null || originalEndTime == null || updatedMemo == null || updatedColorLabelName == null) {
        // print('MyTaskHandler: editLap - Missing required data for editing. Ignoring.');
        return;
      }

      int lapIndex = -1;
      for (int i = 0; i < _lapLogs.length; i++) {
        if (_lapLogs[i]['startTimeFormatted'] == originalStartTime &&
            _lapLogs[i]['endTimeFormatted'] == originalEndTime) {
          lapIndex = i;
          break;
        }
      }

      if (lapIndex != -1) {
        _lapLogs[lapIndex]['memo'] = updatedMemo;
        _lapLogs[lapIndex]['colorLabelName'] = updatedColorLabelName;
        // print('MyTaskHandler: Lap edited. Index: $lapIndex, Updated data: ${_lapLogs[lapIndex]}');
        FlutterForegroundTask.sendDataToMain({'lapLogsUpdate': List<Map<String, dynamic>>.from(_lapLogs)});
        // print('MyTaskHandler: Sent lapLogsUpdate to UI after editing lap.');
      } else {
        // print('MyTaskHandler: editLap - Lap to edit not found with startTime: $originalStartTime, endTime: $originalEndTime');
      }
    } else if (action == 'requestFullState') {
       final String currentFormattedTime = _actualSessionStartTime != null
         ? formatDisplayTime(DateTime.now().difference(_actualSessionStartTime!))
         : '00:00:00:00';
      FlutterForegroundTask.sendDataToMain({
        'formattedTime': currentFormattedTime,
        'lapLogsUpdate': List<Map<String, dynamic>>.from(_lapLogs),
        'isServiceCurrentlyRunning': _actualSessionStartTime != null,
      });
      // print('MyTaskHandler: Sent full state (time and laps) to UI upon request.');
    }
    else {
      // print('MyTaskHandler: Unknown action received: $action. Ignoring.');
    }
  }

  @override
  void onNotificationButtonPressed(String id) {
    // print('MyTaskHandler: Notification button pressed: $id');
    if (id == 'STOP_ACTION') { // 通知ボタンのIDに応じて処理
        onReceiveData({'action': 'stopAndRecordFinalLap'});
    } else if (id == 'LAP_ACTION') {
        onReceiveData({'action': 'recordLap'});
    }
  }

  @override
  void onNotificationPressed() {
    // print('MyTaskHandler: Notification pressed');
    FlutterForegroundTask.launchApp("/");
  }

  @override
  void onNotificationDismissed() {
    // print('MyTaskHandler: Notification dismissed by user. Stopping service.');
    // 通知が消されたらサービスを停止する（アプリの仕様による）
    // FlutterForegroundTask.stopService(); // これを呼ぶと onDestroy がトリガーされる
  }
}
