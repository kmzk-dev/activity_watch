// lib/screens/widgets/log_color_summary_chart.dart
import 'package:flutter/material.dart';
import 'dart:math'; // max関数とmin関数を使用するためにインポート
import '../../models/log_entry.dart'; // LogEntryモデル
import '../../theme/color_constants.dart'; // colorLabelsを使用

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
                (colorDurations[log.colorLabelName] ?? Duration.zero) + log.duration!;
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
        Duration.zero, (previousValue, log) => previousValue + (log.duration ?? Duration.zero));
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, Duration> colorLabelDurations = _calculateColorLabelDurations();
    final Duration totalSessionDuration = _calculateTotalSessionDuration();
    final double totalSessionDurationInSeconds = totalSessionDuration.inSeconds > 0 ? totalSessionDuration.inSeconds.toDouble() : 1.0;

    const double initialMinBarHeight = 2.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double totalAvailableHeight = constraints.maxHeight;
        List<Widget> chartItems = [];

        final double widgetVerticalMargin = 8.0 * 2;
        final double heightAfterWidgetMargin = max(0, totalAvailableHeight - widgetVerticalMargin);

        final double containerInternalVerticalPadding = 8.0 * 2;
        final double stackAreaHeight = max(0, heightAfterWidgetMargin - containerInternalVerticalPadding);

        const double labelTextSize = 10.0;
        final textPainter = TextPainter(
          text: const TextSpan(text: "X", style: TextStyle(fontSize: labelTextSize)),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(minWidth: 0, maxWidth: double.infinity);
        final double actualLabelTextHeight = textPainter.size.height;

        const double paddingBelowBar = 4.0;
        final double nonBarElementsHeight = actualLabelTextHeight + paddingBelowBar;
        final double safetyBuffer = 8.0;

        final bool canShowLabelAndPadding = stackAreaHeight >= (nonBarElementsHeight + initialMinBarHeight + safetyBuffer);

        double maxBarHeight; // バーが取りうる最大の高さ
        if (canShowLabelAndPadding) {
          maxBarHeight = stackAreaHeight - nonBarElementsHeight - safetyBuffer;
        } else {
          maxBarHeight = stackAreaHeight - safetyBuffer;
        }
        maxBarHeight = max(0, maxBarHeight);

        if (logs.isEmpty) {
          colorLabels.forEach((labelName, defaultColor) {
            chartItems.add(
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      Container(
                        width: 20.0,
                        height: initialMinBarHeight, // 初期表示のバーの高さ
                        decoration: BoxDecoration(
                          color: defaultColor.withOpacity(0.5),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4.0),
                            topRight: Radius.circular(4.0),
                          ),
                        ),
                      ),
                      if (canShowLabelAndPadding) ...[
                        const SizedBox(height: paddingBelowBar),
                        Text(
                          labelName,
                          style: TextStyle(fontSize: labelTextSize, color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7)),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ]
                    ],
                  ),
                ),
              ),
            );
          });
        } else {
          colorLabels.forEach((labelName, defaultColor) {
            final Duration duration = colorLabelDurations[labelName] ?? Duration.zero;
            final Color barColor = defaultColor;

            final double barHeightRatio = totalSessionDurationInSeconds > 0 && duration.inSeconds > 0
                ? (duration.inSeconds / totalSessionDurationInSeconds)
                : 0.0;

            double finalBarHeight = maxBarHeight * barHeightRatio;

            if (duration.inSeconds > 0 && finalBarHeight < initialMinBarHeight && maxBarHeight >= initialMinBarHeight) {
              finalBarHeight = initialMinBarHeight;
            } else if (duration.inSeconds == 0 && logs.isNotEmpty) {
                 finalBarHeight = 0;
            }
            finalBarHeight = max(0, min(finalBarHeight, maxBarHeight));

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
                      if (canShowLabelAndPadding) ...[
                        const SizedBox(height: paddingBelowBar),
                        Text(
                          labelName,
                          style: TextStyle(fontSize: labelTextSize, color: Theme.of(context).textTheme.bodySmall?.color),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ]
                    ],
                  ),
                ),
              ),
            );
          });
        }

        List<Widget> gridLines = [];
        // --- 罫線描画ロジックの修正 ---
        double gridLineDrawingAreaHeight; // 実際に罫線を描画する高さの範囲
        double gridLineBottomOffsetAnchor;  // 罫線のbottomオフセットの基準点 (0 またはラベル等の高さ)

        if (canShowLabelAndPadding) {
            // ラベル等が表示される場合、罫線はその上に描画される
            gridLineDrawingAreaHeight = stackAreaHeight - nonBarElementsHeight - safetyBuffer;
            gridLineBottomOffsetAnchor = nonBarElementsHeight;
        } else {
            // ラベル等が表示されない場合、罫線はstackArea全体に対して描画される
            gridLineDrawingAreaHeight = stackAreaHeight - safetyBuffer;
            gridLineBottomOffsetAnchor = 0;
        }
        gridLineDrawingAreaHeight = max(0, gridLineDrawingAreaHeight); // 0未満にならないように

        // gridLineDrawingAreaHeight が非常に小さい場合でも罫線が最低限見えるように調整
        if (gridLineDrawingAreaHeight < 4.0 && stackAreaHeight > safetyBuffer + 4.0) { // 4分割するには最低4pxは欲しい
             gridLineDrawingAreaHeight = 4.0; // 最小でも4pxのエリアで分割を試みる
        }


        if (gridLineDrawingAreaHeight > 1.0) { // 1ピクセル以上の描画領域がある場合のみ罫線を描画
            for (int i = 0; i <= 4; i++) { // 0%, 25%, 50%, 75%, 100% の位置に罫線
                double relativeOffset = (gridLineDrawingAreaHeight / 4) * i;
                double bottomOffset = gridLineBottomOffsetAnchor + relativeOffset;

                // 罫線が描画領域内に収まるように最終調整
                // safetyBuffer を考慮し、stackAreaHeight を超えないようにする
                if (bottomOffset <= stackAreaHeight - safetyBuffer + 0.5 && bottomOffset >= gridLineBottomOffsetAnchor -0.5) { // 0.5は描画の誤差許容
                    gridLines.add(
                        Positioned(
                        bottom: bottomOffset,
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
        }

        return Container(
          margin: EdgeInsets.symmetric(horizontal: 16.0, vertical: widgetVerticalMargin / 2),
          padding: EdgeInsets.all(containerInternalVerticalPadding / 2),
          child: Stack(
            children: [
              ...gridLines,
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: chartItems,
              ),
            ],
          ),
        );
      },
    );
  }
}
