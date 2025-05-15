// lib/screens/widgets/log_card_carousel.dart
import 'package:flutter/material.dart';
import '../../models/log_entry.dart'; // LogEntryモデル
import 'log_card_item.dart'; // LogCardItemウィジェット
import '../../theme/color_constants.dart'; // colorLabels をインポート

class LogCardCarousel extends StatelessWidget {
  final List<LogEntry> logs;
  final Function(int pageViewIndex) onEditLog;
  final PageController? pageController;
  final Function(int page)? onPageChanged;

  const LogCardCarousel({
    super.key,
    required this.logs,
    required this.onEditLog,
    this.pageController,
    this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    final Color listBackgroundColor = Theme.of(context).scaffoldBackgroundColor;

    if (logs.isEmpty) {
      // データがない場合、ダミーのLogEntryを作成して表示
      final LogEntry dummyLog = LogEntry(
        actualSessionStartTime: DateTime(1970), // 固定の過去日時、または DateTime.now()
        startTime: '前回の時間',
        endTime: 'ラップした時間',
        memo: 'ラップを記録するとカードが編集できます', // メモは空（「なにもないこと」を示す）
        colorLabelName: colorLabels.keys.isNotEmpty
            ? colorLabels.keys.first // colorLabelsから最初のキーを使用
            : 'dark', // colorLabelsが空の場合のフォールバック
      );
      dummyLog.calculateDuration(); // duration を 0 に設定

      // PageView.builder内のPaddingと合わせて、単一のカードを表示
      return Container(
        color: listBackgroundColor, // 背景色を適用
        alignment: Alignment.center, // 中央に配置
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: LogCardItem(
            log: dummyLog,
            logIndex: -1, // ダミーのインデックス（編集不可を示す）
            onEdit: (_) {}, // 編集ボタンは何もしない
            showEditIcon: false, 
          ),
        ),
      );
    }

    // データがある場合は、これまで通りPageView.builderで表示
    return Container(
      color: listBackgroundColor,
      child: PageView.builder(
        controller: pageController,
        itemCount: logs.length,
        onPageChanged: onPageChanged,
        itemBuilder: (context, index) {
          final log = logs[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: LogCardItem(
              log: log,
              logIndex: index,
              onEdit: onEditLog,
            ),
          );
        },
      ),
    );
  }
}