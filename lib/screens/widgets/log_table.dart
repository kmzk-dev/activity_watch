import 'package:flutter/material.dart';
import '../../models/log_entry.dart'; // LogEntryモデル
import 'log_table_header.dart'; // LogTableHeaderウィジェット
import 'log_row.dart'; // LogRowウィジェット

// ログのリスト全体（ヘッダーと行）を表示するStatelessWidget
class LogTable extends StatelessWidget {
  final List<LogEntry> logs; // 表示するログのリスト
  final Function(int) onEditLog; // 各ログ行の編集ボタンが押されたときのコールバック

  const LogTable({
    super.key,
    required this.logs,
    required this.onEditLog,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ログテーブルのヘッダーを表示
        const LogTableHeader(),
        // ログリスト本体を表示
        Expanded(
          child: logs.isEmpty
              // ログがない場合は「NO DATA」と表示
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'NO DATA',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ))
              // ログがある場合はListViewで各行を表示
              : ListView.builder(
                  itemCount: logs.length, // ログの数
                  itemBuilder: (context, index) {
                    // リストは新しいものから順に表示するため、インデックスを逆順にする
                    final logIndex = logs.length - 1 - index;
                    final log = logs[logIndex];
                    // LogRowウィジェットを生成して返す
                    return LogRow(
                      log: log,
                      logIndex: logIndex,
                      onEdit: onEditLog, // 編集コールバックを渡す
                    );
                  },
                ),
        ),
      ],
    );
  }
}
