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
              // 左側: 凡例 (色付きの四角のみ)
              Expanded(
                flex: 1, // 凡例エリアの幅を少し狭く調整 (例: flex 1)
                child: Container(
                  height: availableHeight,
                  child: ListView.builder(
                    itemCount: validEntries.length,
                    itemBuilder: (context, index) {
                      final entry = validEntries[index];
                      final String labelName = entry.key; // labelName は色の取得に必要
                      final Color color = colorLabels[labelName] ?? Colors.grey;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3.0), // アイテム間の上下の余白
                        child: Row( // 中央揃えのため、Rowでラップすることも検討
                          mainAxisAlignment: MainAxisAlignment.center, // 四角を中央に
                          children: [
                            Container(
                              width: 12, // 四角の幅
                              height: 12, // 四角の高さ
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.rectangle, // または BoxShape.circle
                                // borderRadius: BorderRadius.circular(2.0), // 四角の場合
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8), // 凡例とグラフの間のスペースを少し調整

              // 右側: 円グラフ
              Expanded(
                flex: 4, // グラフエリアの幅を少し広く調整 (例: flex 4)
                child: Container(
                  height: availableHeight,
                  child: LayoutBuilder(
                    builder: (context, chartConstraints) {
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
                              holeRadiusRatio: 0.95,
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