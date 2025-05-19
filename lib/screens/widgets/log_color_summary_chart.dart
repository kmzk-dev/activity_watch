// lib/screens/widgets/log_color_summary_chart.dart
import 'package:flutter/material.dart';
import 'dart:math';
import '../../models/log_entry.dart';
import '../../theme/color.dart'; // Ensure this path is correct for your project structure

class LogColorSummaryChart extends StatelessWidget {
  final List<LogEntry> logs;

  const LogColorSummaryChart({
    super.key,
    required this.logs,
  });

  // 各カラーラベルごとの合計継続時間を計算します。
  Map<String, Duration> _calculateColorLabelDurations() {
    final Map<String, Duration> colorDurations = {};
    // `colorLabels` マップからすべての定義済みカラーラベルを取得し、継続時間をゼロで初期化します。
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

  // セッション全体の合計継続時間を計算します。
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

    // ログがない、または合計期間が0ミリ秒の場合の処理
    if (logs.isEmpty || actualTotalSessionDuration.inMilliseconds == 0) {
      if (colorLabels.isEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              '色定義がありません', // No color definitions
              style: textTheme.bodyMedium
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ),
        );
      }
      displayColorDurations = {};
      // 変更点: ダミーデータの期間をミリ秒単位に変更
      const Duration equalShareDuration = Duration(milliseconds: 1);
      int numberOfColors = 0;
      for (var labelName in colorLabels.keys) {
        displayColorDurations[labelName] = equalShareDuration;
        numberOfColors++;
      }
      displayTotalSessionDuration = Duration(
          milliseconds: numberOfColors * equalShareDuration.inMilliseconds); // ミリ秒で計算
      if (displayTotalSessionDuration.inMilliseconds == 0 &&
          numberOfColors > 0) {
        displayTotalSessionDuration = const Duration(milliseconds: 1); // フォールバックもミリ秒
      }
    } else {
      displayColorDurations = actualColorDurations;
      displayTotalSessionDuration = actualTotalSessionDuration;
    }

    final List<MapEntry<String, Duration>> validEntries = displayColorDurations
        .entries
        .where((entry) => entry.value.inMilliseconds > 0) // ミリ秒で評価
        .toList();

    if (displayTotalSessionDuration.inMilliseconds == 0 ||
        (colorLabels.isNotEmpty &&
            validEntries.isEmpty &&
            logs.isNotEmpty)) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            '表示するデータがありません (期間0または有効なエントリなし)', // No data to display
            style: textTheme.bodyMedium
                ?.copyWith(color: colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    List<double> adjustedPercentages = [];
    if (validEntries.isNotEmpty &&
        displayTotalSessionDuration.inMilliseconds > 0) {
      List<double> rawPercentages = validEntries.map((entry) {
        return (entry.value.inMilliseconds /
                displayTotalSessionDuration.inMilliseconds) *
            100.0;
      }).toList();

      List<double> roundedPercentages = rawPercentages.map((p) {
        return (p * 10).round() / 10.0;
      }).toList();

      double sumOfRoundedPercentages =
          roundedPercentages.fold(0.0, (sum, p) => sum + p);
      sumOfRoundedPercentages = (sumOfRoundedPercentages * 10).round() / 10.0;

      double difference = 100.0 - sumOfRoundedPercentages;
      difference = (difference * 10).round() / 10.0;

      if (difference != 0.0 && roundedPercentages.isNotEmpty) {
        int indexToAdjust = -1;
        double maxRawPercentage = -1.0;

        for (int i = 0; i < rawPercentages.length; i++) {
          if (rawPercentages[i] > maxRawPercentage) {
            maxRawPercentage = rawPercentages[i];
            indexToAdjust = i;
          }
        }
        
        if (indexToAdjust != -1) {
          double currentRounded = roundedPercentages[indexToAdjust];
          double potentialAdjustedValue = currentRounded + difference;

          if (potentialAdjustedValue < 0 && currentRounded > 0) {
            // No change, keep it simple
          } else if (currentRounded == 0.0 && difference < 0) {
            // No change
          }
          else {
            roundedPercentages[indexToAdjust] = (potentialAdjustedValue * 10).round() / 10.0;
          }

          double finalSum = roundedPercentages.fold(0.0, (sum, p) => sum + p);
          finalSum = (finalSum * 10).round() / 10.0;
          double finalDifference = 100.0 - finalSum;
          finalDifference = (finalDifference * 10).round() / 10.0;

          if (finalDifference != 0.0) {
            double finalAdjustedValue = roundedPercentages[indexToAdjust] + finalDifference;
            if (!((roundedPercentages[indexToAdjust] == 0.0 && finalDifference < 0) || (finalAdjustedValue < 0 && roundedPercentages[indexToAdjust] > 0) )) {
                 roundedPercentages[indexToAdjust] = (finalAdjustedValue * 10).round() / 10.0;
            }
          }
        }
      }
      adjustedPercentages = roundedPercentages;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final double availableHeight = constraints.maxHeight;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Expanded(
                flex: 2,
                child: Container(
                  height: availableHeight,
                  child: ListView.builder(
                    itemCount: validEntries.length,
                    itemBuilder: (context, index) {
                      final entry = validEntries[index];
                      final String labelName = entry.key;
                      final Color color =
                          colorLabels[labelName] ?? Colors.grey;

                      final String percentageText = (adjustedPercentages.isNotEmpty &&
                              index < adjustedPercentages.length)
                          ? '${adjustedPercentages[index].toStringAsFixed(1)}%'
                          : '0.0%';

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.rectangle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              percentageText,
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurface,
                                fontSize: 11,
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
              Expanded(
                flex: 3,
                child: Container(
                  height: availableHeight,
                  child: LayoutBuilder(
                    builder: (context, chartConstraints) {
                      final double chartDiameter = min(
                          chartConstraints.maxWidth, chartConstraints.maxHeight);
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
    if (totalDuration.inMilliseconds == 0) return;

    double startAngle = -pi / 2;

    final Paint sectionPaint = Paint()..style = PaintingStyle.fill;
    final Rect rect = Rect.fromLTWH(0, 0, size.width, size.height);

    colorDurations.forEach((labelName, duration) {
      if (duration.inMilliseconds > 0) {
        final double sweepAngle =
            (duration.inMilliseconds / totalDuration.inMilliseconds) * 2 * pi;
        sectionPaint.color =
            colorMapping[labelName] ?? Colors.grey;
        canvas.drawArc(rect, startAngle, sweepAngle, true, sectionPaint);
        startAngle += sweepAngle;
      }
    });

    if (holeRadiusRatio > 0.0 && holeRadiusRatio < 1.0) {
      final double holeRadius = (size.width / 2) * holeRadiusRatio;
      if (holeRadius > 0) {
        final Paint holePaint = Paint()..color = backgroundColor;
        canvas.drawCircle(
            Offset(size.width / 2, size.height / 2), holeRadius, holePaint);
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
