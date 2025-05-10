// lib/screens/widgets/log_card_item.dart

import 'package:flutter/material.dart';
import '../../models/log_entry.dart'; // LogEntryモデル

class LogCardItem extends StatelessWidget {
  final LogEntry log; // 表示するログデータ
  final int logIndex; // ログのインデックス（編集時に使用）
  final Function(int) onEdit; // 編集ボタンが押されたときのコールバック

  const LogCardItem({
    super.key,
    required this.log,
    required this.logIndex,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); // 現在のテーマを取得
    final bool isCommentEmpty = log.memo.isEmpty;

    // LAP TIME のテキストスタイル（色を LogEntry の labelColor から取得）
    final lapTimeStyle = TextStyle(
      fontSize: 14.0,
      fontWeight: FontWeight.bold,
      color: log.labelColor, // LogEntryのlabelColorを使用
    );
    final lapTimeLabelStyle = TextStyle(
      fontSize: 12.0,
      fontWeight: FontWeight.bold,
      color: log.labelColor, // LogEntryのlabelColorを使用
    );


    return Card(
      elevation: 0.5,
      margin: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
      ),
      color: Colors.grey[100],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center, // この行が重要
          children: [
            // --- 左側の情報エリア (時間とコメント) ---
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                // mainAxisAlignment: MainAxisAlignment.center, // Column内部の中央揃えは解除しても良い場合がある
                children: [
                  // --- 上段: START - END 時間 ---
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(6.0),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Text(
                          log.startTime,
                          style: const TextStyle(
                            fontSize: 13.5,
                            color: Colors.black87,
                            fontWeight: FontWeight.w500,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Icon(
                            Icons.play_arrow_rounded,
                            size: 16.0,
                            color: Colors.grey[700],
                          ),
                        ),
                        Text(
                          log.endTime,
                          style: const TextStyle(
                            fontSize: 13.5,
                            color: Colors.black87,
                            fontWeight: FontWeight.w500,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8.0),

                  // --- 中段: LAP TIME ---
                  Row(
                    children: [
                      Text(
                        'LAP TIME',
                        style: lapTimeLabelStyle,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        log.elapsedTime,
                        style: lapTimeStyle,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4.0),

                  // --- 下段: コメント表示エリア ---
                  Text(
                    isCommentEmpty ? 'コメントはありません' : log.memo,
                    style: TextStyle(
                      fontSize: 14.0,
                      color: isCommentEmpty ? Colors.grey[600] : Colors.black87,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8), // 情報エリアと編集ボタンの間隔

            // --- 右側の編集ボタンエリア ---
            // SizedBoxの高さを指定せず、RowのcrossAxisAlignment: CrossAxisAlignment.centerに配置を任せる
            SizedBox(
              width: 36,
              // height: 36, // 高さを固定しない
              child: Tooltip(
                message: 'コメントを編集',
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      onEdit(logIndex);
                    },
                    borderRadius: BorderRadius.circular(18),
                    child: Icon(
                      Icons.edit,
                      size: 20,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
