// lib/screens/stopwatch_screen_clone.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:vibration/vibration.dart';

import '../models/log_entry.dart';
import '../theme/color_constants.dart';

import '../utils/time_formatters.dart';
import '../utils/log_exporter.dart';
import '../utils/dialog_utils.dart';
import '../utils/session_dialog_utils.dart';
import '../utils/session_storage.dart';
import '../utils/string_utils.dart';
import '../utils/log_data_converter.dart';

import './widgets/log_card_carousel.dart';
import './settings_screen.dart';
import './widgets/log_color_summary_chart.dart';
import './widgets/timer_display.dart';
import './widgets/stopwatch_floating_action_button.dart';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import '../services/foreground_task_handler.dart';


class StopwatchScreenCloneWidget extends StatefulWidget {
  const StopwatchScreenCloneWidget({super.key});

  @override
  State<StopwatchScreenCloneWidget> createState() => _StopwatchScreenCloneWidgetState();
}

class _StopwatchScreenCloneWidgetState extends State<StopwatchScreenCloneWidget> with WidgetsBindingObserver {
  bool _isRunning = false;
  bool _isServiceActuallyRunning = false;
  String _elapsedTime = '00:00:00:00';
  List<LogEntry> _logs = [];
  // DateTime? _currentActualSessionStartTime; // MyTaskHandler側で管理

  List<String> _commentSuggestions = [];
  static const String _suggestionsKey = 'comment_suggestions';
  static const String _savedSessionsKey = 'saved_log_sessions';
  DateTime? _lastSuggestionsLoadTime;

  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const double carouselHeight = 160.0;
  static const double fabWidgetHeight = 120.0;
  static const double pageIndicatorHeight = 24.0;

  bool? _hasVibrator;
  static const int _lapVibrationDuration = 100;
  static const int _stopVibrationDuration = 300;

