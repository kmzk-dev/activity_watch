// lib/theme/color_constants.dart
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart'; // SchedulerBinding を使用するためにインポート
import '../theme.dart'; // MaterialTheme とそのスキーム定義をインポート

Map<String, Color> get colorLabels {
  // 現在のプラットフォームの明るさを取得
  // 注意: これはアプリがテーマモードをオーバーライドしている場合には追従しません。
  // アプリのテーマがシステム追従であれば、これで問題ありません。
  final Brightness platformBrightness = SchedulerBinding.instance.platformDispatcher.platformBrightness;

  if (platformBrightness == Brightness.dark) {
    // ダークモード時の色定義
    final darkScheme = MaterialTheme.darkScheme(); // lib/theme.dart からダークスキームを取得
    return {
      'dark': darkScheme.outline,
      'fire': darkScheme.error,
      'water': darkScheme.primary,
      'Earth': darkScheme.tertiaryContainer,
      'Light': darkScheme.secondary,
    };
  } else {
    // ライトモード時の色定義
    final lightScheme = MaterialTheme.lightScheme();
    return {
      'dark': lightScheme.outline,
      'fire': lightScheme.error,
      'water': lightScheme.primary,
      'Earth': lightScheme.tertiaryContainer,
      'Light': lightScheme.secondary,
    };
  }
}