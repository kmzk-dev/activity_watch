// lib/screens/widgets/stopwatch_floating_action_button.dart
import 'package:flutter/material.dart';

class StopwatchFloatingActionButton extends StatelessWidget {
  final bool isRunning;
  final VoidCallback? onStartStopwatch;
  final VoidCallback? onStopStopwatch;
  final VoidCallback? onLapRecord;
  final VoidCallback? onSaveSession; // <-- 追加: 保存処理のコールバック
  final bool canSaveSession;      // <-- 追加: 保存ボタンの有効状態


  const StopwatchFloatingActionButton({
    super.key,
    required this.isRunning,
    this.onStartStopwatch,
    this.onStopStopwatch,
    this.onLapRecord,
    this.onSaveSession, // <-- 追加
    required this.canSaveSession, // <-- 追加
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final Color invisibleColor = theme.scaffoldBackgroundColor; // 背景色と同じにして要素を隠す

    // FABのサイズ定義
    const double largeFabDimension = 88.0;
    const double smallFabDimension = 56.0;
    const double largeIconSize = 56.0;
    const double smallIconSize = 32.0;

    // ボタン群（Row）が占める実際の高さ（最大のFABの高さ）
    const double buttonsRowHeight = largeFabDimension;

    const double verticalPaddingTotal = 32.0;
    const double fabWidgetHeight = buttonsRowHeight + verticalPaddingTotal;

    return Container(
      height: fabWidgetHeight,
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          // 左ボタン (セッション保存)
          SizedBox(
            width: smallFabDimension,
            height: smallFabDimension,
            child: FloatingActionButton(
              heroTag: 'saveSession_separated',
              onPressed: canSaveSession ? onSaveSession : null,
              backgroundColor: canSaveSession ? colorScheme.secondaryContainer : invisibleColor,
              foregroundColor: canSaveSession ? colorScheme.onSecondaryContainer : invisibleColor,
              elevation: canSaveSession ? 2 : 0,
              shape: const CircleBorder(),
              child: Icon(Icons.save_alt_outlined, size: smallIconSize),
            ),
          ),
          // 中央ボタン (開始/停止)
          SizedBox(
            width: largeFabDimension,
            height: largeFabDimension,
            child: FloatingActionButton(
              heroTag: 'startStopFab_separated',
              onPressed: isRunning ? onStopStopwatch : onStartStopwatch,
              backgroundColor: isRunning ? colorScheme.error : colorScheme.primary,
              elevation: 4,
              shape: const CircleBorder(),
              child: Icon(
                isRunning ? Icons.stop_rounded : Icons.play_arrow_rounded,
                color: isRunning ? colorScheme.onError : colorScheme.onPrimary,
                size: largeIconSize,
              ),
            ),
          ),
          // 右ボタン (ラップ記録)
          SizedBox(
            width: smallFabDimension,
            height: smallFabDimension,
            child: FloatingActionButton(
              heroTag: 'lapRecordFab_separated',
              onPressed: isRunning ? onLapRecord : null,
              backgroundColor: isRunning ? colorScheme.secondary : invisibleColor, 
              foregroundColor: isRunning ? colorScheme.onSecondary : invisibleColor,
              elevation: isRunning ? 2 : 0,
              shape: const CircleBorder(),
              child: Icon(Icons.timer_outlined, size: smallIconSize),
            ),
          ),
        ],
      ),
    );
  }
}