// lib/screens/widgets/stopwatch_floating_action_button.dart
import 'package:flutter/material.dart';

class StopwatchFloatingActionButton extends StatelessWidget {
  final bool isRunning;
  final VoidCallback? onStartStopwatch;
  final VoidCallback? onStopStopwatch;
  final VoidCallback? onLapRecord;
  final VoidCallback? onSettings;
  final Color? primaryColor;
  final Color? stopColor;
  final Color? secondaryColor;
  final Color? disabledColor;

  const StopwatchFloatingActionButton({
    super.key,
    required this.isRunning,
    this.onStartStopwatch,
    this.onStopStopwatch,
    this.onLapRecord,
    this.onSettings,
    this.primaryColor,
    this.stopColor,
    this.secondaryColor,
    this.disabledColor,
  });

  @override
  Widget build(BuildContext context) {
    final Color currentPrimaryColor = primaryColor ?? Theme.of(context).colorScheme.primary;
    final Color currentStopColor = stopColor ?? Colors.redAccent;
    final Color currentSecondaryColor = secondaryColor ?? Theme.of(context).colorScheme.secondary;
    final Color currentDisabledColor = disabledColor ?? Colors.grey[400]!;

    // FABのサイズ定義
    const double largeFabDimension = 88.0;
    const double smallFabDimension = 56.0;
    const double largeIconSize = 56.0;
    const double smallIconSize = 32.0;

    // ボタン群（Row）が占める実際の高さ（最大のFABの高さ）
    const double buttonsRowHeight = largeFabDimension;

    // StopwatchFloatingActionButtonウィジェット全体の高さを定義します。
    // この高さは、BottomNavigationBarの上に表示されるFAB領域全体の高さです。
    // ボタン群がこの高さの中で中央に配置されるように、
    // ボタン群の高さに加えて、上下のパディング（視覚的なマージン）を考慮します。
    // 例えば、ボタン群の上と下にそれぞれ16ずつの余白（合計32）を設ける場合：
    const double verticalPaddingTotal = 32.0; // ★ この値を調整して垂直位置を微調整
    const double fabWidgetHeight = buttonsRowHeight + verticalPaddingTotal;

    return Container(
      height: fabWidgetHeight,
      // 背景色で全体の領域を確認 (デバッグが終わったら削除またはコメントアウト)
      color: Colors.grey.withOpacity(0.2),
      // このContainer（高さfabWidgetHeight）の中でRowを中央に配置
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          // 左ボタン (設定)
          SizedBox(
            width: smallFabDimension,
            height: smallFabDimension,
            child: FloatingActionButton(
              heroTag: 'settingsFab_separated',
              onPressed: onSettings,
              backgroundColor: Colors.grey[300],
              elevation: 2,
              shape: const CircleBorder(),
              child: Icon(Icons.settings_outlined, color: Colors.grey[700], size: smallIconSize),
            ),
          ),
          // 中央ボタン (開始/停止)
          SizedBox(
            width: largeFabDimension,
            height: largeFabDimension,
            child: FloatingActionButton(
              heroTag: 'startStopFab_separated',
              onPressed: isRunning ? onStopStopwatch : onStartStopwatch,
              backgroundColor: isRunning ? currentStopColor : currentPrimaryColor,
              elevation: 4,
              shape: const CircleBorder(),
              child: Icon(
                isRunning ? Icons.stop_rounded : Icons.play_arrow_rounded,
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
              heroTag: 'lapRecordFab_separated',
              onPressed: isRunning ? onLapRecord : null,
              backgroundColor: isRunning ? currentSecondaryColor : currentDisabledColor,
              elevation: 2,
              shape: const CircleBorder(),
              child: Icon(Icons.timer_outlined, color: Colors.white, size: smallIconSize),
            ),
          ),
        ],
      ),
    );
  }
}