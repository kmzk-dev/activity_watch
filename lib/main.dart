// main.dart
import 'package:flutter/material.dart';
import 'screens/saved_sessions_screen.dart'; // 保存済みセッション画面をインポート
import 'screens/stopwatch_screen.dart'; // ストップウォッチ画面をインポート
import 'util.dart';
import 'theme.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart'; // インポート済み
import 'services/foreground_task_handler.dart';
import 'screens/stopwatch_screen_clone.dart'; // クローンページをインポート


// アプリケーションのエントリーポイント
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterForegroundTask.initCommunicationPort();
  runApp(const ActivityWatchApp());
}

// ルートウィジェット
class ActivityWatchApp extends StatelessWidget {
  const ActivityWatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    final brightness = View.of(context).platformDispatcher.platformBrightness;
    TextTheme textTheme = createTextTheme(context, "Noto Sans JP", "Noto Sans JP");

    MaterialTheme theme = MaterialTheme(textTheme);
    return MaterialApp(
      title: 'Activity Watch',
      theme: brightness == Brightness.light ? theme.light() : theme.dark(),
      home: const AppShell(),
      debugShowCheckedModeBanner: false,
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
  int _selectedIndex = 0;

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
    final ThemeData theme = Theme.of(context); // 現在のテーマを取得

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Watch'), // 通常のタイトル
        actions: [
          // クローンページへ遷移するためのテスト用ボタン
          IconButton(
            icon: const Icon(Icons.science_outlined, color: Colors.red), // 目立つように色を変更
            tooltip: 'Test Foreground Service Screen',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const StopwatchScreenCloneWidget()),
              );
            },
          ),
        ],
      ), 
      body: IndexedStack(
        index: _selectedIndex,
        children: _widgetOptions,
      ),
      // 下部のナビゲーションバー
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          // 計測タブのアイテム
          BottomNavigationBarItem(
            icon: Icon(Icons.timer_outlined), // 計測アイコン
            label: '計測', // ラベル
          ),
          // 履歴タブのアイテム
          BottomNavigationBarItem(
            icon: Icon(Icons.history), // 履歴アイコン
            label: '履歴', // ラベル
          ),
        ],
        currentIndex: _selectedIndex, // 現在選択されているアイテムのインデックス
        onTap: _onItemTapped, // アイテムがタップされたときのコールバック
        selectedItemColor: theme.colorScheme.primary, // 選択されたアイテムの色をテーマのプライマリカラーに設定
        unselectedItemColor: theme.colorScheme.onSurface.withOpacity(0.6), // 非選択アイテムの色を少し薄く設定
        showUnselectedLabels: true, // 非選択のラベルも表示する
        // showSelectedLabels: true, // 選択されたラベルはデフォルトで表示されます
      ),
    );
  }
}
