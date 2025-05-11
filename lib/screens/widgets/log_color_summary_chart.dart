// lib/screens/widgets/log_color_summary_chart.dart
import 'package:flutter/material.dart';
import 'dart:math'; // max関数とmin関数を使用するためにインポート
import '../../models/log_entry.dart'; // LogEntryモデル
import '../../theme/color_constants.dart'; // colorLabelsを使用
// import '../../utils/time_formatters.dart'; // 時間表示が不要になったためコメントアウト

class LogColorSummaryChart extends StatelessWidget {
  final List<LogEntry> logs;
  final double chartHeight; // この高さは、グラフ描画エリア（棒が表示されるSizedBox）の高さ

  const LogColorSummaryChart({
    super.key,
    required this.logs,
    this.chartHeight = 100.0, 
  });

  // 色ラベルごとの合計経過時間を計算する
  Map<String, Duration> _calculateColorLabelDurations() {
    final Map<String, Duration> colorDurations = {};
    for (var labelName in colorLabels.keys) {
      colorDurations[labelName] = Duration.zero;
    }
    if (logs.isNotEmpty) {
      for (var log in logs) {
        if (log.duration != null) {
          if (colorDurations.containsKey(log.colorLabelName)) {
            colorDurations[log.colorLabelName] =
                (colorDurations[log.colorLabelName] ?? Duration.zero) + log.duration!;
          }
        }
      }
    }
    return colorDurations;
  }

  // 全ログの合計経過時間を計算する
  Duration _calculateTotalSessionDuration() {
    if (logs.isEmpty) {
      return Duration.zero;
    }
    return logs.fold(
        Duration.zero, (previousValue, log) => previousValue + (log.duration ?? Duration.zero));
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, Duration> colorLabelDurations = _calculateColorLabelDurations();
    final Duration totalSessionDuration = _calculateTotalSessionDuration();

    final double totalSessionDurationInSeconds = totalSessionDuration.inSeconds > 0 ? totalSessionDuration.inSeconds.toDouble() : 1.0;

    List<Widget> chartItems = [];

    const double labelTextSize = 10.0;
    final TextPainter labelTextPainter = TextPainter(
        text: TextSpan(text: "Placeholder", style: TextStyle(fontSize: labelTextSize)),
        maxLines: 1,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr)..layout(minWidth: 0, maxWidth: 50); // maxWidthも指定してより正確に
    
    final double actualLabelTextHeight = labelTextPainter.height;
    const double paddingBelowBar = 4.0; 
    const double overflowPixelBuffer = 4.0; // オーバーフロー対策のための追加バッファ

    // 棒が実際に使える最大の高さ (chartHeightからラベルとパディング、バッファを引いたもの)
    final double maxDrawableBarHeight = chartHeight - actualLabelTextHeight - paddingBelowBar - overflowPixelBuffer;

    colorLabels.forEach((labelName, defaultColor) {
      final Duration duration = colorLabelDurations[labelName] ?? Duration.zero;
      final Color barColor = defaultColor; 

      final double barHeightRatio = totalSessionDurationInSeconds > 0 && duration.inSeconds > 0
          ? (duration.inSeconds / totalSessionDurationInSeconds)
          : 0.0;
      
      double calculatedBarHeight = maxDrawableBarHeight * barHeightRatio;
      // 棒の高さが負にならないようにし、最小でも2.0は確保 (ただしmaxDrawableBarHeightが2より小さい場合はそれに合わせる)
      calculatedBarHeight = max(min(2.0, max(0,maxDrawableBarHeight)), calculatedBarHeight); 
      final double finalBarHeight = min(calculatedBarHeight, max(0,maxDrawableBarHeight)); // maxDrawableBarHeightを超えないように

      chartItems.add(
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end, 
              children: <Widget>[
                Container(
                  width: 20.0, 
                  height: finalBarHeight, 
                  decoration: BoxDecoration(
                    color: barColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4.0),
                      topRight: Radius.circular(4.0),
                    ),
                  ),
                ),
                const SizedBox(height: paddingBelowBar), 
                Text(
                  labelName,
                  style: TextStyle(fontSize: labelTextSize, color: Theme.of(context).textTheme.bodySmall?.color),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ),
      );
    });

    List<Widget> gridLines = [];
    if (maxDrawableBarHeight > 0) { // 描画領域がある場合のみ罫線を描画
        for (int i = 0; i <= 4; i++) { 
            gridLines.add(
                Positioned(
                bottom: (maxDrawableBarHeight / 4) * i + actualLabelTextHeight + paddingBelowBar, // 棒の描画エリアの底からの相対位置に修正
                left: 0,
                right: 0,
                child: Container(
                    height: 1.0,
                    color: Colors.grey[300], 
                ),
                ),
            );
        }
    }
    
    if (logs.isEmpty) {
      return Container( 
        height: chartHeight + actualLabelTextHeight + paddingBelowBar + 32, 
        margin: const EdgeInsets.all(16.0), 
        padding: const EdgeInsets.all(16.0), 
        decoration: BoxDecoration( 
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(4.0), 
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 2.0,
              offset: const Offset(0, 1),
            )
          ]
        ),
        child: Center(
          child: Text('記録されたログはありません。', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
        ),
      );
    }

    return Container( 
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0), 
      padding: const EdgeInsets.all(16.0), 
      child: SizedBox( 
        height: chartHeight, 
        child: Stack(
          children: [
            ...gridLines,
            Row(
              crossAxisAlignment: CrossAxisAlignment.end, 
              children: chartItems,
            ),
          ],
        ),
      ),
    );
  }
}
