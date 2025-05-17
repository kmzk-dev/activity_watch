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

class _StopwatchScreenWidgetState extends State<StopwatchScreenWidget> with WidgetsBindingObserver, TickerProviderStateMixin { // TickerProviderStateMixin を追加
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

  // 長押し停止機能のための状態変数
  // Timer? _longPressTimer; // AnimationControllerで代替するため削除
  late AnimationController _longPressProgressController; // 長押しプログレス用
  bool _isStoppingWithLongPress = false;
  static const Duration _longPressDuration = Duration(milliseconds: 500);
  bool _ignoreTapAfterLongPressStop = false;


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
    ));
    _carouselAnimationController.value = 1.0;

    // 長押しプログレス用 AnimationController の初期化
    _longPressProgressController = AnimationController(
      vsync: this, // TickerProviderStateMixin が必要
      duration: _longPressDuration,
    );

    _longPressProgressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // アニメーション完了時 (2秒経過時)
        if (_isStoppingWithLongPress && _isRunning && mounted) {
          _handleStopStopwatch(); // 実際の停止処理を実行
          if (mounted) {
            setState(() {
              _ignoreTapAfterLongPressStop = true; // 長押しで停止したので、次のタップを無視
              _isStoppingWithLongPress = false; // 長押し状態を解除
            });
          }
        } else {
           // アニメーションは完了したが、何らかの理由で停止処理を実行しない場合
           if(mounted){
            setState(() {
              _isStoppingWithLongPress = false;
            });
           }
        }
        _longPressProgressController.reset(); // アニメーションをリセット
      } else if (status == AnimationStatus.dismissed) {
        // アニメーションが途中でキャンセルされたりリセットされた場合
        if (mounted) {
          setState(() {
            _isStoppingWithLongPress = false;
          });
        }
      }
    });


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
    _longPressProgressController.dispose(); // AnimationController を破棄
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    _uiAndNotificationTimer?.cancel();
    // _longPressTimer?.cancel(); // 削除済み
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
    if (!_isRunning) {
      if (state == AppLifecycleState.resumed) {
         StopwatchNotifier.stopNotification();
      }
      return;
    }

    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive || state == AppLifecycleState.hidden) {
      StopwatchNotifier.updateNotification(_elapsedTime);
    } else if (state == AppLifecycleState.resumed) {
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
  }

  void _handleStartStopwatch() {
    if (_ignoreTapAfterLongPressStop) {
      if (mounted) {
        setState(() {
          _ignoreTapAfterLongPressStop = false;
        });
      }
      return;
    }

    _carouselAnimationController.value = 1.0;
    _isStoppingWithLongPress = false;
    _longPressProgressController.reset(); // 開始時にプログレスコントローラーもリセット

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
  }

  void _handleStopButtonPress() {
    if (!_isRunning) return;

    if (mounted) {
      setState(() {
        _isStoppingWithLongPress = true;
      });
    }
    _longPressProgressController.forward(from: 0.0); // アニメーション開始
  }

  void _handleStopButtonRelease() {
    if (!_isRunning) return;

    if (_longPressProgressController.isAnimating) {
      _longPressProgressController.stop(); // アニメーションを途中で停止
      _longPressProgressController.reset(); // リセットしてプログレスを0に戻す
      if (mounted) {
        setState(() {
          _isStoppingWithLongPress = false;
        });
      }
    } else if (_isStoppingWithLongPress) {
      // アニメーションは完了したが、何らかの理由で isStoppingWithLongPress が true のままの場合
      // (例えば、addStatusListener の completed 内で false にする前に指を離した場合など)
      if (mounted) {
        setState(() {
          _isStoppingWithLongPress = false;
        });
      }
    }
  }

  void _handleStopStopwatch() {
    if (!_isRunning || _currentActualSessionStartTime == null) return;

    if (_hasVibrator == true) Vibration.vibrate(duration: _stopVibrationDuration);

    _uiAndNotificationTimer?.cancel();
    final Duration finalElapsedDuration = DateTime.now().difference(_currentActualSessionStartTime!);

    if(mounted){
        setState(() {
            _elapsedTime = formatDisplayTime(finalElapsedDuration);
            _isRunning = false;
            // _ignoreTapAfterLongPressStop は addStatusListener で設定済みの想定
            // _isStoppingWithLongPress も addStatusListener で設定済みの想定
        });
    }
    _stopwatch.stop();

    StopwatchNotifier.stopNotification();
    FocusScope.of(context).unfocus();
  }

  void _handleLapRecord() async {
    if (!_isRunning || _currentActualSessionStartTime == null) return;
    if (_hasVibrator == true) Vibration.vibrate(duration: _lapVibrationDuration);

    if (_ignoreTapAfterLongPressStop && mounted) {
      setState(() {
        _ignoreTapAfterLongPressStop = false;
      });
    }
    // ラップ記録時は長押しプログレスをキャンセル
    if (_longPressProgressController.isAnimating) {
      _longPressProgressController.stop();
      _longPressProgressController.reset();
    }
    if (_isStoppingWithLongPress && mounted) {
      setState(() {
        _isStoppingWithLongPress = false;
      });
    }


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
    if (_ignoreTapAfterLongPressStop && mounted) {
      setState(() {
        _ignoreTapAfterLongPressStop = false;
      });
    }
    // 設定画面遷移時にも長押しプログレスをキャンセル
    if (_longPressProgressController.isAnimating) {
      _longPressProgressController.stop();
      _longPressProgressController.reset();
    }
     if (_isStoppingWithLongPress && mounted) {
      setState(() {
        _isStoppingWithLongPress = false;
      });
    }

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
          StopwatchNotifier.stopNotification();
          return;
        }
        if (_isRunning) {
          FlutterForegroundTask.minimizeApp();
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
              backgroundColor: colorScheme.surface,
              elevation: 0,
              scrolledUnderElevation: 0.0,
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
          floatingActionButton: AnimatedBuilder( // プログレスの更新を検知して再描画
            animation: _longPressProgressController,
            builder: (context, child) {
              return StopwatchFloatingActionButton(
                isRunning: _isRunning,
                isStoppingWithLongPress: _isStoppingWithLongPress,
                longPressProgress: _longPressProgressController.value, // プログレス値を渡す
                onStartStopwatch: _handleStartStopwatch,
                onStopButtonPress: _handleStopButtonPress,
                onStopButtonRelease: _handleStopButtonRelease,
                onLapRecord: _handleLapRecord,
                onSaveSession: _showSaveSessionDialog,
                canSaveSession: _logs.isNotEmpty && !_isRunning,
              );
            },
          ),
        ),
      ),
    );
  }
}