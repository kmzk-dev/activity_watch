import 'package:flutter/material.dart';
import '../../models/log_entry.dart'; // LogEntryモデルをインポート

// ログリストの各行を表示するStatelessWidget
class LogRow extends StatelessWidget {
  final LogEntry log; // 表示するログデータ
  final int logIndex; // ログのインデックス（編集時に使用）
  final Function(int) onEdit; // 編集ボタンが押されたときのコールバック

  const LogRow({
    super.key,
    required this.log,
    required this.logIndex,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    // 現在のテーマとDataTableThemeを取得
    final theme = Theme.of(context);
    final dataTableTheme = theme.dataTableTheme;
    // データ行の最小高さを取得、なければデフォルト値を使用
    final dataRowMinHeight = dataTableTheme.dataRowMinHeight ?? 48.0;

    return Container(
      // データ行の最小高さを設定
      constraints: BoxConstraints(minHeight: dataRowMinHeight),
      // パディングを設定
      padding: const EdgeInsets.only(left: 16.0, right: 0, top: 8.0, bottom: 8.0),
      // Rowウィジェットで各列のデータを配置
      child: Row(
        children: <Widget>[
          // 「END」列 (ログの終了時刻)
          Expanded(
            flex: 2, // Row内の占有スペースの割合
            child: Text(log.endTime),
          ),
          // 「COMMENT」列 (ログのメモ)
          Expanded(
            flex: 4, // Row内の占有スペースの割合
            child: Tooltip(
              message: log.memo, // 長いメモはツールチップで表示
              child: Text(
                log.memo,
                overflow: TextOverflow.ellipsis, // 範囲外のテキストは省略記号で表示
                maxLines: 2, // 最大2行まで表示
                style: TextStyle(color: log.labelColor), // ラベルの色を適用
              ),
            ),
          ),
          // 「ELAPSED」列 (ログの経過時間)
          Expanded(
            flex: 3, // Row内の占有スペースの割合
            child: Text(log.elapsedTime),
          ),
          // 編集ボタン
          SizedBox(
            width: 48, // ボタンの幅を固定
            child: Tooltip(
              message: 'EDIT COMMENT', // ツールチップメッセージ
              child: IconButton(
                icon: const Icon(Icons.edit_note, size: 20), // 編集アイコン
                padding: EdgeInsets.zero, // パディングを最小限に
                visualDensity: VisualDensity.compact, // ボタンの密度をコンパクトに
                onPressed: () {
                  onEdit(logIndex); // 編集コールバックを実行
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
