// lib/screens/widgets/log_card_item.dart

import 'package:flutter/material.dart';
import '../../models/log_entry.dart';
import '../../theme/scale.dart'; // Scaleクラスをインポート

class LogCardItem extends StatelessWidget {
  final LogEntry log;
  final int logIndex;
  final Function(int) onEdit; // 編集ボタンが押されたときのコールバック
  final bool showEditIcon; // <--- 追加: 編集アイコンの表示フラグ

  const LogCardItem({
    super.key,
    required this.log,
    required this.logIndex,
    required this.onEdit,
    this.showEditIcon = true, // <--- 追加: デフォルトはtrue（表示する）
  });

  @override
  Widget build(BuildContext context) {

    final bool isCommentEmpty = log.memo.isEmpty;
    final Color cardBackgroundColor = log.labelColor.withAlpha(Scale.alpha87);
    final Color defaultForegroundColor = Theme.of(context).colorScheme.surface;

    final lapTimeStyle = TextStyle(
      fontSize: 14.0,
      fontWeight: FontWeight.bold,
      color: defaultForegroundColor,
    );

    final lapTimeLabelStyle = TextStyle(
      fontSize: 12.0,
      fontWeight: FontWeight.bold,
      color: defaultForegroundColor.withAlpha(Scale.alpha87),
    );

    final timeTextStyle = TextStyle(
      fontSize: 13.5,
      color: defaultForegroundColor.withAlpha(Scale.alpha87),
      fontWeight: FontWeight.w500,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    final commentTextStyle = TextStyle(
      fontSize: 14.0,
      color: isCommentEmpty
          ? defaultForegroundColor.withAlpha(Scale.alpha50)
          : defaultForegroundColor.withAlpha(Scale.alpha87),
      height: 1.3,
    );

    final Color iconColor = defaultForegroundColor.withAlpha(Scale.alpha70);

    const double fixedCardHeight = 160.0;

    return SizedBox(
      height: fixedCardHeight,
      child: Card(
        elevation: 0.5,
        margin: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
        ),
        color: cardBackgroundColor,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    // --- 上段: START - END 時間 ---
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                      decoration: BoxDecoration(
                        color: log.labelColor.withAlpha(Scale.alpha60),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Text(log.startTime, style: timeTextStyle),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0),
                            child: Icon(
                              Icons.play_arrow_rounded,
                              size: 16.0,
                              color: iconColor,
                            ),
                          ),
                          Text(log.endTime, style: timeTextStyle),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4.0),

                    // --- 中段: LAP TIME ---
                    Row(
                      children: [
                        Text('LAP TIME', style: lapTimeLabelStyle),
                        const SizedBox(width: 8),
                        Text(log.elapsedTime, style: lapTimeStyle),
                      ],
                    ),
                    const SizedBox(height: 8.0),

                    // --- 下段: コメント表示エリア ---
                    Text(
                      isCommentEmpty ? 'コメントはありません' : log.memo,
                      style: commentTextStyle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // --- 編集アイコン ---
              if (showEditIcon) ...[
                const SizedBox(width: 8),
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
                          color: iconColor,
                        ),
                      ),
                    ),
                  ),
                ),
               ] else ...[
                const SizedBox(width: 8),
                SizedBox(
                  width: 36,
                  child: Tooltip(
                    message: '編集不可',
                    child: Icon(
                      Icons.lock,
                      size: 20,
                      color: iconColor,
                    ),
                  ),
                ),
               ],
            ],
          ),
        ),
      ),
    );
  }
}