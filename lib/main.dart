// main.dart
import 'package:flutter/material.dart';
import 'theme/app_theme.dart'; // アプリのテーマ設定をインポート
import 'screens/saved_sessions_screen.dart'; // 保存済みセッション画面をインポート
import 'screens/stopwatch_screen.dart'; // ストップウォッチ画面をインポート

// アプリケーションのエントリーポイント
void main() {
  runApp(const ActivityWatchApp());
}

// ルートウィジェット
class ActivityWatchApp extends StatelessWidget {
  const ActivityWatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Activity Watch', // アプリのタイトル
      theme: appThemeData, // アプリのテーマを適用
      home: const AppShell(), // メインの画面構造
      debugShowCheckedModeBanner: false, // デバッグバナーを非表示
    );
  }
}

// アプリケーションの主要な構造（シェル）を定義するStatefulWidget
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

// AppShellのStateクラス
class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0; // 現在選択されているタブのインデックス

  // 各タブに対応するウィジェットのリスト
  // このリスト内のウィジェットはIndexedStackによって状態が保持される
  static const List<Widget> _widgetOptions = <Widget>[
    StopwatchScreenWidget(), // 計測タブの画面
    SavedSessionsScreen(), // 履歴タブの画面
  ];

  // BottomNavigationBarのアイテムがタップされたときの処理
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index; // 選択されたタブのインデックスを更新
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStackを使用することで、タブを切り替えても各画面の状態が保持される
      // indexプロパティで現在表示するウィジェットを指定し、
      // childrenプロパティに表示候補のウィジェットリストを渡す
      body: IndexedStack(
        index: _selectedIndex,
        children: _widgetOptions,
      ),
      // 下部のナビゲーションバー
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          // 計測タブのアイテム (アイコンを SizedBox.shrink() に変更)
          BottomNavigationBarItem(
            icon: SizedBox.shrink(), // アイコンを非表示にするための空のSizedBox
            label: '計測', // ラベル
          ),
          // 履歴タブのアイテム (アイコンを SizedBox.shrink() に変更)
          BottomNavigationBarItem(
            icon: SizedBox.shrink(), // アイコンを非表示にするための空のSizedBox
            label: '履歴', // ラベル
          ),
        ],
        currentIndex: _selectedIndex, // 現在選択されているアイテムのインデックス
        onTap: _onItemTapped, // アイテムがタップされたときのコールバック
        // showSelectedLabels: true, // 選択されたラベルはデフォルトで表示されます
        // showUnselectedLabels: true, // 選択されていないラベルも表示する場合 (テーマで設定済みなら不要な場合も)
      ),
    );
  }
}
