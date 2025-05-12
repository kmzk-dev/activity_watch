// lib/screens/widgets/stopwatch_floating_action_button.dart
import 'package:flutter/material.dart';

class StopwatchFloatingActionButton extends StatelessWidget {
  final bool isRunning;
  final VoidCallback? onStartStopwatch;
  final VoidCallback? onStopStopwatch;
  final VoidCallback? onLapRecord;
  final VoidCallback? onSettings;
  // final Color? primaryColor; // マテリアルテーマ準拠のため削除、またはテーマから取得するように変更
  // final Color? stopColor; // マテリアルテーマ準拠のため削除、またはテーマから取得するように変更
  // final Color? secondaryColor; // マテリアルテーマ準拠のため削除、またはテーマから取得するように変更
  // final Color? disabledColor; // マテリアルテーマ準拠のため削除、またはテーマから取得するように変更

  const StopwatchFloatingActionButton({
    super.key,
    required this.isRunning,
    this.onStartStopwatch,
    this.onStopStopwatch,
    this.onLapRecord,
    this.onSettings,
    // this.primaryColor, // マテリアルテーマ準拠のため削除
    // this.stopColor, // マテリアルテーマ準拠のため削除
    // this.secondaryColor, // マテリアルテーマ準拠のため削除
    // this.disabledColor, // マテリアルテーマ準拠のため削除
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

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
              // backgroundColor: Colors.grey[300], // 修正: テーマの色を使用
              //backgroundColor: theme.colorScheme.surfaceVariant, // または適切なテーマの色
              elevation: 2,
              shape: const CircleBorder(),
              // child: Icon(Icons.settings_outlined, color: Colors.grey[700], size: smallIconSize), // 修正: テーマの色を使用
              child: Icon(Icons.settings_outlined, color: theme.colorScheme.onSurfaceVariant, size: smallIconSize),
            ),
          ),
          // 中央ボタン (開始/停止)
          SizedBox(
            width: largeFabDimension,
            height: largeFabDimension,
            child: FloatingActionButton(
              heroTag: 'startStopFab_separated',
              onPressed: isRunning ? onStopStopwatch : onStartStopwatch,
              // backgroundColor: isRunning ? currentStopColor : currentPrimaryColor, // 修正: テーマの色を使用
              backgroundColor: isRunning ? colorScheme.error : colorScheme.primary,
              elevation: 4,
              shape: const CircleBorder(),
              child: Icon(
                isRunning ? Icons.stop_rounded : Icons.play_arrow_rounded,
                // color: Colors.white, // 修正: アイコンの色はテーマによって自動的に決定されることが多い
                // 必要であれば明示的に指定: colorScheme.onError または colorScheme.onPrimary
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
              // backgroundColor: isRunning ? currentSecondaryColor : currentDisabledColor, // 修正: テーマの色を使用
              backgroundColor: isRunning ? colorScheme.secondary : theme.disabledColor.withOpacity(0.12), // 無効状態の背景色
              foregroundColor: isRunning ? colorScheme.onSecondary : theme.disabledColor, // 無効状態のアイコン色
              elevation: 2,
              shape: const CircleBorder(),
              // child: Icon(Icons.timer_outlined, color: Colors.white, size: smallIconSize), // 修正: テーマの色を使用
               child: Icon(Icons.timer_outlined, size: smallIconSize),
            ),
          ),
        ],
      ),
    );
  }
}