// lib/screens/stopwatch_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:vibration/vibration.dart'; // ★ Vibrationプラグインをインポート

import '../theme/color_constants.dart';
import '../models/log_entry.dart';

import '../utils/time_formatters.dart';
import '../utils/log_exporter.dart';
import '../utils/dialog_utils.dart';
import '../utils/session_dialog_utils.dart';
import '../utils/session_storage.dart';
import '../utils/string_utils.dart';

import './widgets/log_card_carousel.dart';
import './settings_screen.dart';
import './widgets/log_color_summary_chart.dart';
import './widgets/timer_display.dart';
import './widgets/stopwatch_floating_action_button.dart'; // FABウィジェット

class StopwatchScreenWidget extends StatefulWidget {
  const StopwatchScreenWidget({super.key});

  @override
  State<StopwatchScreenWidget> createState() => _StopwatchScreenWidgetState();
}

class _StopwatchScreenWidgetState extends State<StopwatchScreenWidget> with WidgetsBindingObserver {
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  bool _isRunning = false;
  String _elapsedTime = '00:00:00:00';
  final TextEditingController _sessionTitleController = TextEditingController();
  final TextEditingController _sessionCommentController = TextEditingController();

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

  bool _showLapFlash = false;
  Timer? _lapFlashTimer;

