// lib/screens/widgets/log_card_list.dart

import 'package:flutter/material.dart';
import '../../models/log_entry.dart'; // LogEntryモデル
import 'log_card_item.dart'; // LogCardItemウィジェット

// ログのリスト全体をカード形式で表示するStatelessWidget
class LogCardList extends StatelessWidget {
  final List<LogEntry> logs; // 表示するログのリスト
  final Function(int) onEditLog; // 各ログカードの編集ボタンが押されたときのコールバック

  const LogCardList({
    super.key,
    required this.logs,
    required this.onEditLog,
  });

  @override
  Widget build(BuildContext context) {
    // リスト全体の背景色を白に設定
    final Color listBackgroundColor = Colors.white;

    return Container(
      color: listBackgroundColor, // ListView全体の背景色を白に変更
      child: logs.isEmpty
          // ログがない場合は「NO DATA」と表示
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'NO DATA', // ログがない場合の表示テキスト
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[700], // テキストの色を調整
                      ),
                ),
              ))
          // ログがある場合はListViewで各カードを表示
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 4.0), // リスト上下のパディング
              itemCount: logs.length, // ログの数
              itemBuilder: (context, index) {
                // リストは新しいものから順に表示するため、インデックスを逆順にする
                final logIndex = logs.length - 1 - index;
                final log = logs[logIndex];

                // LogCardItemウィジェットを生成して返す
                return LogCardItem(
                  log: log,
                  logIndex: logIndex,
                  onEdit: onEditLog,
                );
              },
            ),
    );
  }
}
