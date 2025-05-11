// lib/screens/widgets/log_card_carousel.dart
import 'package:flutter/material.dart';
import '../../models/log_entry.dart'; // LogEntryモデル
import 'log_card_item.dart'; // LogCardItemウィジェット

class LogCardCarousel extends StatelessWidget {
  final List<LogEntry> logs; // 表示するログのリスト (表示したい順序で渡されることを期待)
  final Function(int pageViewIndex) onEditLog; // 各ログカードの編集ボタンが押されたときのコールバック
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
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'NO DATA',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[700],
                ),
          ),
        ),
      );
    }

    return Container(
      color: listBackgroundColor,
      child: PageView.builder(
        controller: pageController,
        itemCount: logs.length,
        onPageChanged: onPageChanged,
        itemBuilder: (context, index) {
          // PageViewのindexは、渡されたlogsリストのindexと一致する。
          // 呼び出し側(stopwatch_screen.dart)で表示順を制御したリストを渡す。
          final log = logs[index];
          // onEditLogに渡すindexは、この表示用リストのindex。
          // 呼び出し側で、このindexを元の_logsリストの実際のindexにマッピングする。
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: LogCardItem(
              log: log,
              logIndex: index, // 表示用リストのインデックスを渡す
              onEdit: onEditLog,
            ),
          );
        },
      ),
    );
  }
}