  // --- バイブレーションサポート状況を保持する変数 ---
  bool? _hasVibrator;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkVibrationSupport(); // ★ バイブレーションサポート状況を確認
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        loadSuggestionsFromPrefs(force: true);
      }
    });
  }

  // ★ バイブレーションがサポートされているか確認するメソッド
  Future<void> _checkVibrationSupport() async {
    bool? hasVibrator = await Vibration.hasVibrator();
    if (mounted) {
      setState(() {
        _hasVibrator = hasVibrator;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    _timer?.cancel();
    _lapFlashTimer?.cancel();
    _stopwatch.stop();
    _sessionTitleController.dispose();
    _sessionCommentController.dispose();
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
    if (!_isRunning) return;

    if (state == AppLifecycleState.paused) {
      _timer?.cancel();
    } else if (state == AppLifecycleState.resumed) {
      if (_currentActualSessionStartTime != null) {
        final Duration resumedElapsedTime = DateTime.now().difference(_currentActualSessionStartTime!);
        if (mounted) {
          setState(() {
            _elapsedTime = formatDisplayTime(resumedElapsedTime);
          });
        }
        _startTimer();
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

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 10), (timer) {
      if (!_isRunning || _currentActualSessionStartTime == null) {
        timer.cancel();
        return;
      }
      if (mounted) {
        setState(() {
          _elapsedTime = formatDisplayTime(DateTime.now().difference(_currentActualSessionStartTime!));
        });
      }
    });
  }

  void _handleStartStopwatch() {
    setState(() {
      _logs.clear();
      _stopwatch.reset();
      _currentActualSessionStartTime = DateTime.now();
      _elapsedTime = '00:00:00:00';
      _stopwatch.start();
      _isRunning = true;
      _startTimer();
      _currentPage = 0;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
    });
  }

  void _handleStopStopwatch() {
    if (!_isRunning || _currentActualSessionStartTime == null) return;
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
    if (mounted) {
      setState(() {
        _logs.add(newLog);
        _timer?.cancel();
        _stopwatch.stop();
        _isRunning = false;
        _elapsedTime = formatDisplayTime(currentElapsedDuration);
        _currentPage = 0;
      });
      FocusScope.of(context).unfocus();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageController.hasClients && _getDisplayLogs().isNotEmpty) {
          _pageController.animateToPage(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _handleLapRecord() async { // ★ asyncに変更
    if (!_isRunning || _currentActualSessionStartTime == null) return;

    // --- 画面フラッシュフィードバック開始 ---
    _lapFlashTimer?.cancel();
    if (mounted) {
      setState(() {
        _showLapFlash = true;
      });
    }
    _lapFlashTimer = Timer(const Duration(milliseconds: 650), () {
      if (mounted) {
        setState(() {
          _showLapFlash = false;
        });
      }
    });

    // --- バイブレーション実行 ---
    if (_hasVibrator == true) { // nullチェックとtrueチェック
      Vibration.vibrate(duration: 100); // 100ミリ秒のバイブレーション
    }
    // --- バイブレーションここまで ---

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

    if (mounted) {
      setState(() {
        _logs.add(newLog);
        _currentPage = 0;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageController.hasClients && _getDisplayLogs().isNotEmpty) {
           _pageController.animateToPage(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Future<void> _showEditLogDialog(int pageViewIndex) async {
    if (_logs.isEmpty || pageViewIndex < 0 ) return;
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
      final String newMemo = result['memo'] ?? currentLog.memo;
      final String newColorLabel = result['colorLabel'] ?? currentLog.colorLabelName;
      setState(() {
        _logs[actualLogIndex].memo = newMemo;
        _logs[actualLogIndex].colorLabelName = newColorLabel;
      });
    }
    if (!mounted) return;
    FocusScope.of(context).unfocus();
  }

  Future<void> _showSaveSessionDialog() async {
    if (_logs.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('保存するログがありません。')),
      );
      return;
    }
    if (_isRunning) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('まずストップウォッチを停止してください。')),
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
      await saveSession(
        context: context,
        title: sessionData['title']!,
        comment: sessionData['comment'],
        logs: _logs,
        savedSessionsKey: _savedSessionsKey,
      );
    }
  }

  List<LogEntry> _getDisplayLogs() {
    return _logs.reversed.toList();
  }

  void _navigateToSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final Color stopColor = Colors.redAccent;
    final Color secondaryColor = Theme.of(context).colorScheme.secondary;
    final Color disabledColor = Colors.grey[400]!;

    final displayLogsForCarousel = _getDisplayLogs();
    final bool isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
    final double graphHeightPercentage = 0.25;

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
                      color: Colors.grey[700],
                      onPressed: (_logs.isNotEmpty && !_isRunning) ? _showSaveSessionDialog : null,
                    ),
                  ),
                  Tooltip(
                    message: 'ログを共有 (CSV)',
                    child: IconButton(
                      icon: const Icon(Icons.share_outlined, size: 28),
                      color: Colors.grey[700],
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
                onEditLog: _showEditLogDialog,
                pageController: _pageController,
                onPageChanged: _onPageChanged,
              ),
            ),
            displayLogsForCarousel.isNotEmpty
              ? Padding(
                  padding: const EdgeInsets.only(top: 4.0, bottom: 8.0),
                  child: Text(
                    '${_currentPage + 1} / ${displayLogsForCarousel.length}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12.0),
                  ),
                )
              : const SizedBox(height: pageIndicatorHeight),
            SizedBox(height: fabWidgetHeight + MediaQuery.of(context).padding.bottom + 20),
          ],
        ),
      ),
    );

    return VisibilityDetector(
      key: const Key('stopwatch_screen_widget_visibility_detector'),
      onVisibilityChanged: (visibilityInfo) {
        final visiblePercentage = visibilityInfo.visibleFraction * 100;
        if (mounted && visiblePercentage > 50) {
          loadSuggestionsFromPrefs(force: true);
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            mainContent,
            if (_showLapFlash)
              Positioned.fill(
                child: Container(
                  color: Colors.white.withOpacity(0.3),
                ),
              ),
          ],
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        floatingActionButton: StopwatchFloatingActionButton(
          isRunning: _isRunning,
          onStartStopwatch: _handleStartStopwatch,
          onStopStopwatch: _handleStopStopwatch,
          onLapRecord: _handleLapRecord,
          onSettings: _navigateToSettings,
          primaryColor: primaryColor,
          stopColor: stopColor,
          secondaryColor: secondaryColor,
          disabledColor: disabledColor,
        ),
      ),
    );
  }
}
