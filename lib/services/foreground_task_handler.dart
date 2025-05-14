// lib/services/foreground_task_handler.dart
import 'dart:async';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import '../utils/time_formatters.dart';
import '../theme/color_constants.dart'; // colorLabels のためにインポート

// フォアグラウンドタスクのエントリーポイント
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(MyTaskHandler());
}

class MyTaskHandler extends TaskHandler {
  DateTime? _actualSessionStartTime; // セッションの実際の開始時刻
  List<Map<String, dynamic>> _lapLogs = []; // ラップログのリスト
  DateTime? _lastLapEndTime; // 最後に記録されたラップの終了時刻（次のラップの開始時刻になる）

  Timer? _timer; // 時間更新とUI通知のためのタイマー

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // サービス開始時の初期化処理
    _actualSessionStartTime = DateTime.now(); // 現在時刻をセッション開始時刻とする
    _lapLogs = []; // ラップログをクリア
    _lastLapEndTime = _actualSessionStartTime; // 最初のラップの開始はセッション開始と同じ

    print('MyTaskHandler: onStart - Service started. Actual start time: $_actualSessionStartTime, Lap logs initialized.');
    _startSendingTimeUpdates(); // 時間更新の送信を開始
  }

  void _startSendingTimeUpdates() {
    _timer?.cancel(); // 既存のタイマーがあればキャンセル
    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) { // 100ミリ秒ごとに実行
      if (_actualSessionStartTime == null) {
        // セッションが開始されていなければタイマーを停止
        timer.cancel();
        return;
      }
      // 経過時間を計算
      final Duration elapsedTime = DateTime.now().difference(_actualSessionStartTime!);
      final String formattedTime = formatDisplayTime(elapsedTime); // 表示用にフォーマット

      // UIに現在の時間と実行状態を送信
      FlutterForegroundTask.sendDataToMain({
        'formattedTime': formattedTime,
        'isServiceCurrentlyRunning': true, // サービスが実行中であることを示す
      });
      // 通知を更新
      FlutterForegroundTask.updateService(
        notificationTitle: 'ストップウォッチ実行中 (Clone)',
        notificationText: formattedTime,
      );
    });
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // ForegroundTaskOptions.eventAction が none の場合、このメソッドは呼ばれない想定
    // print('MyTaskHandler: onRepeatEvent at $timestamp (This might be redundant if using manual Timer)');
  }


  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    _timer?.cancel(); // タイマーを停止
    print('MyTaskHandler: onDestroy at $timestamp (isTimeout: $isTimeout)');
    // _actualSessionStartTime = null; // 状態をリセットするかどうかはアプリの仕様による
    // _lapLogs はクリアしない（UIが最後に取得したり、停止後に編集・保存するため）
    // _lastLapEndTime = null;

    // UIにサービスが完全に停止したことを明確に伝える (stopAndRecordFinalLapで送信済みのため、ここでは不要な場合もある)
    // FlutterForegroundTask.sendDataToMain({'serviceDefinitelyStopped': true, 'isServiceCurrentlyRunning': false});
  }

  // ラップを内部的に記録するメソッド
  // isFinalLap: これがセッションの最後のラップか（ストップウォッチ停止時か）
  // sendUpdateToUi: このメソッド内でUIに更新を送信するか
  void _recordLapInternal(bool isFinalLap, {bool sendUpdateToUi = true}) {
    if (_actualSessionStartTime == null || _lastLapEndTime == null) {
      print('MyTaskHandler: Cannot record lap, service not properly started.');
      return;
    }

    final DateTime currentLapTime = DateTime.now(); // 現在時刻をラップの終了時刻とする
    // セッション開始からの総経過時間
    final Duration overallElapsedTime = currentLapTime.difference(_actualSessionStartTime!);

    // このラップの開始時刻（セッション開始からの経過時間）をフォーマット
    final String lapStartTimeFormatted = formatLogTime(_lastLapEndTime!.difference(_actualSessionStartTime!));
    // このラップの終了時刻（セッション開始からの経過時間）をフォーマット
    final String lapEndTimeFormatted = formatLogTime(overallElapsedTime);

    final newLapLog = {
      'actualSessionStartTimeEpoch': _actualSessionStartTime!.millisecondsSinceEpoch,
      'startTimeFormatted': lapStartTimeFormatted,
      'endTimeFormatted': lapEndTimeFormatted,
      'memo': isFinalLap ? '最終ラップ' : '', // 最終ラップの場合、特別なメモを設定（任意）
      'colorLabelName': colorLabels.keys.first, // デフォルトの色ラベル
    };
    _lapLogs.add(newLapLog); // ラップログリストに追加
    _lastLapEndTime = currentLapTime; // 次のラップのために、現在の終了時刻を保持

    print('MyTaskHandler: Lap recorded (isFinal: $isFinalLap). New lap: $newLapLog');
    print('MyTaskHandler: All lap logs count: ${_lapLogs.length}');

    if (sendUpdateToUi) {
      // UIにラップログの更新を通知
      FlutterForegroundTask.sendDataToMain({'lapLogsUpdate': List<Map<String, dynamic>>.from(_lapLogs)});
      print('MyTaskHandler: Sent lapLogsUpdate to UI.');
    }
  }


  @override
  void onReceiveData(Object data) {
    print('MyTaskHandler: Received data from UI: $data');
    if (data is! Map<String, dynamic>) {
      print('MyTaskHandler: Received data is not a Map. Ignoring.');
      return;
    }

    final Map<String, dynamic> actionData = data;
    final String? action = actionData['action'] as String?;

    if (action == 'recordLap') {
      // 通常のラップ記録
      _recordLapInternal(false, sendUpdateToUi: true);
    } else if (action == 'stopAndRecordFinalLap') {
      // ストップウォッチ停止と最終ラップ記録
      if (_actualSessionStartTime != null && _lastLapEndTime != null) {
        // 最後の区間をラップとして記録 (UIへの更新はここでは行わない)
        _recordLapInternal(true, sendUpdateToUi: false);
      }
      // 最終的な状態をUIに送信
      final String finalFormattedTime = _actualSessionStartTime != null
          ? formatDisplayTime(DateTime.now().difference(_actualSessionStartTime!))
          : '00:00:00:00'; // 念のためフォールバック

      FlutterForegroundTask.sendDataToMain({
        'lapLogsUpdate': List<Map<String, dynamic>>.from(_lapLogs), // 最終ラップを含むログ
        'formattedTime': finalFormattedTime, // 最終的な経過時間
        'serviceStopped': true, // UIにサービス停止を明確に伝える
        'isServiceCurrentlyRunning': false, // サービスが停止したことを示す
      });
      print('MyTaskHandler: Recorded final lap, sent final state, and stopping service.');
      FlutterForegroundTask.stopService(); // サービスを実際に停止
    }
    else if (action == 'editLap') {
      // ラップ編集処理
      final String? originalStartTime = actionData['originalStartTimeFormatted'] as String?;
      final String? originalEndTime = actionData['originalEndTimeFormatted'] as String?;
      final int? actualSessionStartTimeEpoch = actionData['actualSessionStartTimeEpoch'] as int?; // 特定用に追加
      final String? updatedMemo = actionData['updatedMemo'] as String?;
      final String? updatedColorLabelName = actionData['updatedColorLabelName'] as String?;

      if (originalStartTime == null || originalEndTime == null || updatedMemo == null || updatedColorLabelName == null || actualSessionStartTimeEpoch == null) {
        print('MyTaskHandler: editLap - Missing required data for editing. Ignoring.');
        return;
      }

      int lapIndex = -1;
      for (int i = 0; i < _lapLogs.length; i++) {
        // actualSessionStartTimeEpoch, startTimeFormatted, endTimeFormatted でラップを特定
        if (_lapLogs[i]['actualSessionStartTimeEpoch'] == actualSessionStartTimeEpoch &&
            _lapLogs[i]['startTimeFormatted'] == originalStartTime &&
            _lapLogs[i]['endTimeFormatted'] == originalEndTime) {
          lapIndex = i;
          break;
        }
      }

      if (lapIndex != -1) {
        _lapLogs[lapIndex]['memo'] = updatedMemo;
        _lapLogs[lapIndex]['colorLabelName'] = updatedColorLabelName;
        print('MyTaskHandler: Lap edited. Index: $lapIndex, Updated data: ${_lapLogs[lapIndex]}');
        // UIに更新されたラップログリストを送信
        FlutterForegroundTask.sendDataToMain({'lapLogsUpdate': List<Map<String, dynamic>>.from(_lapLogs)});
        print('MyTaskHandler: Sent lapLogsUpdate to UI after editing lap.');
      } else {
        print('MyTaskHandler: editLap - Lap to edit not found with sessionEpoch: $actualSessionStartTimeEpoch, startTime: $originalStartTime, endTime: $originalEndTime');
      }
    } else if (action == 'requestFullState') {
      // UIから現在の全状態（時間、ラップログ、実行状態）を要求された場合
       final String currentFormattedTime = _actualSessionStartTime != null
         ? formatDisplayTime(DateTime.now().difference(_actualSessionStartTime!))
         : '00:00:00:00'; // フォールバック
      FlutterForegroundTask.sendDataToMain({
        'formattedTime': currentFormattedTime,
        'lapLogsUpdate': List<Map<String, dynamic>>.from(_lapLogs),
        'isServiceCurrentlyRunning': _actualSessionStartTime != null, // 実行中かどうかのフラグ
      });
      print('MyTaskHandler: Sent full state (time and laps) to UI upon request.');
    }
    else {
      print('MyTaskHandler: Unknown action received: $action. Ignoring.');
    }
  }

  @override
  void onNotificationButtonPressed(String id) {
    // 通知上のボタンが押されたときの処理 (現在は未使用)
    print('MyTaskHandler: Notification button pressed: $id');
    // 例: if (id == 'STOP_ACTION') { onReceiveData({'action': 'stopAndRecordFinalLap'}); }
  }

  @override
  void onNotificationPressed() {
    // 通知自体がタップされたときの処理
    print('MyTaskHandler: Notification pressed. Launching app.');
    FlutterForegroundTask.launchApp("/"); // アプリを起動/フォアグラウンドに表示
    // 必要であれば、特定の画面に遷移させるためのデータを送信することも可能
    // FlutterForegroundTask.sendDataToMain("onNotificationPressed");
  }

  @override
  void onNotificationDismissed() {
    // 通知がユーザーによって消されたときの処理 (現在は未使用)
    print('MyTaskHandler: Notification dismissed by user.');
    // 仕様によっては、ここでサービスを停止するなどの処理を入れることも考えられる
    // FlutterForegroundTask.stopService();
  }
}
