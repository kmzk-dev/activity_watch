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
import './widgets/log_color_summary_chart.dart';
import './widgets/timer_display.dart'; // ★ 新しいTimerDisplayウィジェットをインポート

class StopwatchScreenWidget extends StatefulWidget {
  const StopwatchScreenWidget({super.key});

  @override
  State<StopwatchScreenWidget> createState() => _StopwatchScreenWidgetState();
}

class _StopwatchScreenWidgetState extends State<StopwatchScreenWidget> with WidgetsBindingObserver {
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  bool _isRunning = false;
  String _elapsedTime = '00:00:00:00'; // 初期値を設定
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
      memo: '', // 初期メモは空
      colorLabelName: colorLabels.keys.first, // デフォルトの色ラベル
    );
    newLog.calculateDuration(); // 忘れずにdurationを計算
    if (mounted) {
      setState(() {
        _logs.add(newLog);
        _timer?.cancel();
        _stopwatch.stop();
        _isRunning = false;
        _elapsedTime = formatDisplayTime(currentElapsedDuration);
        _currentPage = 0; // 停止時はカルーセルを先頭に戻す
      });
      FocusScope.of(context).unfocus();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageController.hasClients && _getDisplayLogs().isNotEmpty) {
          _pageController.animateToPage(
            0, // カルーセルの先頭ページ
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
      memo: '', // 初期メモは空
      colorLabelName: colorLabels.keys.first, // デフォルトの色ラベル
    );
    newLog.calculateDuration(); // 忘れずにdurationを計算
    if (mounted) {
      setState(() {
        _logs.add(newLog);
        _currentPage = 0; // ラップ記録時もカルーセルを先頭に戻す
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageController.hasClients && _getDisplayLogs().isNotEmpty) {
           _pageController.animateToPage(
            0, // カルーセルの先頭ページ
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Future<void> _showEditLogDialog(int pageViewIndex) async {
    if (_logs.isEmpty || pageViewIndex < 0 ) return;

    // pageViewIndex は表示順 (新しいものが0) なので、_logs の実際のインデックスに変換
    final int actualLogIndex = _logs.length - 1 - pageViewIndex;

    if (actualLogIndex < 0 || actualLogIndex >= _logs.length) {
      // print('Error: Invalid actualLogIndex ($actualLogIndex) derived from pageViewIndex ($pageViewIndex).');
      return;
    }

    await loadSuggestionsFromPrefs(force: true); // ダイアログ表示直前に最新のサジェストを読み込む
    if (!mounted) return; // mountedチェックを追加
    final LogEntry currentLog = _logs[actualLogIndex];
    final Map<String, String>? result = await showLogCommentEditDialog(
      context: context,
      initialMemo: currentLog.memo,
      initialColorLabelName: currentLog.colorLabelName,
      commentSuggestions: _commentSuggestions,
      katakanaToHiraganaConverter: katakanaToHiragana,
      availableColorLabels: colorLabels,
    );
    if (result != null && mounted) { // mountedチェックを追加
      final String newMemo = result['memo'] ?? currentLog.memo;
      final String newColorLabel = result['colorLabel'] ?? currentLog.colorLabelName;
      setState(() {
        _logs[actualLogIndex].memo = newMemo;
        _logs[actualLogIndex].colorLabelName = newColorLabel;
        // 必要であれば、ここで _logs リストを再ソートしたり、表示を更新するロジックを追加
      });
    }
    if (!mounted) return; // mountedチェックを追加
    FocusScope.of(context).unfocus(); // ダイアログが閉じた後にフォーカスを外す
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
      initialTitle: '', // 新規保存なので空
      initialComment: '', // 新規保存なので空
      positiveButtonText: '保存',
    );
    if (!mounted) return; // mountedチェックを追加
    FocusScope.of(context).unfocus(); // ダイアログが閉じた後にフォーカスを外す
    if (sessionData != null && sessionData['title'] != null && sessionData['title']!.isNotEmpty) {
      await saveSession(
        context: context,
        title: sessionData['title']!,
        comment: sessionData['comment'],
        logs: _logs,
        savedSessionsKey: _savedSessionsKey,
      );
      // 保存成功のSnackBarはsaveSession関数内で表示される
    }
  }

  // 表示用のログリストを取得する（新しいログが先頭に来るように逆順にする）
  List<LogEntry> _getDisplayLogs() {
    return _logs.reversed.toList();
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final Color stopColor = Colors.redAccent; // 停止ボタンの色
    final Color secondaryColor = Theme.of(context).colorScheme.secondary;
    final Color disabledColor = Colors.grey[400]!; // 無効時のボタン色

    // FABのサイズ定義 (画像イメージに近づけるため調整)
    const double largeFabDimension = 88.0;
    const double smallFabDimension = 64.0;
    const double largeIconSize = 56.0;
    const double smallIconSize = 32.0;

    // FABの画面下部からのパディング
    final double fabBottomPadding = MediaQuery.of(context).padding.bottom + 24.0; // 少し多めに

    // ログ表示エリアの高さ関連
    const double carouselHeight = 160.0; // LogCardItemの高さに合わせる
    // ログ表示エリアがFABと重ならないようにするためのPadding
    // (smallFabDimensionでは小さいのでlargeFabDimensionを基準にするか、固定値を設定)
    final double logAreaBottomPadding = largeFabDimension + fabBottomPadding - MediaQuery.of(context).padding.bottom + 16.0;


    final displayLogsForCarousel = _getDisplayLogs();

    return VisibilityDetector(
      key: const Key('stopwatch_screen_widget_visibility_detector'),
      onVisibilityChanged: (visibilityInfo) {
        final visiblePercentage = visibilityInfo.visibleFraction * 100;
        if (mounted && visiblePercentage > 50) {
          loadSuggestionsFromPrefs(force: true); // 画面表示時にサジェストを強制読み込み
        }
      },
      child: Scaffold(
        body: SafeArea(
          // SafeAreaの上下のpaddingを無効にする (TimerDisplayで画面上部まで表示するため)
          top: false,
          bottom: false, // FABのために下部はSafeAreaを有効にしておくか、個別にpadding調整
          child: Column(
            children: <Widget>[
              // --- ★ タイマー表示部分を新しいウィジェットに置き換え ---
              TimerDisplay(elapsedTime: _elapsedTime),
              // --- アクションボタン (保存・共有) ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 0), // 上下のpaddingを0に
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Tooltip(
                      message: '現在のログを保存',
                      child: IconButton(
                        icon: const Icon(Icons.save_alt_outlined, size: 28), // アイコンとサイズ調整
                        color: Colors.grey[700], // アイコン色調整
                        onPressed: (_logs.isNotEmpty && !_isRunning) ? _showSaveSessionDialog : null,
                      ),
                    ),
                    Tooltip(
                      message: 'ログを共有 (CSV)',
                      child: IconButton(
                        icon: const Icon(Icons.share_outlined, size: 28), // アイコンとサイズ調整
                        color: Colors.grey[700], // アイコン色調整
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
                  // 下方向のPaddingを調整してFABとの重なりを避ける
                  padding: EdgeInsets.only(bottom: logAreaBottomPadding),
                  child: SingleChildScrollView( // Column全体をスクロール可能に
                    child: Column(
                      children: [
                        LogColorSummaryChart(logs: _logs, chartHeight: 80.0),
                        SizedBox(
                          height: carouselHeight,
                          child: LogCardCarousel(
                            logs: displayLogsForCarousel,
                            onEditLog: _showEditLogDialog,
                            pageController: _pageController,
                            onPageChanged: _onPageChanged,
                          ),
                        ),
                        if (displayLogsForCarousel.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0, bottom: 8.0),
                            child: Text(
                              '${_currentPage + 1} / ${displayLogsForCarousel.length}',
                              style: TextStyle(color: Colors.grey[600], fontSize: 12.0),
                            ),
                          ),
                        // ★★★ カルーセル下の意図しない要素 (プレースホルダー) を削除 ★★★
                        // Padding(
                        //   padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                        //   child: Container(
                        //     height: 150,
                        //     width: double.infinity,
                        //     decoration: BoxDecoration(
                        //       color: Colors.grey[200], // ライトグレー
                        //       borderRadius: BorderRadius.circular(15.0),
                        //     ),
                        //     child: Column(
                        //       mainAxisAlignment: MainAxisAlignment.end,
                        //       children: [
                        //         Container(
                        //           width: 60,
                        //           height: 6,
                        //           margin: const EdgeInsets.only(bottom: 10),
                        //           decoration: BoxDecoration(
                        //             color: Colors.grey[400],
                        //             borderRadius: BorderRadius.circular(3),
                        //           ),
                        //         ),
                        //       ],
                        //     ),
                        //   ),
                        // ),
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
          padding: EdgeInsets.only(bottom: fabBottomPadding - (MediaQuery.of(context).padding.bottom)), // padding調整
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.center, // ボタンの垂直方向の位置を中央に
            children: <Widget>[
              // 左ボタン (設定)
              SizedBox(
                width: smallFabDimension,
                height: smallFabDimension,
                child: FloatingActionButton(
                  heroTag: 'settingsFab_new',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const SettingsScreen()),
                    );
                  },
                  backgroundColor: Colors.grey[300], // 背景色を薄いグレーに
                  elevation: 2,
                  shape: const CircleBorder(),
                  child: Icon(Icons.settings_outlined, color: Colors.grey[700], size: smallIconSize), // アイコン変更
                ),
              ),
              // 中央ボタン (開始/停止)
              SizedBox(
                width: largeFabDimension,
                height: largeFabDimension,
                child: FloatingActionButton(
                  heroTag: 'startStopFab_new',
                  onPressed: _isRunning ? _handleStopStopwatch : _handleStartStopwatch,
                  backgroundColor: _isRunning ? stopColor : primaryColor, // 状態に応じて色を変更
                  elevation: 4,
                  shape: const CircleBorder(), // 円形を維持
                  child: Icon(
                    _isRunning ? Icons.stop_rounded : Icons.play_arrow_rounded, // アイコン変更
                    color: Colors.white,
                    size: largeIconSize,
                  ),
                ),
              ),
              // 右ボタン (ラップ記録)
              SizedBox(
                width: smallFabDimension,
                height: smallFabDimension,
                child: FloatingActionButton(
                  heroTag: 'lapRecordFab_new',
                  onPressed: _isRunning ? _handleLapRecord : null,
                  backgroundColor: _isRunning ? secondaryColor : disabledColor, // 状態に応じて色を変更
                  elevation: 2,
                  shape: const CircleBorder(),
                  child: Icon(Icons.flag_outlined, color: Colors.white, size: smallIconSize), // アイコン変更
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
