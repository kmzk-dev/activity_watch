// main.dart
import 'package:flutter/material.dart';
import 'screens/saved_sessions_screen.dart'; // 保存済みセッション画面をインポート
import 'screens/stopwatch_screen.dart'; // ストップウォッチ画面をインポート
import 'util.dart';
import 'theme.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart'; // インポート済み
import 'services/foreground_task_handler.dart';

// アプリケーションのエントリーポイント
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterForegroundTask.initCommunicationPort();
  runApp(const ActivityWatchApp());
}

// ルートウィジェット
class ActivityWatchApp extends StatelessWidget {
  const ActivityWatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    final brightness = View.of(context).platformDispatcher.platformBrightness;
    TextTheme textTheme = createTextTheme(context, "Noto Sans JP", "Noto Sans JP");

    MaterialTheme theme = MaterialTheme(textTheme);
    return MaterialApp(
      title: 'Activity Watch',
      theme: brightness == Brightness.light ? theme.light() : theme.dark(),
      home: const AppShell(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// アプリケーションの主要な構造（シェル）を定義するStatefulWidget
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

// AppShellのStateクラス
class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;
  bool _isServiceRunning = false; // <--- 追加: サービス実行状態を管理

  // 各タブに対応するウィジェットのリスト
  // このリスト内のウィジェットはIndexedStackによって状態が保持される
  static const List<Widget> _widgetOptions = <Widget>[
    StopwatchScreenWidget(), // 計測タブの画面
    SavedSessionsScreen(), // 履歴タブの画面
  ];

  // タスクデータを受信したときのコールバック関数
  // FlutterForegroundTaskからデータを受信するためのコールバック関数
  void _onReceiveTaskData(Object data) {
    print('Received data in UI: $data');
    if (data is Map<String, dynamic>) {
      final dynamic timestampMillis = data["timestampMillis"];
      if (timestampMillis != null) {
        final DateTime timestamp = DateTime.fromMillisecondsSinceEpoch(timestampMillis, isUtc: true);
        print('Received timestamp (JST): ${timestamp.toLocal()}');
        //TODO: 受信データでUIを更新する処理
      }
    }
  }

  // 必要な権限を要求する関数
  Future<void> _requestPermissions() async {
    // 通知権限 (Android 13+ / iOS)
    final NotificationPermission notificationPermission =
        await FlutterForegroundTask.checkNotificationPermission();
    if (notificationPermission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }
  }
  // Foreground Task サービスを初期化する関数
  void _initService() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'foreground_service', // 通知チャンネルID (マニフェストと合わせる必要はない)
        channelName: 'Foreground Service Notification', // 通知チャンネル名
        channelDescription:
            'ストップウォッチがバックグラウンドで実行中です。', // 通知の説明
        channelImportance: NotificationChannelImportance.LOW, // 重要度を低に設定 (通知音などを抑制)
        onlyAlertOnce: false, // 初回のみ通知音などを鳴らす (重要度LOWなら影響少ないかも)
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true, // iOSでも通知を表示
        playSound: false, // 音は鳴らさない
      ),
      foregroundTaskOptions: ForegroundTaskOptions(        
        eventAction: ForegroundTaskEventAction.repeat(1000),// ストップウォッチの更新頻度に合わせて調整 (例: 1秒ごと)
        autoRunOnBoot: false, // 端末起動時の自動実行はしない
        autoRunOnMyPackageReplaced: false, // アプリ更新時の自動実行はしない
        allowWakeLock: true, // スリープ状態でも実行を維持しようとする
        allowWifiLock: false, // Wifiロックは通常不要
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    FlutterForegroundTask.addTaskDataCallback(_onReceiveTaskData);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _requestPermissions();
      _initService();
      // アプリ起動時に現在のサービス状態を確認し、UIに反映
      final isRunning = await FlutterForegroundTask.isRunningService;
      if (mounted) {
        setState(() {
          _isServiceRunning = isRunning;
        });
      }
    });
  }
  

  @override
  void dispose() {
    // コールバックを解除
    FlutterForegroundTask.removeTaskDataCallback(_onReceiveTaskData);
    super.dispose();
  }

  // Foreground Task サービスを開始する関数
  Future<void> _startForegroundService() async {
    try {
      // サービスが実行中でなければ開始する
      if (!await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.startService(
          notificationTitle: 'ストップウォッチ実行中',
          notificationText: 'タイマーがバックグラウンドで動作しています。',
          callback: startCallback, // lib/services/foreground_task_handler.dart で定義されたコールバック
        );
      }
      setState(() {
        _isServiceRunning = true;
      });
      print('Foreground service started.');
    } catch (e) {
      print('Failed to start foreground service: $e');
    }
  }

    // Foreground Task サービスを停止する関数
  Future<void> _stopForegroundService() async {
    try {
      await FlutterForegroundTask.stopService();
      setState(() {
        _isServiceRunning = false;
      });
      print('Foreground service stopped.');
    } catch (e) {
      print('Failed to stop foreground service: $e');
    }
  }
  
  // BottomNavigationBarのアイテムがタップされたときの処理
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index; // 選択されたタブのインデックスを更新
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context); // 現在のテーマを取得

    return Scaffold(   
      body: IndexedStack(
        index: _selectedIndex,
        children: _widgetOptions,
      ),
      // 下部のナビゲーションバー
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          // 計測タブのアイテム
          BottomNavigationBarItem(
            icon: Icon(Icons.timer_outlined), // 計測アイコン
            label: '計測', // ラベル
          ),
          // 履歴タブのアイテム
          BottomNavigationBarItem(
            icon: Icon(Icons.history), // 履歴アイコン
            label: '履歴', // ラベル
          ),
        ],
        currentIndex: _selectedIndex, // 現在選択されているアイテムのインデックス
        onTap: _onItemTapped, // アイテムがタップされたときのコールバック
        selectedItemColor: theme.colorScheme.primary, // 選択されたアイテムの色をテーマのプライマリカラーに設定
        unselectedItemColor: theme.colorScheme.onSurface.withOpacity(0.6), // 非選択アイテムの色を少し薄く設定
        showUnselectedLabels: true, // 非選択のラベルも表示する
        // showSelectedLabels: true, // 選択されたラベルはデフォルトで表示されます
      ),
    );
  }
}
