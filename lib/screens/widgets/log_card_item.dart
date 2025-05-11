// lib/screens/widgets/log_card_item.dart

import 'package:flutter/material.dart';
import '../../models/log_entry.dart'; // LogEntryモデル

class LogCardItem extends StatelessWidget {
  final LogEntry log; // 表示するログデータ
  final int logIndex; // ログのインデックス（編集時に使用）
  final Function(int) onEdit; // 編集ボタンが押されたときのコールバック
  // final double? itemHeight; // 必要であれば外部から高さを指定できるようにする

  const LogCardItem({
    super.key,
    required this.log,
    required this.logIndex,
    required this.onEdit,
    // this.itemHeight, // 必要であれば外部から高さを指定できるようにする
  });

  @override
  Widget build(BuildContext context) {
    //final theme = Theme.of(context); // 現在のテーマを取得
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

    // カードの高さを固定値で定義 (この値はデザインに合わせて調整してください)
    const double fixedCardHeight = 160.0; // 例: 160ピクセル

    return SizedBox(
      height: fixedCardHeight, // SizedBoxで高さを固定
      child: Card(
        elevation: 0.5,
        margin: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
        color: Colors.grey[100],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // --- 左側の情報エリア (時間とコメント) ---
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween, // 要素間のスペースを均等に配分
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
                    // const SizedBox(height: 8.0), // MainAxisAlignment.spaceBetween により不要になる可能性

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
                    // const SizedBox(height: 4.0), // MainAxisAlignment.spaceBetween により不要になる可能性

                    // --- 下段: コメント表示エリア ---
                    Text(
                      isCommentEmpty ? 'コメントはありません' : log.memo,
                      style: TextStyle(
                        fontSize: 14.0,
                        color: isCommentEmpty ? Colors.grey[600] : Colors.black87,
                        height: 1.3,
                      ),
                      maxLines: 2, // 表示行数を2行に制限
                      overflow: TextOverflow.ellipsis, // 2行を超える場合は省略記号
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8), // 情報エリアと編集ボタンの間隔

              // --- 右側の編集ボタンエリア ---
              SizedBox(
                width: 36,
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
      ),
    );
  }
}
