// lib/screens/stopwatch_screen.dart
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
import '../utils/stopwatch_notifier.dart'; // フォアグラウンドサービス用

import './widgets/log_card_carousel.dart';
import './settings_screen.dart';
import './widgets/log_color_summary_chart.dart';
import './widgets/timer_display.dart';
import './widgets/stopwatch_floating_action_button.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

class StopwatchScreenWidget extends StatefulWidget {
  const StopwatchScreenWidget({super.key});

  @override
  State<StopwatchScreenWidget> createState() => _StopwatchScreenWidgetState();
}

class _StopwatchScreenWidgetState extends State<StopwatchScreenWidget> with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _uiAndNotificationTimer;
  bool _isRunning = false;
  String _elapsedTime = '00:00:00:00';

  final List<LogEntry> _logs = [];
  DateTime? _currentActualSessionStartTime;

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

  int _notificationUpdateCounter = 0;
  static const int _notificationUpdateIntervalTicks = 100;

  late AnimationController _carouselAnimationController;
  late Animation<double> _carouselFadeAnimation;
  late Animation<Offset> _carouselSlideAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkVibrationSupport();

    _carouselAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _carouselFadeAnimation = CurvedAnimation(
      parent: _carouselAnimationController,
      curve: Curves.easeInOut,
    );

    _carouselSlideAnimation = Tween<Offset>(
      begin: const Offset(-1.25, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _carouselAnimationController,
      curve: Curves.easeOutCubic,
      //curve: Curves.easeOutBack,
    ));

    _carouselAnimationController.value = 1.0;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        loadSuggestionsFromPrefs(force: true);
        StopwatchNotifier.stopNotification();
      }
    });
  }

  Future<void> _checkVibrationSupport() async {
    _hasVibrator = await Vibration.hasVibrator();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _carouselAnimationController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    _uiAndNotificationTimer?.cancel();
    _stopwatch.stop();
    if (_isRunning) {
      StopwatchNotifier.stopNotification();
    }
    super.dispose();
  }

  void _onPageChanged(int page) {
    if (mounted) {
      setState(() {
        _currentPage = page;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // print("StopwatchScreen: AppLifecycleState changed to $state");

    if (!_isRunning) {
      if (state == AppLifecycleState.resumed) {
         StopwatchNotifier.stopNotification();
      }
      return;
    }

    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive || state == AppLifecycleState.hidden) {
      // print("StopwatchScreen: App is not resumed. Updating notification.");
      StopwatchNotifier.updateNotification(_elapsedTime);
    } else if (state == AppLifecycleState.resumed) {
      // print("StopwatchScreen: App resumed. Syncing time.");
      if (_currentActualSessionStartTime != null) {
        final Duration resumedElapsedTime = DateTime.now().difference(_currentActualSessionStartTime!);
        if (mounted) {
          setState(() {
            _elapsedTime = formatDisplayTime(resumedElapsedTime);
          });
          StopwatchNotifier.updateNotification(_elapsedTime);
        }
        if (!(_uiAndNotificationTimer?.isActive ?? false)) {
          _startUiAndNotificationTimer();
        }
      }
    }
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

  void _startUiAndNotificationTimer() {
    _uiAndNotificationTimer?.cancel();
    _notificationUpdateCounter = 0;
    _uiAndNotificationTimer = Timer.periodic(const Duration(milliseconds: 10), (timer) {
      if (!_isRunning || _currentActualSessionStartTime == null) {
        timer.cancel();
        // print("StopwatchScreen: UI and Notification Timer stopped.");
        return;
      }
      final newElapsedTime = formatDisplayTime(DateTime.now().difference(_currentActualSessionStartTime!));
      if (mounted) {
        setState(() {
          _elapsedTime = newElapsedTime;
        });
      }
      _notificationUpdateCounter++;
      if (_notificationUpdateCounter >= _notificationUpdateIntervalTicks) {
        StopwatchNotifier.updateNotification(newElapsedTime);
        _notificationUpdateCounter = 0;
      }
    });
    // print("StopwatchScreen: UI and Notification Timer started.");
  }

  void _handleStartStopwatch() {
    _carouselAnimationController.value = 1.0;

    setState(() {
      _logs.clear();
      _stopwatch.reset();
      _currentActualSessionStartTime = DateTime.now();
      _elapsedTime = '00:00:00:00';
      _stopwatch.start();
      _isRunning = true;
      _currentPage = 0;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
    });
    _startUiAndNotificationTimer();
    StopwatchNotifier.startNotification(_elapsedTime);
    // print("StopwatchScreen: Stopwatch started.");
  }

  void _handleStopStopwatch() async {
    if (!_isRunning || _currentActualSessionStartTime == null) return;
    if (_hasVibrator == true) Vibration.vibrate(duration: _stopVibrationDuration);

    _uiAndNotificationTimer?.cancel();
    final Duration finalElapsedDuration = DateTime.now().difference(_currentActualSessionStartTime!);
    _isRunning = false;
    _stopwatch.stop();

    await _carouselAnimationController.reverse();

    setState(() {
      _elapsedTime = formatDisplayTime(finalElapsedDuration);
      final String currentTimeForLog = formatLogTime(finalElapsedDuration);
      final String startTime = _logs.isEmpty ? '00:00:00' : _logs.last.endTime;
      final newLog = LogEntry(
        actualSessionStartTime: _currentActualSessionStartTime!,
        startTime: startTime,
        endTime: currentTimeForLog,
        memo: '',
        colorLabelName: colorLabels.keys.first,
      );
      newLog.calculateDuration();
      _logs.add(newLog);
      _currentPage = 0;
    });

    StopwatchNotifier.stopNotification();
    // print("StopwatchScreen: Stopwatch stopped.");
    FocusScope.of(context).unfocus();

    _carouselAnimationController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController.hasClients && _getDisplayLogs().isNotEmpty) {
        _pageController.animateToPage(0,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  void _handleLapRecord() async {
    if (!_isRunning || _currentActualSessionStartTime == null) return;
    if (_hasVibrator == true) Vibration.vibrate(duration: _lapVibrationDuration);

    await _carouselAnimationController.reverse();

    final Duration currentElapsedDuration = DateTime.now().difference(_currentActualSessionStartTime!);
    final String currentTimeForLog = formatLogTime(currentElapsedDuration);
    final String startTime = _logs.isEmpty ? '00:00:00' : _logs.last.endTime;
    final newLog = LogEntry(
      actualSessionStartTime: _currentActualSessionStartTime!,
      startTime: startTime,
      endTime: currentTimeForLog,
      memo: '',
      colorLabelName: colorLabels.keys.first,
    );
    newLog.calculateDuration();

    setState(() {
      _logs.add(newLog);
      _currentPage = 0;
    });

    _carouselAnimationController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController.hasClients && _getDisplayLogs().isNotEmpty) {
         _pageController.animateToPage(0,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
    // print("StopwatchScreen: Lap recorded, carousel animated.");
  }

  Future<void> _showEditLogDialog(int pageViewIndex) async {
    if (_logs.isEmpty || pageViewIndex < 0 || pageViewIndex >= _logs.length) return;
    final int actualLogIndex = _logs.length - 1 - pageViewIndex;
    if (actualLogIndex < 0 || actualLogIndex >= _logs.length) return;

    await loadSuggestionsFromPrefs(force: true);
    if (!mounted) return;
    final LogEntry currentLog = _logs[actualLogIndex];
    final Map<String, String>? result = await showLogCommentEditDialog(
      context: context,
      initialMemo: currentLog.memo,
      initialColorLabelName: currentLog.colorLabelName,
      commentSuggestions: _commentSuggestions,
      katakanaToHiraganaConverter: katakanaToHiragana,
      availableColorLabels: colorLabels,
    );
    if (result != null && mounted) {
      // 編集時はアニメーションなしで直接データを更新
      setState(() {
        _logs[actualLogIndex].memo = result['memo'] ?? currentLog.memo;
        _logs[actualLogIndex].colorLabelName = result['colorLabel'] ?? currentLog.colorLabelName;
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
        SnackBar(content: Text('保存するログがありません。', style: TextStyle(color: colorScheme.onError)),
                  backgroundColor: colorScheme.error),
      );
      return;
    }
    if (_isRunning) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('まずストップウォッチを停止してください。', style: TextStyle(color: colorScheme.onError)),
                  backgroundColor: colorScheme.error),
      );
      return;
    }
    final Map<String, String>? sessionData = await showSessionDetailsInputDialog(
      context: context, dialogTitle: 'セッションを保存', initialTitle: '',
      initialComment: '', positiveButtonText: '保存',
    );
    if (!mounted) return;
    FocusScope.of(context).unfocus();
    if (sessionData != null && sessionData['title'] != null && sessionData['title']!.isNotEmpty) {
      await saveSession(context: context, title: sessionData['title']!,
                        comment: sessionData['comment'], logs: _logs,
                        savedSessionsKey: _savedSessionsKey);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('「${sessionData['title']}」としてセッションを保存しました。', style: TextStyle(color: colorScheme.onSurface)),
                    backgroundColor: colorScheme.surfaceContainerHighest),
        );
      }
    }
  }

  List<LogEntry> _getDisplayLogs() {
    return _logs.reversed.toList();
  }

  void _navigateToSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    ).then((_){
      if(mounted) loadSuggestionsFromPrefs(force: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextTheme textTheme = theme.textTheme;
    final displayLogsForCarousel = _getDisplayLogs();
    final bool isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
    final double graphHeightPercentage = 0.25;
    final ColorScheme colorScheme = theme.colorScheme;

    Widget mainContent = SafeArea(
      top: false, bottom: false,
      child: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            TimerDisplay(elapsedTime: _elapsedTime),
            const SizedBox(height: 8.0),
            if (!isKeyboardVisible)
              SizedBox(height: MediaQuery.of(context).size.height * graphHeightPercentage,
                        child: LogColorSummaryChart(logs: _logs))
            else const SizedBox.shrink(),
            SlideTransition(
              position: _carouselSlideAnimation,
              child: FadeTransition(
                opacity: _carouselFadeAnimation,
                child: SizedBox(height: carouselHeight,
                          child: LogCardCarousel(logs: displayLogsForCarousel, onEditLog: _showEditLogDialog,
                                               pageController: _pageController, onPageChanged: _onPageChanged)),
              ),
            ),
            displayLogsForCarousel.isNotEmpty
              ? Padding(padding: const EdgeInsets.only(top: 4.0, bottom: 8.0),
                          child: Text('${_currentPage + 1} / ${displayLogsForCarousel.length}', style: textTheme.bodySmall))
              : const SizedBox(height: pageIndicatorHeight),
            SizedBox(height: fabWidgetHeight + MediaQuery.of(context).padding.bottom + 20),
          ],
        ),
      ),
    );

    return PopScope(
      canPop: !_isRunning,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) {
          // print("StopwatchScreen: Pop allowed and occurred. Result: $result");
          StopwatchNotifier.stopNotification();
          return;
        }
        if (_isRunning) {
          // print("StopwatchScreen: Pop prevented while running, minimizing app.");
          FlutterForegroundTask.minimizeApp(); // 必要に応じてインポート
          StopwatchNotifier.startNotification(_elapsedTime);
        }
      },
      child: VisibilityDetector(
        key: const Key('stopwatch_screen_widget_visibility_detector'),
        onVisibilityChanged: (visibilityInfo) {
          final visiblePercentage = visibilityInfo.visibleFraction * 100;
          if (mounted && visiblePercentage > 50) {
            loadSuggestionsFromPrefs(force: true);
            if (_isRunning) StopwatchNotifier.startNotification(_elapsedTime);
          } else if (mounted && visiblePercentage < 10 && _isRunning) {
            StopwatchNotifier.startNotification(_elapsedTime);
          }
        },
        child: Scaffold(
          appBar: AppBar(
              backgroundColor: colorScheme.surface, // AppBarの背景色を固定
              elevation: 0, // 通常時の影を消す場合 (任意)
              scrolledUnderElevation: 0.0, // スクロール時の影 (色の変化の原因の一つ) をなくす
              surfaceTintColor: colorScheme.surface,
              actions: <Widget>[
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                tooltip: '設定',
                onPressed: _navigateToSettings,
              ),
              IconButton(
                icon: const Icon(Icons.share_outlined),
                tooltip: 'シェア',
                onPressed: _logs.isNotEmpty ? () => shareLogsAsCsvText(context, _logs) : null, 
              )
            ],
          ),
          body: mainContent,
          floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
          floatingActionButton: StopwatchFloatingActionButton(
            isRunning: _isRunning, onStartStopwatch: _handleStartStopwatch,
            onStopStopwatch: _handleStopStopwatch, onLapRecord: _handleLapRecord,
            onSaveSession: _showSaveSessionDialog,
            canSaveSession: _logs.isNotEmpty && !_isRunning, 
          ),
        ),
      ),
    );
  }
}