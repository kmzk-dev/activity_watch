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
            _isRunning = false;
          }
        });
      }

      if (data.containsKey('lapLogsUpdate')) {
        final List<dynamic>? lapMapListRaw = data['lapLogsUpdate'] as List<dynamic>?;
        if (lapMapListRaw != null) {
          setState(() {
            _logs = convertBackgroundTaskLapListToLogEntries(lapMapListRaw);
            _updateCurrentPageAndLogEntryBasedOnLogs();
            print('StopwatchScreenClone: Received lapLogsUpdate and updated _logs. Count: ${_logs.length}');
          });
        }
      }

      if (data.containsKey('serviceStopped') && data['serviceStopped'] == true) {
        print("StopwatchScreenClone: Received 'serviceStopped' signal from TaskHandler.");
        setState(() {
          _isServiceActuallyRunning = false;
          _isRunning = false; // サービスが止まったらUI上の実行状態もfalseに
          // 経過時間はMyTaskHandlerから最終的なものが送られてくる想定
          if (data.containsKey('formattedTime')) {
             _elapsedTime = data['formattedTime'] as String;
          }
          // ラップログは 'lapLogsUpdate' で最終状態が送られてくるはず
        });
      }
    } else if (data is String && data == "onNotificationPressed") {
      print("StopwatchScreenClone: Notification was pressed, received in UI.");
    }
  }

  Future<void> _requestPermissions() async {
    if (await FlutterForegroundTask.checkNotificationPermission() != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }
  }

  void _initForegroundTaskService() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'stopwatch_foreground_service_clone',
        channelName: 'Stopwatch Foreground Service (Clone)',
        channelDescription: 'Stopwatch (Clone) is running in the background.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        onlyAlertOnce: true,
        enableVibration: false,
        playSound: false,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(1000),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: false,
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
        _isRunning = false;
        _elapsedTime = '00:00:00:00';
      } else {
         _isRunning = true;
      }
    });

    if (isActuallyRunningNow) {
      print('StopwatchScreenClone: Service is running, requesting full state from MyTaskHandler.');
      FlutterForegroundTask.sendDataToTask({'action': 'requestFullState'});
    }
  }

  Future<void> _handleStartStopwatch() async {
    if (_isServiceActuallyRunning) {
      await _stopForegroundService(); // 停止時に最終ラップを記録するようMyTaskHandlerを修正
      await Future.delayed(const Duration(milliseconds: 200));
    }
    _logs.clear();

    setState(() {
      _isRunning = true;
      _elapsedTime = '00:00:00:00';
      _currentPage = 0;
    });
    if (_pageController.hasClients) {
      _pageController.jumpToPage(0);
    }
    await _startForegroundService();
  }

  Future<void> _startForegroundService() async {
    if (await FlutterForegroundTask.isRunningService) {
      print("StopwatchScreenClone: Service is already running. Not starting again.");
      if(mounted && !_isServiceActuallyRunning) {
        setState(() {
          _isServiceActuallyRunning = true;
          if(!_isRunning) _isRunning = true;
        });
      }
      return;
    }
    try {
      await FlutterForegroundTask.startService(
        notificationTitle: 'ストップウォッチ計測中',
        notificationText: _elapsedTime,
        callback: startCallback,
      );
      print('StopwatchScreenClone: Foreground service start initiated.');
    } catch (e) {
      print('StopwatchScreenClone: Failed to start foreground service: $e');
      if (mounted) {
        setState(() {
          _isServiceActuallyRunning = false;
          _isRunning = false;
        });
      }
    }
  }

  Future<void> _handleStopStopwatch() async {
    if (!_isRunning && !_isServiceActuallyRunning) {
      print("StopwatchScreenClone: Stopwatch already stopped or service not running.");
      return;
    }
    if (_hasVibrator == true) {
      Vibration.vibrate(duration: _stopVibrationDuration);
    }
    setState(() {
      _isRunning = false; // UIを即座に停止表示に
    });
    // MyTaskHandler に最終ラップ記録とサービス停止を指示
    print("StopwatchScreenClone: Sending 'stopAndRecordFinalLap' action to TaskHandler.");
    FlutterForegroundTask.sendDataToTask({'action': 'stopAndRecordFinalLap'});
    // 実際のサービス停止とUI更新は MyTaskHandler からの通知で行う
  }

  Future<void> _stopForegroundService() async { // このメソッドは直接呼ばれなくなるかも
    if (!await FlutterForegroundTask.isRunningService) {
      print("StopwatchScreenClone: Service is not running. Not stopping (from _stopForegroundService).");
      if (mounted && _isServiceActuallyRunning) {
        setState(() {
          _isServiceActuallyRunning = false;
          if (_isRunning) _isRunning = false;
        });
      }
      return;
    }
    try {
      // 通常は 'stopAndRecordFinalLap' を経由して MyTaskHandler 側で stopService が呼ばれる
      await FlutterForegroundTask.stopService();
      print('StopwatchScreenClone: Foreground service stop initiated (from _stopForegroundService).');
    } catch (e) {
      print('StopwatchScreenClone: Failed to stop foreground service (from _stopForegroundService): $e');
      if (mounted) {
        setState(() {
          _isServiceActuallyRunning = false;
          _isRunning = false;
        });
      }
    }
  }

  void _handleLapRecord() async {
    if (!_isRunning || !_isServiceActuallyRunning) {
      print("StopwatchScreenClone: Cannot record lap, stopwatch not running or service not running.");
      return;
    }
    if (_hasVibrator == true) {
      Vibration.vibrate(duration: _lapVibrationDuration);
    }
    print("StopwatchScreenClone: Sending 'recordLap' action to TaskHandler.");
    FlutterForegroundTask.sendDataToTask({'action': 'recordLap'});
  }

  Future<void> _showEditLogDialog(int pageViewIndex) async {
    // ===>>> 修正: 停止後も編集可能にするため、実行状態のチェックを削除 <<<===
    // if (!_isRunning && !_isServiceActuallyRunning) {
    //   print("StopwatchScreenClone: Cannot edit log, stopwatch is not running.");
    //   if (mounted) {
    //     ScaffoldMessenger.of(context).showSnackBar(
    //       const SnackBar(
    //         content: Text('計測中はログを編集できません。'), // メッセージも変更検討
    //         duration: Duration(seconds: 2),
    //       ),
    //     );
    //   }
    //   return;
    // }
    if (_logs.isEmpty) { // ログがない場合は編集できない
        print("StopwatchScreenClone: No logs to edit.");
        return;
    }

    final List<LogEntry> currentDisplayLogs = _getDisplayLogs();
    if (pageViewIndex < 0 || pageViewIndex >= currentDisplayLogs.length) {
      print("StopwatchScreenClone: Invalid pageViewIndex for editing: $pageViewIndex. Display logs count: ${currentDisplayLogs.length}");
      return;
    }
    final LogEntry logToEdit = currentDisplayLogs[pageViewIndex];

    await loadSuggestionsFromPrefs(force: true);
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

      print('StopwatchScreenClone: Sending editLap command to MyTaskHandler.');
      FlutterForegroundTask.sendDataToTask({
        'action': 'editLap',
        'originalStartTimeFormatted': logToEdit.startTime,
        'originalEndTimeFormatted': logToEdit.endTime,
        'updatedMemo': newMemo,
        'updatedColorLabelName': newColorLabel,
      });
    }
    if (!mounted) return;
    FocusScope.of(context).unfocus();
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
    if (_isServiceActuallyRunning) { // サービス実行中は保存不可
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
      initialTitle: '',
      initialComment: '',
      positiveButtonText: '保存',
    );

    if (!mounted) return;
    FocusScope.of(context).unfocus();

    if (sessionData != null && sessionData['title'] != null && sessionData['title']!.isNotEmpty) {
      print("StopwatchScreenClone: Save session requested. Title: ${sessionData['title']}. Logs count: ${_logs.length}");
      await saveSession(
        context: context,
        title: sessionData['title']!,
        comment: sessionData['comment'],
        logs: _logs,
        savedSessionsKey: _savedSessionsKey,
      );
    }
  }

  Future<void> _checkVibrationSupport() async {
    _hasVibrator = await Vibration.hasVibrator();
  }

  Future<void> loadSuggestionsFromPrefs({bool force = false}) async {
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
    return _logs.reversed.toList();
  }

  void _updateCurrentPageAndLogEntryBasedOnLogs() {
    if (!mounted) return;
    setState(() {
      if (_logs.isEmpty) {
        _currentPage = 0;
      } else {
        if (_currentPage >= _logs.length) {
          _currentPage = _logs.length - 1;
        }
        if (_currentPage < 0) {
           _currentPage = 0;
        }
      }
    });
  }

  void _onPageChanged(int page) {
    if (mounted) {
      setState(() {
        _currentPage = page;
      });
    }
  }

  void _navigateToSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    ).then((_) {
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

    // ===>>> 修正: 編集ボタンの有効/無効状態の制御を削除または変更 <<<===
    // final bool canEditLogs = _isRunning || _isServiceActuallyRunning; // 古い制御
    // 停止後も編集可能にするため、単純にログが存在するかどうかで制御する、など
    final bool canEditLogs = _logs.isNotEmpty;


    Widget mainContent = SafeArea(
      top: false,
      bottom: false,
      child: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            TimerDisplay(elapsedTime: _elapsedTime),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Tooltip(
                    message: '現在のログを保存',
                    child: IconButton(
                      icon: const Icon(Icons.save_alt_outlined, size: 28),
                      onPressed: (_logs.isNotEmpty && !_isServiceActuallyRunning) ? _showSaveSessionDialog : null,
                    ),
                  ),
                  Tooltip(
                    message: 'ログを共有 (CSV)',
                    child: IconButton(
                      icon: const Icon(Icons.share_outlined, size: 28),
                      onPressed: _logs.isNotEmpty
                          ? () => shareLogsAsCsvText(context, _logs)
                          : null,
                    ),
                  ),
                ],
              ),
            ),
            if (!isKeyboardVisible)
              SizedBox(
                height: MediaQuery.of(context).size.height * graphHeightPercentage,
                child: LogColorSummaryChart(
                  logs: _logs,
                ),
              )
            else
              const SizedBox.shrink(),
            SizedBox(
              height: carouselHeight,
              child: LogCardCarousel(
                logs: displayLogsForCarousel,
                // ===>>> 修正: canEditLogs の条件を変更、または常に編集ダイアログを呼び出す <<<===
                onEditLog: (int index) { // canEditLogs の条件を削除し、常にダイアログを試みる
                  if (_logs.isEmpty) return; // ガード節は _showEditLogDialog 内にもあるが、ここでも良い
                  _showEditLogDialog(index);
                },
                pageController: _pageController,
                onPageChanged: _onPageChanged,
              ),
            ),
            displayLogsForCarousel.isNotEmpty
              ? Padding(
                  padding: const EdgeInsets.only(top: 4.0, bottom: 8.0),
                  child: Text(
                    '${_currentPage + 1} / ${displayLogsForCarousel.length}',
                    style: textTheme.bodySmall,
                  ),
                )
              : const SizedBox(height: pageIndicatorHeight),
            SizedBox(height: fabWidgetHeight + MediaQuery.of(context).padding.bottom + 20),
          ],
        ),
      ),
    );

    return VisibilityDetector(
      key: const Key('stopwatch_screen_clone_visibility_detector'),
      onVisibilityChanged: (visibilityInfo) {
        final visiblePercentage = visibilityInfo.visibleFraction * 100;
        if (mounted && visiblePercentage > 50) {
          print("StopwatchScreenClone: VisibilityDetector - visible");
          loadSuggestionsFromPrefs(force: true);
          _checkAndSyncServiceState();
        }
      },
      child: Scaffold(
        body: mainContent,
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        floatingActionButton: StopwatchFloatingActionButton(
          isRunning: _isRunning,
          onStartStopwatch: _handleStartStopwatch,
          onStopStopwatch: _handleStopStopwatch,
          onLapRecord: _handleLapRecord,
          onSettings: _navigateToSettings,
        ),
      ),
    );
  }
}
