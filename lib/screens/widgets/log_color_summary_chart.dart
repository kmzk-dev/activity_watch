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
    // colorLabels からキーを取得して初期化
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
    final ThemeData theme = Theme.of(context); // テーマを取得
    final ColorScheme colorScheme = theme.colorScheme; // カラーキームを取得
    final TextTheme textTheme = theme.textTheme; // テキストテーマを取得

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
          text: TextSpan(text: "X", style: TextStyle(fontSize: labelTextSize, color: textTheme.bodySmall?.color)),
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
          // colorLabels はユーザー定義の色なので、そのまま使用
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
                          // 修正: ログがない場合のバーの色。テーマのアクセントカラーや無効化された色などを検討
                          // defaultColor は colorLabels からの色なので、ここではそれを薄くして使用。
                          // よりテーマに合わせるなら、colorScheme.surfaceVariant や theme.disabledColor などを使用。
                          color: defaultColor.withAlpha((255 * 0.3).round()), // ★修正: withOpacity(0.3) から変更 (alpha: 77)
                          // color: colorScheme.surfaceVariant.withAlpha((255 * 0.5).round()), // テーマに合わせた代替案 (alpha: 128)
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
                          style: TextStyle(
                            fontSize: labelTextSize,
                            // 修正: ログがない場合のラベルテキストの色。textThemeの補助的な色を使用。
                            color: textTheme.bodySmall?.color?.withAlpha((255 * 0.7).round()) ?? colorScheme.onSurface.withAlpha((255 * 0.7).round()), // ★修正: withOpacity(0.7) から変更 (alpha: 179)
                          ),
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
          // colorLabels はユーザー定義の色なので、そのまま使用
          colorLabels.forEach((labelName, defaultColor) {
            final Duration duration = colorLabelDurations[labelName] ?? Duration.zero;
            // barColor は colorLabels からの色なので、そのまま使用
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
                          color: barColor, // colorLabels の色をそのまま使用
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
                          style: TextStyle(
                            fontSize: labelTextSize,
                            // 修正: ログがある場合のラベルテキストの色。textTheme の標準的な色を使用。
                            color: textTheme.bodySmall?.color ?? colorScheme.onSurface,
                          ),
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
        // --- 罫線描画ロジック ---
        double gridLineDrawingAreaHeight;
        double gridLineBottomOffsetAnchor;

        if (canShowLabelAndPadding) {
            gridLineDrawingAreaHeight = stackAreaHeight - nonBarElementsHeight - safetyBuffer;
            gridLineBottomOffsetAnchor = nonBarElementsHeight;
        } else {
            gridLineDrawingAreaHeight = stackAreaHeight - safetyBuffer;
            gridLineBottomOffsetAnchor = 0;
        }
        gridLineDrawingAreaHeight = max(0, gridLineDrawingAreaHeight);

        if (gridLineDrawingAreaHeight < 4.0 && stackAreaHeight > safetyBuffer + 4.0) {
             gridLineDrawingAreaHeight = 4.0;
        }

        if (gridLineDrawingAreaHeight > 1.0) {
            for (int i = 0; i <= 4; i++) {
                double relativeOffset = (gridLineDrawingAreaHeight / 4) * i;
                double bottomOffset = gridLineBottomOffsetAnchor + relativeOffset;

                if (bottomOffset <= stackAreaHeight - safetyBuffer + 0.5 && bottomOffset >= gridLineBottomOffsetAnchor -0.5) {
                    gridLines.add(
                        Positioned(
                        bottom: bottomOffset,
                        left: 0,
                        right: 0,
                        child: Container(
                            height: 1.0,
                            // 修正: 罫線の色。テーマの区切り線色 (dividerColor) や薄いグレーを使用。
                            color: theme.dividerColor.withAlpha((255 * 0.5).round()), // ★修正: withOpacity(0.5) から変更 (alpha: 128)
                            // color: Colors.grey[300], // 修正前: ハードコードされたグレー
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