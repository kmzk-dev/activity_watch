import 'package:flutter/material.dart';
import '../settings_screen.dart'; // SettingsScreenをインポート

// StopwatchScreen専用のAppBarウィジェット
// PreferredSizeWidgetを実装することで、AppBarとしてScafooldに配置可能になる
class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CustomAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    // AppBarウィジェットを構築
    return AppBar(
      // AppBar右側に配置するアクションボタンのリスト
      actions: <Widget>[
        // 設定アイコンボタン
        IconButton(
          icon: const Icon(Icons.settings), // 設定アイコン
          tooltip: '設定', // ツールチップでボタンの機能を説明
          onPressed: () {
            // ボタンが押されたらSettingsScreenへ遷移
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsScreen()),
            );
          },
        ),
      ],
    );
  }

  // AppBarの推奨サイズを返す (通常はkToolbarHeight)
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
