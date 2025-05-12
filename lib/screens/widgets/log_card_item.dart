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
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;

    final bool isCommentEmpty = log.memo.isEmpty;
    final Color cardBackgroundColor = log.labelColor.withAlpha(115); // 透明度0.45 (alpha: 115)

    // カード内のテキスト・アイコン色を決定 (背景色とのコントラストを考慮)
    // 例: テーマの onSurface 系を使用するか、背景の輝度に応じて動的に変更
    final Color defaultForegroundColor = ThemeData.estimateBrightnessForColor(cardBackgroundColor) == Brightness.dark
        ? Colors.white // 暗い背景なら白
        : Colors.black; // 明るい背景なら黒
    // より Material Design 3 に準拠するなら、colorScheme の onXXXContainer 系を使うことを検討
    // final Color effectiveForegroundColor = colorScheme.onSurface; // 一例

    final lapTimeStyle = TextStyle(
      fontSize: 14.0,
      fontWeight: FontWeight.bold,
      color: defaultForegroundColor,
    );
    final lapTimeLabelStyle = TextStyle(
      fontSize: 12.0,
      fontWeight: FontWeight.bold,
      color: defaultForegroundColor.withAlpha((255 * 0.87).round()), // 少し薄く (alpha: 222)
    );
    final timeTextStyle = TextStyle(
      fontSize: 13.5,
      color: defaultForegroundColor.withAlpha((255 * 0.87).round()), // (alpha: 222)
      fontWeight: FontWeight.w500,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final commentTextStyle = TextStyle(
      fontSize: 14.0,
      color: isCommentEmpty
          ? defaultForegroundColor.withAlpha((255 * 0.6).round()) // (alpha: 153)
          : defaultForegroundColor.withAlpha((255 * 0.87).round()), // (alpha: 222)
      height: 1.3,
    );
    final Color iconColor = defaultForegroundColor.withAlpha((255 * 0.7).round()); // (alpha: 179)


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
                  // mainAxisAlignment: MainAxisAlignment.spaceBetween, // ★修正前
                  mainAxisAlignment: MainAxisAlignment.start, // ★修正: 上から順に配置
                  children: [
                    // --- 上段: START - END 時間 ---
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                      decoration: BoxDecoration(
                        color: log.labelColor.withAlpha((255 * 0.2).round()), // (alpha: 51)
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
                    // const SizedBox(height: 8.0), // ★MainAxisAlignment.spaceBetween により不要になる可能性があった箇所
                    const SizedBox(height: 4.0), // ★追加: LAP TIME の上の余白を小さく設定

                    // --- 中段: LAP TIME ---
                    Row(
                      children: [
                        Text('LAP TIME', style: lapTimeLabelStyle),
                        const SizedBox(width: 8),
                        Text(log.elapsedTime, style: lapTimeStyle),
                      ],
                    ),
                    // const SizedBox(height: 4.0), // ★MainAxisAlignment.spaceBetween により不要になる可能性があった箇所
                    const SizedBox(height: 8.0), // ★追加: LAP TIME とコメントの間の余白 (適宜調整)

                    // --- 下段: コメント表示エリア ---
                    Text(
                      isCommentEmpty ? 'コメントはありません' : log.memo,
                      style: commentTextStyle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // 必要に応じて、下部のスペースを埋めるために Spacer() を追加
                    // const Spacer(), // これを入れるとコメントがカード下部に寄る
                  ],
                ),
              ),
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
            ],
          ),
        ),
      ),
    );
  }
}