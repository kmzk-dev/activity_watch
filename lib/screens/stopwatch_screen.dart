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

import './widgets/custom_app_bar.dart';
import './widgets/log_table.dart';

class StopwatchScreenWidget extends StatefulWidget {
  const StopwatchScreenWidget({super.key});

  @override
  State<StopwatchScreenWidget> createState() => _StopwatchScreenWidgetState();
}

// WidgetsBindingObserver をミックスイン
class _StopwatchScreenWidgetState extends State<StopwatchScreenWidget> with WidgetsBindingObserver {
  final Stopwatch _stopwatch = Stopwatch(); // Stopwatchオブジェクトは主に状態管理（isRunning）に使用
  Timer? _timer;
  bool _isRunning = false;
  String _elapsedTime = '00:00:00:00';
  final TextEditingController _sessionTitleController = TextEditingController();
  final TextEditingController _sessionCommentController = TextEditingController();

  final List<LogEntry> _logs = [];
  DateTime? _currentActualSessionStartTime; // 計測の絶対開始時刻

  List<String> _commentSuggestions = [];
  static const String _suggestionsKey = 'comment_suggestions';
  static const String _savedSessionsKey = 'saved_log_sessions';
  DateTime? _lastSuggestionsLoadTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // オブザーバーを登録
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        loadSuggestionsFromPrefs(force: true);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // オブザーバーを解除
    _timer?.cancel();
    _stopwatch.stop();
    _sessionTitleController.dispose();
    _sessionCommentController.dispose();
    super.dispose();
  }

  // アプリのライフサイクルが変更されたときに呼ばれる
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (!_isRunning) return; // ストップウォッチが実行中でなければ何もしない

    if (state == AppLifecycleState.paused) {
      // アプリがバックグラウンドに移行したらタイマーをキャンセル
      _timer?.cancel();
    } else if (state == AppLifecycleState.resumed) {
      // アプリがフォアグラウンドに戻ったら、経過時間を再計算しタイマーを再開
      if (_currentActualSessionStartTime != null) {
        final Duration resumedElapsedTime = DateTime.now().difference(_currentActualSessionStartTime!);
        if (mounted) {
          setState(() {
            _elapsedTime = formatDisplayTime(resumedElapsedTime);
          });
        }
        _startTimer(); // タイマーを再開
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

  // タイマーを開始または再開する共通メソッド
  void _startTimer() {
    _timer?.cancel(); // 既存のタイマーがあればキャンセル
    _timer = Timer.periodic(const Duration(milliseconds: 10), (timer) {
      if (!_isRunning || _currentActualSessionStartTime == null) {
        timer.cancel();
        return;
      }
      if (mounted) {
        setState(() {
          // 絶対開始時刻からの差分で経過時間を更新
          _elapsedTime = formatDisplayTime(DateTime.now().difference(_currentActualSessionStartTime!));
        });
      }
    });
  }

  void _handleFABPress() async {
    if (_isRunning) { // ラップ記録または停止
      await loadSuggestionsFromPrefs(force: true);
      if (!mounted) return;

      // 現在の経過時間を絶対開始時刻からの差分で計算
      final Duration currentElapsedDuration = _currentActualSessionStartTime != null
          ? DateTime.now().difference(_currentActualSessionStartTime!)
          : Duration.zero;
      final String currentTimeForLog = formatLogTime(currentElapsedDuration);

      final Map<String, dynamic>? result = await showAddNewLogDialog(
        context: context,
        timeForLogDialog: currentTimeForLog,
        commentSuggestions: _commentSuggestions,
        katakanaToHiraganaConverter: katakanaToHiragana,
        availableColorLabels: colorLabels,
        initialSelectedColorLabel: colorLabels.keys.first,
      );

      if (result != null && mounted) {
        final String memo = result['memo'] as String;
        final String colorLabel = result['colorLabel'] as String;
        final String action = result['action'] as String;

        final String startTime = _logs.isEmpty ? '00:00:00' : _logs.last.endTime;
        final newLog = LogEntry(
          actualSessionStartTime: _currentActualSessionStartTime!,
          startTime: startTime,
          endTime: currentTimeForLog, // 正確な終了時刻
          memo: memo,
          colorLabelName: colorLabel,
        );
        newLog.calculateDuration(); // LogEntry内部のdurationもこれで計算される
        setState(() {
          _logs.add(newLog);
        });

        if (action == 'stop') {
          _stopCounter();
        }
      }
      if (mounted) {
        FocusScope.of(context).unfocus();
      }
    } else { // 計測開始
      setState(() {
        _logs.clear();
        _stopwatch.reset(); // Stopwatchはリセット
        _currentActualSessionStartTime = DateTime.now(); // 絶対開始時刻を記録
        _elapsedTime = '00:00:00:00';

        _stopwatch.start(); // Stopwatchを開始（主にisRunning状態の管理のため）
        _isRunning = true;
        _startTimer(); // カスタムタイマーを開始
      });
    }
  }

  void _stopCounter() {
    if (mounted) {
      setState(() {
        if (_isRunning) {
          _timer?.cancel();
          _stopwatch.stop(); // Stopwatchを停止
          _isRunning = false;
          // 最終的な経過時間を絶対開始時刻からの差分で確定
          if (_currentActualSessionStartTime != null) {
            _elapsedTime = formatDisplayTime(DateTime.now().difference(_currentActualSessionStartTime!));
          }
        }
      });
    }
  }

  Future<void> _showEditLogDialog(int logIndex) async {
    await loadSuggestionsFromPrefs(force: true);
    if (!mounted) return;

    final LogEntry currentLog = _logs[logIndex];

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
        _logs[logIndex].memo = newMemo;
        _logs[logIndex].colorLabelName = newColorLabel;
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

  Widget _buildFloatingActionButton() {
    if (!_isRunning) {
      return FloatingActionButton(
        onPressed: _handleFABPress,
        tooltip: '開始',
        heroTag: 'startFab',
        child: const Icon(Icons.play_arrow, size: 36.0),
      );
    } else {
      return FloatingActionButton(
        onPressed: _handleFABPress,
        tooltip: 'ラップ記録',
        heroTag: 'lapRecordFab',
        child: const Icon(Icons.format_list_bulleted_add, size: 36.0),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: const Key('stopwatch_screen_widget_visibility_detector'),
      onVisibilityChanged: (visibilityInfo) {
        final visiblePercentage = visibilityInfo.visibleFraction * 100;
        if (mounted && visiblePercentage > 50) {
          loadSuggestionsFromPrefs(force: true);
        }
      },
      child: Scaffold(
        appBar: const CustomAppBar(),
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
              Expanded(
                child: LogTable(
                  logs: _logs,
                  onEditLog: _showEditLogDialog,
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: SizedBox(
          width: 70.0,
          height: 70.0,
          child: _buildFloatingActionButton(),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      ),
    );
  }
}
