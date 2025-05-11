// lib/screens/stopwatch_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

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
import './widgets/log_color_summary_chart.dart'; // LogColorSummaryChartをインポート

class StopwatchScreenWidget extends StatefulWidget {
  const StopwatchScreenWidget({super.key});

  @override
  State<StopwatchScreenWidget> createState() => _StopwatchScreenWidgetState();
}

// WidgetsBindingObserver をミックスイン
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        loadSuggestionsFromPrefs(force: true);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    _timer?.cancel();
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

  void _handleLapRecord() {
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

    if (actualLogIndex < 0 || actualLogIndex >= _logs.length) {
      print('Error: Invalid actualLogIndex ($actualLogIndex) derived from pageViewIndex ($pageViewIndex).');
      return;
    }

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

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final Color stopColor = Colors.redAccent;
    final Color secondaryColor = Theme.of(context).colorScheme.secondary;
    final Color disabledColor = Colors.grey[400]!;
    const double fabDimension = 112.0 * 0.9;
    const double iconSize = 72.0 * 0.9;
    const double smallFabDimension = fabDimension / 2;
    const double smallIconSize = iconSize / 2;
    final double fabBottomPadding = MediaQuery.of(context).padding.bottom + 16.0;

    const double carouselHeight = 160.0;
    // logAreaBottomPaddingはExpandedの親のPaddingなので、Expandedが使える高さを制御する
    // この値を小さくすると、Expandedが使える高さが増える
    final double logAreaBottomPadding = fabDimension + 16.0; // 少し減らしてみる

    final displayLogsForCarousel = _getDisplayLogs();

    return VisibilityDetector(
      key: const Key('stopwatch_screen_widget_visibility_detector'),
      onVisibilityChanged: (visibilityInfo) {
        final visiblePercentage = visibilityInfo.visibleFraction * 100;
        if (mounted && visiblePercentage > 50) {
          loadSuggestionsFromPrefs(force: true);
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(top: 48.0, bottom: 32.0),
                child: Text(
                  _elapsedTime,
                  style: const TextStyle(
                    fontSize: 56.0,
                    fontWeight: FontWeight.bold,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Tooltip(
                      message: '現在のログを保存',
                      child: IconButton(
                        icon: const Icon(Icons.save),
                        onPressed: (_logs.isNotEmpty && !_isRunning) ? _showSaveSessionDialog : null,
                      ),
                    ),
                    Tooltip(
                      message: 'ログを共有 (CSV)',
                      child: IconButton(
                        icon: const Icon(Icons.share),
                        onPressed: _logs.isNotEmpty
                            ? () => shareLogsAsCsvText(context, _logs)
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
              // --- ログ表示エリア ---
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: logAreaBottomPadding), 
                  child: SingleChildScrollView( // ColumnをSingleChildScrollViewでラップ
                    child: Column(
                      // mainAxisSize: MainAxisSize.min, // SingleChildScrollViewの子なのでminでも良いが、Expanded内のためmaxでも可
                      children: [
                        LogColorSummaryChart(logs: _logs, chartHeight: 80.0), // chartHeightを少し小さくしてみる
                        SizedBox(
                          height: carouselHeight, // カルーセルの高さは維持
                          child: LogCardCarousel(
                            logs: displayLogsForCarousel,
                            onEditLog: _showEditLogDialog,
                            pageController: _pageController,
                            onPageChanged: _onPageChanged,
                          ),
                        ),
                        if (displayLogsForCarousel.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0, bottom: 8.0), // ページ番号の下にも少し余白
                            child: Text(
                              '${_currentPage + 1} / ${displayLogsForCarousel.length}',
                              style: TextStyle(color: Colors.grey[600], fontSize: 12.0),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        floatingActionButton: Padding(
          padding: EdgeInsets.only(bottom: fabBottomPadding),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              SizedBox(
                width: smallFabDimension,
                height: smallFabDimension,
                child: FloatingActionButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const SettingsScreen()),
                    );
                  },
                  tooltip: '設定',
                  heroTag: 'settingsFab',
                  backgroundColor: Colors.grey[700],
                  foregroundColor: Colors.white,
                  shape: const CircleBorder(),
                  child: const Icon(Icons.settings, size: smallIconSize),
                ),
              ),
              SizedBox(
                width: fabDimension,
                height: fabDimension,
                child: FloatingActionButton(
                  onPressed: _isRunning ? _handleStopStopwatch : _handleStartStopwatch,
                  tooltip: _isRunning ? '停止' : '開始',
                  heroTag: 'startStopFab',
                  backgroundColor: _isRunning ? stopColor : primaryColor,
                  foregroundColor: Colors.white,
                  shape: _isRunning ? null : const CircleBorder(),
                  child: Icon(_isRunning ? Icons.stop : Icons.play_arrow, size: iconSize),
                ),
              ),
              SizedBox(
                width: smallFabDimension,
                height: smallFabDimension,
                child: FloatingActionButton(
                  onPressed: _isRunning ? _handleLapRecord : null,
                  tooltip: 'ラップ記録',
                  heroTag: 'lapRecordFab',
                  backgroundColor: !_isRunning ? disabledColor : secondaryColor,
                  foregroundColor: Colors.white,
                  shape: const CircleBorder(),
                  child: const Icon(Icons.format_list_bulleted_add, size: smallIconSize),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
