import 'package:flutter/material.dart';

// アプリケーションのテーマ定義
final ThemeData appThemeData = ThemeData(
  primarySwatch: Colors.blue,
  colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.blue).copyWith(
    secondary: Colors.blueAccent,
  ),
  dialogTheme: DialogTheme(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16.0),
    ),
  ),
  dataTableTheme: DataTableThemeData(
    dataRowMinHeight: 48,
    columnSpacing: 16,
    headingTextStyle: const TextStyle(
        fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 14),
  ),
  iconButtonTheme: IconButtonThemeData(
    // IconButton.styleFrom は const ではないため、ThemeData 全体を const にできない
    style: IconButton.styleFrom(
      foregroundColor: Colors.grey[700],
    ),
  ),
  bottomNavigationBarTheme: BottomNavigationBarThemeData(
    // Theme.of(context) に依存しないように具体的な色を指定する例
    // もしくは、実行時に context から取得する別の方法を検討
    selectedItemColor: Colors.blue, // primarySwatch と同じ色を指定
    unselectedItemColor: Colors.grey,
    showUnselectedLabels: true,
  ),
);
