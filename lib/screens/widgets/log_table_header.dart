import 'package:flutter/material.dart';

// ログリストのヘッダーを表示するStatelessWidget
class LogTableHeader extends StatelessWidget {
  const LogTableHeader({super.key});

  @override
  Widget build(BuildContext context) {
    // 現在のテーマを取得
    final theme = Theme.of(context);
    // DataTableThemeからヘッダーのテキストスタイルを取得。存在しない場合はデフォルトスタイルを使用。
    final dataTableTheme = theme.dataTableTheme;
    final headingTextStyle = dataTableTheme.headingTextStyle ??
        const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 14);

    // ヘッダーのレイアウトを構築
    return Container(
      // 下線を追加してテーブルヘッダーらしく見せる
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor, // テーマの区切り線色を使用
            width: 1.0,
          ),
        ),
      ),
      // 水平方向と垂直方向のパディングを設定
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      // Rowウィジェットで各列のヘッダーテキストを配置
      child: Row(
        children: <Widget>[
          // 「END」列のヘッダー
          Expanded(
            flex: 2, // Row内の占有スペースの割合
            child: Text('END', style: headingTextStyle),
          ),
          // 「COMMENT」列のヘッダー
          Expanded(
            flex: 4, // Row内の占有スペースの割合
            child: Text('COMMENT', style: headingTextStyle),
          ),
          // 「ELAPSED」列のヘッダー
          Expanded(
            flex: 3, // Row内の占有スペースの割合
            child: Text('LAP TIME', style: headingTextStyle),
          ),
          // 右端の編集ボタンとのスペース調整用
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}