  @override
  void initState() {
    super.initState();
    print("StopwatchScreenClone: initState");
    WidgetsBinding.instance.addObserver(this);
    _checkVibrationSupport();
    FlutterForegroundTask.addTaskDataCallback(_onReceiveTaskData);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        print("StopwatchScreenClone: initState - addPostFrameCallback executing");
        await _requestPermissions();
        _initForegroundTaskService();
        await _checkAndSyncServiceState();
        loadSuggestionsFromPrefs(force: true);
      }
    });
  }

  @override
  void dispose() {
    print("StopwatchScreenClone: dispose");
    FlutterForegroundTask.removeTaskDataCallback(_onReceiveTaskData);
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    print("StopwatchScreenClone: didChangeAppLifecycleState - $state");
    if (state == AppLifecycleState.resumed) {
      _checkAndSyncServiceState();
    }
  }

  void _onReceiveTaskData(Object? data) {
    if (!mounted) return;

    if (data is Map<String, dynamic>) {
      if (data.containsKey('formattedTime')) {
        final String newElapsedTime = data['formattedTime'] as String;
        bool serviceIsActuallyRunning = data['isServiceCurrentlyRunning'] as bool? ?? _isServiceActuallyRunning;
        setState(() {
          _elapsedTime = newElapsedTime;
          _isServiceActuallyRunning = serviceIsActuallyRunning;
          if (_isServiceActuallyRunning && !_isRunning) {
            _isRunning = true;
          } else if (!_isServiceActuallyRunning && _isRunning) {
            // サービスが停止したがUIがまだ実行中と認識している場合、UIも停止状態に合わせる
            _isRunning = false;
          }
        });
      }

      if (data.containsKey('lapLogsUpdate')) {
        final List<dynamic>? lapMapListRaw = data['lapLogsUpdate'] as List<dynamic>?;
        if (lapMapListRaw != null) {
          setState(() {
            _logs = convertBackgroundTaskLapListToLogEntries(lapMapListRaw);
            _updateCurrentPageAndLogEntryBasedOnLogs(); // ページ表示を更新
            print('StopwatchScreenClone: Received lapLogsUpdate and updated _logs. Count: ${_logs.length}');
          });
        }
      }

      if (data.containsKey('serviceStopped') && data['serviceStopped'] == true) {
        print("StopwatchScreenClone: Received 'serviceStopped' signal from TaskHandler.");
        setState(() {
          _isServiceActuallyRunning = false;
          _isRunning = false; // サービスが止まったらUI上の実行状態もfalseに
          if (data.containsKey('formattedTime')) {
             _elapsedTime = data['formattedTime'] as String;
          }
          // ラップログは 'lapLogsUpdate' で最終状態が送られてくるはず
        });
      }
    } else if (data is String && data == "onNotificationPressed") {
      print("StopwatchScreenClone: Notification was pressed, received in UI.");
      // 必要であれば、通知タップ時の追加処理をここに記述
    }
  }

  Future<void> _requestPermissions() async {
    // 通知権限のリクエスト (Android 13以降で必要)
    if (await FlutterForegroundTask.checkNotificationPermission() != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }
    // 必要に応じて他の権限もリクエスト (例: バッテリー最適化の除外など)
  }

  void _initForegroundTaskService() {
    // フォアグラウンドタスクの初期化
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'stopwatch_foreground_service_clone',
        channelName: 'Stopwatch Foreground Service (Clone)',
        channelDescription: 'Stopwatch (Clone) is running in the background.',
        channelImportance: NotificationChannelImportance.LOW, // 通知の重要度
        priority: NotificationPriority.LOW, // 通知の優先度
        onlyAlertOnce: true, // 新しい通知で一度だけ音を鳴らすか
        enableVibration: false, // 通知時のバイブレーションの有無
        playSound: false, // 通知音の有無
        // アイコン設定 (例: 'ic_stat_ stopwatch')
        // iconData: const NotificationIconData(resType: ResourceType.mipmap, name: 'ic_launcher'),
        // 通知タップ時のアクション設定
        // onTap: () => FlutterForegroundTask.launchApp("/stopwatch_clone"), // 例: 特定のルートに遷移
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true, // iOSで通知を表示するか
        playSound: false, // 通知音の有無
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(1000),
        autoRunOnBoot: false, // OS起動時に自動実行するか
        autoRunOnMyPackageReplaced: false, // アプリ更新時に自動実行するか
        allowWakeLock: true, // スリープ状態でもタスクを実行し続けるか (true推奨)
        allowWifiLock: false, // Wifi接続を維持するか
      ),
    );
    print("StopwatchScreenClone: FlutterForegroundTask.init completed.");
  }

  Future<void> _checkAndSyncServiceState() async {
    if (!mounted) return;
    print("StopwatchScreenClone: _checkAndSyncServiceState called");

    final bool isActuallyRunningNow = await FlutterForegroundTask.isRunningService;
    print("StopwatchScreenClone: Service isActuallyRunningNow: $isActuallyRunningNow");

    setState(() {
      _isServiceActuallyRunning = isActuallyRunningNow;
      if (!_isServiceActuallyRunning) {
        _isRunning = false; // サービスが動いていなければUIも非実行状態
        _elapsedTime = '00:00:00:00'; // 時間もリセット
        // _logs = []; // ログもリセットするかどうかは仕様による (アプリ再起動時の復元を考慮するなら保持)
      } else {
         _isRunning = true; // サービスが動いていればUIも実行状態に (ただし、これはMyTaskHandlerからの通知で上書きされるべき)
      }
    });

    if (isActuallyRunningNow) {
      // サービスが既に実行中の場合、現在の状態をタスクハンドラに問い合わせる
      print('StopwatchScreenClone: Service is running, requesting full state from MyTaskHandler.');
      FlutterForegroundTask.sendDataToTask({'action': 'requestFullState'});
    }
  }


  Future<void> _handleStartStopwatch() async {
    // 既にサービスが動いている場合は、一度停止してから再開する（リセット動作）
    if (_isServiceActuallyRunning) {
      // UI上は即座に停止表示にしたいが、サービス停止完了を待つとラグが出る可能性がある。
      // MyTaskHandler側でstopAndRecordFinalLapが呼ばれ、最終的にserviceStoppedが通知される。
      // ここでは、新しいセッションを開始する前に、既存のサービスを確実に止めることを優先。
      await _stopForegroundService(); // MyTaskHandlerに停止を指示
      await Future.delayed(const Duration(milliseconds: 200)); // サービス停止処理の完了を少し待つ
    }
    // ログをクリア
    _logs.clear();

    // UIの状態を更新
    setState(() {
      _isRunning = true; // UIを実行中に
      _elapsedTime = '00:00:00:00'; // 時間をリセット
      _currentPage = 0; // ページネーションをリセット
    });
    // ページコントローラもリセット
    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }
    // フォアグラウンドサービスを開始
    await _startForegroundService();
  }

  Future<void> _startForegroundService() async {
    // 既にサービスが実行中の場合は開始しない
    if (await FlutterForegroundTask.isRunningService) {
      print("StopwatchScreenClone: Service is already running. Not starting again.");
      // UIの状態とサービスの実際の状態が食い違っている場合、同期する
      if(mounted && !_isServiceActuallyRunning) {
        setState(() {
          _isServiceActuallyRunning = true;
          if(!_isRunning) _isRunning = true; // UIも実行中に
        });
      }
      return;
    }
    try {
      // フォアグラウンドサービスを開始
      await FlutterForegroundTask.startService(
        notificationTitle: 'ストップウォッチ計測中', // 通知タイトル
        notificationText: _elapsedTime, // 通知テキスト（初期値）
        callback: startCallback, // エントリーポイント関数
      );
      // UIの状態を更新
      if (mounted) {
        setState(() {
          _isServiceActuallyRunning = true;
          if (!_isRunning) _isRunning = true; // UIも実行中に
        });
      }
      print('StopwatchScreenClone: Foreground service start initiated.');
    } catch (e) {
      print('StopwatchScreenClone: Failed to start foreground service: $e');
      // エラー発生時はUIの状態を非実行に戻す
      if (mounted) {
        setState(() {
          _isServiceActuallyRunning = false;
          _isRunning = false;
        });
      }
    }
  }

  Future<void> _handleStopStopwatch() async {
    // UIが非実行状態で、かつサービスも実際に動いていない場合は何もしない
    if (!_isRunning && !_isServiceActuallyRunning) {
      print("StopwatchScreenClone: Stopwatch already stopped or service not running.");
      return;
    }
    // バイブレーション
    if (_hasVibrator == true) {
      Vibration.vibrate(duration: _stopVibrationDuration);
    }
    // UIを即座に停止表示に
    setState(() {
      _isRunning = false;
    });
    // MyTaskHandler に最終ラップ記録とサービス停止を指示
    print("StopwatchScreenClone: Sending 'stopAndRecordFinalLap' action to TaskHandler.");
    FlutterForegroundTask.sendDataToTask({'action': 'stopAndRecordFinalLap'});
    // 実際のサービス停止とUIの完全な状態同期は MyTaskHandler からの通知 (`serviceStopped: true`) で行う
  }

  // このメソッドは、主にUIから明示的にサービスだけを止めたい場合に使う（例：スタート前のリセット時）
  Future<void> _stopForegroundService() async {
    if (!await FlutterForegroundTask.isRunningService) {
      print("StopwatchScreenClone: Service is not running. Not stopping (from _stopForegroundService).");
      if (mounted && _isServiceActuallyRunning) { // UIと実際の状態が不一致なら同期
        setState(() {
          _isServiceActuallyRunning = false;
          if (_isRunning) _isRunning = false;
        });
      }
      return;
    }
    try {
      // MyTaskHandlerに停止を指示するのがより安全な場合もある
      // FlutterForegroundTask.sendDataToTask({'action': 'stopAndRecordFinalLap'});
      // 直接サービスを停止する場合
      await FlutterForegroundTask.stopService();
      print('StopwatchScreenClone: Foreground service stop initiated (from _stopForegroundService).');
      // UIの状態更新は MyTaskHandler からの 'serviceStopped' 通知に任せるか、ここで強制的に行う
      if (mounted) {
        setState(() {
          _isServiceActuallyRunning = false;
          _isRunning = false;
        });
      }
    } catch (e) {
      print('StopwatchScreenClone: Failed to stop foreground service (from _stopForegroundService): $e');
      // エラー時もUIの状態を非実行に試みる
      if (mounted) {
        setState(() {
          _isServiceActuallyRunning = false;
          _isRunning = false;
        });
      }
    }
  }


  void _handleLapRecord() async {
    // UIが実行中でない、またはサービスが実際に動いていない場合はラップを記録しない
    if (!_isRunning || !_isServiceActuallyRunning) {
      print("StopwatchScreenClone: Cannot record lap, stopwatch not running or service not running.");
      return;
    }
    // バイブレーション
    if (_hasVibrator == true) {
      Vibration.vibrate(duration: _lapVibrationDuration);
    }
    // MyTaskHandler にラップ記録を指示
    print("StopwatchScreenClone: Sending 'recordLap' action to TaskHandler.");
    FlutterForegroundTask.sendDataToTask({'action': 'recordLap'});
    // ラップ記録後のUI更新（ログリストの更新など）は MyTaskHandler からの通知 (`lapLogsUpdate`) で行う
  }

  Future<void> _showEditLogDialog(int pageViewIndex) async {
    if (_logs.isEmpty) {
      print("StopwatchScreenClone: No logs to edit.");
      return;
    }

    // pageViewIndex は表示用リスト（新しいものが先頭）のインデックス
    // _logs リスト（古いものが先頭）の実際のインデックスに変換
    final int actualLogIndex = _logs.length - 1 - pageViewIndex;

    if (actualLogIndex < 0 || actualLogIndex >= _logs.length) {
      print("StopwatchScreenClone: Invalid actualLogIndex for editing: $actualLogIndex. Original logs count: ${_logs.length}");
      return;
    }
    final LogEntry logToEdit = _logs[actualLogIndex]; // オリジナルの_logsリストから取得

    await loadSuggestionsFromPrefs(force: true); // 最新のサジェストを読み込み
    if (!mounted) return;

    final Map<String, String>? result = await showLogCommentEditDialog(
      context: context,
      initialMemo: logToEdit.memo,
      initialColorLabelName: logToEdit.colorLabelName,
      commentSuggestions: _commentSuggestions,
      katakanaToHiraganaConverter: katakanaToHiragana,
      availableColorLabels: colorLabels,
    );

    if (result != null && mounted) {
      final String newMemo = result['memo'] ?? logToEdit.memo;
      final String newColorLabel = result['colorLabel'] ?? logToEdit.colorLabelName;

      if (_isServiceActuallyRunning) {
        // サービス実行中: MyTaskHandler に編集を依頼
        print('StopwatchScreenClone: Service is running. Sending editLap command to MyTaskHandler.');
        FlutterForegroundTask.sendDataToTask({
          'action': 'editLap',
          'originalStartTimeFormatted': logToEdit.startTime,
          'originalEndTimeFormatted': logToEdit.endTime,
          'actualSessionStartTimeEpoch': logToEdit.actualSessionStartTime.millisecondsSinceEpoch, // 特定精度向上のため追加
          'updatedMemo': newMemo,
          'updatedColorLabelName': newColorLabel,
        });
      } else {
        // サービス停止中: UI側で直接 _logs を更新
        print('StopwatchScreenClone: Service is stopped. Updating log locally.');
        setState(() {
          _logs[actualLogIndex].memo = newMemo;
          _logs[actualLogIndex].colorLabelName = newColorLabel;
          // _logs が更新されたので、表示に使われる displayLogsForCarousel も自動的に更新される
          // 必要であれば、_updateCurrentPageAndLogEntryBasedOnLogs(); を呼んでページ表示も調整
        });
        print('StopwatchScreenClone: Log updated locally. New memo: $newMemo, New color: $newColorLabel for log at index $actualLogIndex');
      }
    }
    if (!mounted) return;
    FocusScope.of(context).unfocus(); // キーボードを閉じる
  }

  Future<void> _showSaveSessionDialog() async {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    if (_logs.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('保存するログがありません。', style: TextStyle(color: colorScheme.onError)),
          backgroundColor: colorScheme.error,
        ),
      );
      return;
    }
    // サービスが実際に実行中の場合は保存を許可しない
    if (_isServiceActuallyRunning) {
       if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('計測を停止してから保存してください。', style: TextStyle(color: colorScheme.onError)),
          backgroundColor: colorScheme.error,
        ),
      );
      return;
    }

    final Map<String, String>? sessionData = await showSessionDetailsInputDialog(
      context: context,
      dialogTitle: 'セッションを保存',
      initialTitle: '', // 新規保存なので空
      initialComment: '', // 新規保存なので空
      positiveButtonText: '保存',
    );

    if (!mounted) return;
    FocusScope.of(context).unfocus(); // キーボードを閉じる

    if (sessionData != null && sessionData['title'] != null && sessionData['title']!.isNotEmpty) {
      print("StopwatchScreenClone: Save session requested. Title: ${sessionData['title']}. Logs count: ${_logs.length}");
      // session_storage.dart の saveSession 関数を呼び出す
      await saveSession(
        context: context, // SnackBar表示のため
        title: sessionData['title']!,
        comment: sessionData['comment'], // nullの可能性あり
        logs: _logs, // 現在のログリスト
        savedSessionsKey: _savedSessionsKey, // SharedPreferencesのキー
      );
      // 保存成功のSnackBarはsaveSession関数内で表示されることを期待
    }
  }

  Future<void> _checkVibrationSupport() async {
    // デバイスがバイブレーションをサポートしているか確認
    _hasVibrator = await Vibration.hasVibrator();
  }

  Future<void> loadSuggestionsFromPrefs({bool force = false}) async {
    // 短期間での連続読み込みを避ける
    if (!force && _lastSuggestionsLoadTime != null && DateTime.now().difference(_lastSuggestionsLoadTime!) < const Duration(seconds: 1)) {
      return;
    }
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _commentSuggestions = prefs.getStringList(_suggestionsKey) ?? [];
      _lastSuggestionsLoadTime = DateTime.now();
    });
  }

  List<LogEntry> _getDisplayLogs() {
    // 表示用のログリスト（新しいものが先頭に来るように逆順にする）
    return _logs.reversed.toList();
  }

  void _updateCurrentPageAndLogEntryBasedOnLogs() {
    if (!mounted) return;
    setState(() {
      if (_logs.isEmpty) {
        _currentPage = 0;
      } else {
        // 現在のページがログの範囲外にならないように調整
        if (_currentPage >= _logs.length) {
          _currentPage = _logs.length - 1;
        }
        if (_currentPage < 0 && _logs.isNotEmpty) { // ログがある場合のみ0に
           _currentPage = 0;
        } else if (_logs.isEmpty) { // ログがなくなったら0に
            _currentPage = 0;
        }
      }
    });
     // ページコントローラーも現在のページに合わせる (アニメーションなしでジャンプ)
    if (_pageController.hasClients && _logs.isNotEmpty && _currentPage < _logs.length) {
      // PageViewは逆順リストで表示しているので、ページインデックスもそれに合わせる
      // _currentPage は逆順リストのインデックスを指すようにする
      // _getDisplayLogs() を使って表示しているので、_currentPage はそのリストのインデックス
       _pageController.jumpToPage(_currentPage);
    } else if (_pageController.hasClients && _logs.isEmpty) {
        _pageController.jumpToPage(0);
    }
  }


  void _onPageChanged(int page) {
    // PageViewのページが変更されたときに呼ばれる
    if (mounted) {
      setState(() {
        _currentPage = page;
      });
    }
  }

  void _navigateToSettings() {
    // 設定画面へ遷移
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    ).then((_) {
      // 設定画面から戻ってきたときにサジェストを再読み込み
      if (mounted) {
        loadSuggestionsFromPrefs(force: true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextTheme textTheme = theme.textTheme;

    final List<LogEntry> displayLogsForCarousel = _getDisplayLogs();
    final bool isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
    final double graphHeightPercentage = 0.25;

    Widget mainContent = SafeArea(
      top: false, // 上部のセーフエリアは TimerDisplay 側で考慮
      bottom: false, // 下部のセーフエリアは FloatingActionButton 周辺で考慮
      child: SingleChildScrollView( // 画面全体をスクロール可能に
        child: Column(
          children: <Widget>[
            TimerDisplay(elapsedTime: _elapsedTime), // 時間表示ウィジェット
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end, // ボタンを右寄せに
                children: [
                  Tooltip(
                    message: '現在のログを保存',
                    child: IconButton(
                      icon: const Icon(Icons.save_alt_outlined, size: 28),
                      // ログがあり、かつサービスが実際に停止している場合のみ有効
                      onPressed: (_logs.isNotEmpty && !_isServiceActuallyRunning) ? _showSaveSessionDialog : null,
                    ),
                  ),
                  Tooltip(
                    message: 'ログを共有 (CSV)',
                    child: IconButton(
                      icon: const Icon(Icons.share_outlined, size: 28),
                      // ログがある場合のみ有効
                      onPressed: _logs.isNotEmpty
                          ? () => shareLogsAsCsvText(context, _logs) // log_exporter.dart の関数
                          : null,
                    ),
                  ),
                ],
              ),
            ),
            // キーボードが表示されていないときだけグラフを表示
            if (!isKeyboardVisible)
              SizedBox(
                height: MediaQuery.of(context).size.height * graphHeightPercentage,
                child: LogColorSummaryChart(
                  logs: _logs, // 現在のログリストを渡す
                ),
              )
            else
              const SizedBox.shrink(), // キーボード表示中はグラフ領域を確保しない
            // ラップログ表示カルーセル
            SizedBox(
              height: carouselHeight,
              child: LogCardCarousel(
                logs: displayLogsForCarousel, // 表示用ログリスト
                onEditLog: (int index) {
                  // ラップ編集ダイアログを表示 (インデックスは表示用リストのもの)
                  _showEditLogDialog(index);
                },
                pageController: _pageController, // ページコントローラ
                onPageChanged: _onPageChanged, // ページ変更コールバック
              ),
            ),
            // ページインジケータ (ログがある場合のみ表示)
            displayLogsForCarousel.isNotEmpty
              ? Padding(
                  padding: const EdgeInsets.only(top: 4.0, bottom: 8.0),
                  child: Text(
                    // 現在のページ / 総ページ数
                    '${_currentPage + 1} / ${displayLogsForCarousel.length}',
                    style: textTheme.bodySmall,
                  ),
                )
              : const SizedBox(height: pageIndicatorHeight), // ログがない場合は高さを確保
            // フローティングアクションボタン分の高さを確保 (画面下部のコンテンツが隠れないように)
            SizedBox(height: fabWidgetHeight + MediaQuery.of(context).padding.bottom + 20),
          ],
        ),
      ),
    );

    return VisibilityDetector(
      key: const Key('stopwatch_screen_clone_visibility_detector'),
      onVisibilityChanged: (visibilityInfo) {
        final visiblePercentage = visibilityInfo.visibleFraction * 100;
        if (mounted && visiblePercentage > 50) { // 画面の半分以上が表示されたら
          print("StopwatchScreenClone: VisibilityDetector - visible");
          loadSuggestionsFromPrefs(force: true); // サジェストを読み込み
          _checkAndSyncServiceState(); // サービス状態を同期
        }
      },
      child: Scaffold(
        body: mainContent,
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked, // FABの位置
        floatingActionButton: StopwatchFloatingActionButton(
          isRunning: _isRunning, // 現在の実行状態
          onStartStopwatch: _handleStartStopwatch, // 開始処理
          onStopStopwatch: _handleStopStopwatch, // 停止処理
          onLapRecord: _handleLapRecord, // ラップ記録処理
          onSettings: _navigateToSettings, // 設定画面へ遷移
        ),
      ),
    );
  }
}
