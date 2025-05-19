import 'dart:math' as math;
import 'package:flutter/material.dart';

class StopwatchFloatingActionButton extends StatelessWidget {
  final bool isRunning;
  final bool isStoppingWithLongPress;
  final double longPressProgress; // 長押しの進捗 (0.0 to 1.0)
  final VoidCallback? onStartStopwatch;
  final VoidCallback? onStopButtonPress;
  final VoidCallback? onStopButtonRelease;
  final VoidCallback? onLapRecord;
  final VoidCallback? onSaveSession;
  final bool canSaveSession;

  const StopwatchFloatingActionButton({
    super.key,
    required this.isRunning,
    required this.isStoppingWithLongPress,
    required this.longPressProgress, // 追加
    this.onStartStopwatch,
    this.onStopButtonPress,
    this.onStopButtonRelease,
    this.onLapRecord,
    this.onSaveSession,
    required this.canSaveSession,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final Color invisibleColor = Colors.transparent;

    const double largeFabDimension = 88.0;
    const double smallFabDimension = 56.0;
    const double largeIconSize = 56.0;
    const double smallIconSize = 32.0;
    const double buttonsRowHeight = largeFabDimension;
    const double verticalPaddingTotal = 32.0;
    const double fabWidgetHeight = buttonsRowHeight + verticalPaddingTotal;

    final Color stopButtonColor = isRunning
        ? (isStoppingWithLongPress
            ? colorScheme.errorContainer // 長押し中は少し薄い色に変更 (例)
            : colorScheme.error)
        : colorScheme.primary;

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
            child: Stack(
              alignment: Alignment.center,
              children: [
                // ボタン本体（大きさをStackに合わせる）
                GestureDetector(
                  onTapDown: (_) {
                    if (isRunning && onStopButtonPress != null) {
                      onStopButtonPress!();
                    }
                  },
                  onTapUp: (_) {
                    if (isRunning && onStopButtonRelease != null) {
                      onStopButtonRelease!();
                    }
                  },
                  onTapCancel: () {
                    if (isRunning && onStopButtonRelease != null) {
                      onStopButtonRelease!();
                    }
                  },
                  onTap: () {
                    if (!isRunning && onStartStopwatch != null) {
                      onStartStopwatch!();
                    } else if (isRunning) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('ストップボタンは長押しで停止します。'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    }
                  },
                  child: SizedBox(
                    width: largeFabDimension,
                    height: largeFabDimension,
                    child: FloatingActionButton(
                      heroTag: 'startStopFab_separated',
                      onPressed: null,
                      backgroundColor: stopButtonColor,
                      elevation: 0,
                      shape: const CircleBorder(),
                      child: Icon(
                        isRunning ? Icons.stop_rounded : Icons.play_arrow_rounded,
                        color: isRunning ? colorScheme.onErrorContainer : colorScheme.onPrimary,
                        size: largeIconSize,
                      ),
                    ),
                  ),
                ),
                // プログレスバー（ボタンサイズに合わせて余白を最小化）
                if (isRunning && isStoppingWithLongPress && longPressProgress > 0.0)
                  SizedBox(
                    width: largeFabDimension,
                    height: largeFabDimension,
                    child: CustomPaint(
                      painter: _LongPressProgressPainter(
                        progress: longPressProgress,
                        color: colorScheme.error,
                        strokeWidth: 4.0,
                      ),
                    ),
                  ),
              ],
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

class _LongPressProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  _LongPressProgressPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final double radius = (math.min(size.width, size.height) - strokeWidth) / 2 ;
    final Offset center = Offset(size.width / 2, size.height / 2);

    // 円弧を描画
    // -pi / 2 は12時の位置から開始するため
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2, // 開始角度 (12時の方向)
      progress * 2 * math.pi, // 描画する角度 (進捗に応じて)
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _LongPressProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}