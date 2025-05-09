import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // google_fonts パッケージをインポート

// アプリケーションのテーマ定義
final ThemeData appThemeData = ThemeData(
  primarySwatch: Colors.blue, // アプリケーションのプライマリスウォッチ（主要な色のセット）
  colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.blue).copyWith(
    secondary: Colors.blueAccent, // セカンダリカラー（アクセントカラー）
  ),
  // --- フォント設定 ---
  // GoogleFonts.notoSansJpTextTheme() を使用して、
  // アプリケーション全体のテキストテーマに Noto Sans Japanese フォントを適用します。
  // ThemeData(brightness: Brightness.light).textTheme を渡すことで、
  // ライトテーマのデフォルトテキストスタイルをベースにフォントが適用されます。
  // ダークテーマ対応など、より詳細な設定が必要な場合は、
  // ThemeData.dark().textTheme なども考慮に入れることができます。
  textTheme: GoogleFonts.notoSansJpTextTheme(
    ThemeData(brightness: Brightness.light).textTheme,
  ),
  // --- ダイアログのテーマ設定 ---
  dialogTheme: DialogTheme(
    // ダイアログの角を丸くします。
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16.0),
    ),
  ),
  // --- データテーブルのテーマ設定 ---
  dataTableTheme: DataTableThemeData(
    dataRowMinHeight: 48, // データ行の最小の高さ
    columnSpacing: 16, // 列間のスペース
    // ヘッダー行のテキストスタイル
    headingTextStyle: const TextStyle(
        fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 14),
  ),
  // --- アイコンボタンのテーマ設定 ---
  iconButtonTheme: IconButtonThemeData(
    // IconButton.styleFrom は const ではないため、ThemeData 全体を const にできません。
    style: IconButton.styleFrom(
      foregroundColor: Colors.grey[700], // アイコンボタンの前景色（アイコンの色）
    ),
  ),
  // --- ボトムナビゲーションバーのテーマ設定 ---
  bottomNavigationBarTheme: BottomNavigationBarThemeData(
    selectedItemColor: Colors.blue, // 選択されたアイテムの色
    unselectedItemColor: Colors.grey, // 選択されていないアイテムの色
    showUnselectedLabels: true, // 選択されていないアイテムのラベルを表示するかどうか
  ),
);
