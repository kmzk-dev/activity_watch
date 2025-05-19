// main.dart
import 'package:flutter/material.dart';
import 'util.dart';
import 'theme.dart';
// オプション
import 'utils/stopwatch_notifier.dart';
import 'theme/scale.dart';
// 各画面
import 'screens/saved_sessions_screen.dart';
import 'screens/stopwatch_screen.dart';

// エントリーポイント
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  StopwatchNotifier.initializeService();
  runApp(const ActivityWatchApp());
}

// ルート
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
    );
  }
}

// アプリケーションの主要な構造（シェル）を定義
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

// AppShellのStateクラス
class _AppShellState extends State<AppShell> {

  // BottomNavigationBarのルーティング処理
  int _selectedIndex = 0;

  // BottomNavigationBarのインデックス
  static const List<Widget> _widgetOptions = <Widget>[
    StopwatchScreenWidget(), 
    SavedSessionsScreen(),
  ];
  
  // BottomNavigationBarのアイテムがタップされたときの処理
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      // appBarは各画面で描画する
      // bodyは各画面で描画する
      body: IndexedStack(
        index: _selectedIndex,
        children: _widgetOptions,
      ),
      // 下部のナビゲーションバー
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.timer_outlined),
            label: '計測', 
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list),
            label: '履歴',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: theme.colorScheme.primary,
        unselectedItemColor: theme.colorScheme.onSurface.withAlpha(Scale.alpha60),
        showUnselectedLabels: false,
        showSelectedLabels: true,
      ),
    );
  }
}
