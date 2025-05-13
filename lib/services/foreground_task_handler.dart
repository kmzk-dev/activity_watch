// lib/services/foreground_task_handler.dart
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

// TaskHandlerを開始するためのコールバック関数
// 必ずトップレベル関数またはstatic関数である必要があります。
@pragma('vm:entry-point')
void startCallback() {
  // TaskHandlerを登録します
  FlutterForegroundTask.setTaskHandler(MyTaskHandler());
}

// バックグラウンドで実行されるタスクの処理を定義するクラス
class MyTaskHandler extends TaskHandler {

  // タスクが開始されたときに呼び出されます。
  // starter引数はどのTaskStarterから開始されたかの情報を含みます (startService, restartService, updateService)
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    print('Foreground task started at $timestamp (starter: ${starter.name})');
    // ここにタスク開始時の初期化処理などを記述できます
  }

  // ForegroundTaskOptionsで設定されたeventActionに基づいて呼び出されます。
  // (例: ForegroundTaskEventAction.repeat の場合は定期的に呼び出される)
  @override
  void onRepeatEvent(DateTime timestamp) {
    print('Repeat event at $timestamp');

    // UI側のIsolateにデータを送信します。
    final Map<String, dynamic> data = {
      "timestampMillis": timestamp.millisecondsSinceEpoch,
      "message": "Hello from background!", // 例としてメッセージを追加
    };
    FlutterForegroundTask.sendDataToMain(data);

    // 通知の内容を更新することもできます
    // FlutterForegroundTask.updateService(
    //   notificationTitle: 'MyTaskHandler',
    //   notificationText: 'Repeating event at ${timestamp.second}',
    // );
  }

  // タスクが破棄されるときに呼び出されます。
  // isTimeoutがtrueの場合、OSによってタイムアウトで破棄されたことを示します。
  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    print('Foreground task destroyed at $timestamp (isTimeout: $isTimeout)');
    // ここにリソースのクリーンアップ処理などを記述できます
  }

  // UI側から FlutterForegroundTask.sendDataToTask でデータが送信されたときに呼び出されます。
  @override
  void onReceiveData(Object data) {
    print('Received data in TaskHandler: $data');
    // UIからのデータに基づいて処理を行う場合に使用します
  }

  // 通知に追加されたボタンが押されたときに呼び出されます。
  // idにはNotificationButtonで指定したidが入ります。
  @override
  void onNotificationButtonPressed(String id) {
    print('Notification button pressed: $id');
  }

  // 通知自体がタップされたときに呼び出されます。
  @override
  void onNotificationPressed() {
    // アプリをフォアグラウンドに表示するなどのアクション
    print('Notification pressed');
    FlutterForegroundTask.launchApp("/"); // アプリのルートに遷移
    FlutterForegroundTask.sendDataToMain("onNotificationPressed"); // UIに通知が押されたことを伝える
  }

    // 通知がユーザーによって閉じられた（スワイプされたなど）場合に呼び出されます。
  @override
  void onNotificationDismissed() {
    print('Notification dismissed');
  }
}