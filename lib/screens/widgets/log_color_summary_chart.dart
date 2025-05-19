// lib/screens/widgets/log_color_summary_chart.dart
import 'package:flutter/material.dart';
import 'dart:math';
import '../../models/log_entry.dart';
import '../../theme/color_constants.dart';

class LogColorSummaryChart extends StatelessWidget {
  final List<LogEntry> logs;

  const LogColorSummaryChart({
    super.key,
    required this.logs,
  });

  Map<String, Duration> _calculateColorLabelDurations() {
    // ... (既存のコード)
    final Map<String, Duration> colorDurations = {};
    for (var labelName in colorLabels.keys) {
      colorDurations[labelName] = Duration.zero;
    }
    if (logs.isNotEmpty) {
      for (var log in logs) {
        if (log.duration != null) {
          if (colorDurations.containsKey(log.colorLabelName)) {
            colorDurations[log.colorLabelName] =
                (colorDurations[log.colorLabelName] ?? Duration.zero) +
                    log.duration!;
          }
        }
      }
    }
    return colorDurations;
  }

  Duration _calculateTotalSessionDuration() {
    // ... (既存のコード)
    if (logs.isEmpty) {
      return Duration.zero;
    }
    return logs.fold(
        Duration.zero,
        (previousValue, log) =>
            previousValue + (log.duration ?? Duration.zero));
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;
    final Color chartBackgroundColor = theme.canvasColor;

    Map<String, Duration> displayColorDurations;
    Duration displayTotalSessionDuration;

    Map<String, Duration> actualColorDurations = _calculateColorLabelDurations();
    Duration actualTotalSessionDuration = _calculateTotalSessionDuration();

    if (logs.isEmpty || actualTotalSessionDuration.inSeconds == 0) {
      // ... (既存のデータなしの場合の処理)
      if (colorLabels.isEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              '色定義がありません',
              style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ),
        );
      }
      displayColorDurations = {};
      const Duration equalShareDuration = Duration(seconds: 1);
      int numberOfColors = 0;
      for (var labelName in colorLabels.keys) {
        displayColorDurations[labelName] = equalShareDuration;
        numberOfColors++;
      }
      displayTotalSessionDuration = Duration(seconds: numberOfColors * equalShareDuration.inSeconds);
      if (displayTotalSessionDuration.inSeconds == 0 && numberOfColors > 0) {
          displayTotalSessionDuration = const Duration(seconds: 1);
      }
    } else {
      displayColorDurations = actualColorDurations;
      displayTotalSessionDuration = actualTotalSessionDuration;
    }

    final List<MapEntry<String, Duration>> validEntries = displayColorDurations
        .entries
        .where((entry) => entry.value.inSeconds > 0)
        .toList();

    if (displayTotalSessionDuration.inSeconds == 0 || (colorLabels.isNotEmpty && validEntries.isEmpty)) {
      // ... (既存の表示データなしの場合の処理)
       return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            '表示するデータがありません (期間0またはエントリなし)',
            style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final double availableHeight = constraints.maxHeight;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              // 左側: 凡例 (カラーアイコンと割合)
              Expanded(
                // flex: 1 から flex: 2 に変更して少し幅を広げる (割合表示のため)
                flex: 2,
                child: Container(
                  height: availableHeight,
                  child: ListView.builder(
                    itemCount: validEntries.length,
                    itemBuilder: (context, index) {
                      final entry = validEntries[index];
                      final String labelName = entry.key;
                      final Duration duration = entry.value;
                      final Color color = colorLabels[labelName] ?? Colors.grey;

                      // 割合を計算
                      final double percentage = displayTotalSessionDuration.inSeconds > 0
                          ? (duration.inSeconds / displayTotalSessionDuration.inSeconds) * 100
                          : 0.0;
                      // 小数点以下1桁で表示 (例: 25.3%)
                      final String percentageText = '${percentage.toStringAsFixed(1)}%';

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0), // 少し余白を調整
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start, // 左寄せに変更
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.rectangle,
                              ),
                            ),
                            const SizedBox(width: 8), // アイコンとテキストの間のスペース
                            Text(
                              percentageText,
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurface,
                                fontSize: 11, // フォントサイズを少し小さく調整
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // 右側: 円グラフ
              Expanded(
                // flex: 4 から flex: 3 に変更してバランスを取る
                flex: 3,
                child: Container(
                  height: availableHeight,
                  child: LayoutBuilder(
                    builder: (context, chartConstraints) {
                      // ... (既存の円グラフ描画ロジック)
                      final double chartDiameter = min(chartConstraints.maxWidth, chartConstraints.maxHeight);
                      if (chartDiameter <= 10) {
                        return const SizedBox.shrink();
                      }
                      return Center(
                        child: SizedBox(
                          width: chartDiameter,
                          height: chartDiameter,
                          child: CustomPaint(
                            painter: PieChartPainter(
                              colorDurations: displayColorDurations,
                              totalDuration: displayTotalSessionDuration,
                              colorMapping: colorLabels,
                              backgroundColor: chartBackgroundColor,
                              holeRadiusRatio: 0.90,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class PieChartPainter extends CustomPainter {
  // ... (PieChartPainter の既存のコードは変更なし)
  final Map<String, Duration> colorDurations;
  final Duration totalDuration;
  final Map<String, Color> colorMapping;
  final Color backgroundColor;
  final double holeRadiusRatio;

  PieChartPainter({
    required this.colorDurations,
    required this.totalDuration,
    required this.colorMapping,
    required this.backgroundColor,
    this.holeRadiusRatio = 0.9,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (totalDuration.inSeconds == 0) return;

    double startAngle = -pi / 2;

    final Paint sectionPaint = Paint()..style = PaintingStyle.fill;
    final Rect rect = Rect.fromLTWH(0, 0, size.width, size.height);

    colorDurations.forEach((labelName, duration) {
      if (duration.inSeconds > 0) {
        final double sweepAngle = (duration.inSeconds / totalDuration.inSeconds) * 2 * pi;
        sectionPaint.color = colorMapping[labelName] ?? Colors.grey;
        canvas.drawArc(rect, startAngle, sweepAngle, true, sectionPaint);
        startAngle += sweepAngle;
      }
    });

    if (holeRadiusRatio > 0.0 && holeRadiusRatio < 1.0) {
      final double holeRadius = (size.width / 2) * holeRadiusRatio;
      if (holeRadius > 0) {
        final Paint holePaint = Paint()..color = backgroundColor;
        canvas.drawCircle(Offset(size.width / 2, size.height / 2), holeRadius, holePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant PieChartPainter oldDelegate) {
    return oldDelegate.colorDurations != colorDurations ||
           oldDelegate.totalDuration != totalDuration ||
           oldDelegate.colorMapping != colorMapping ||
           oldDelegate.backgroundColor != backgroundColor ||
           oldDelegate.holeRadiusRatio != holeRadiusRatio;
  }
}