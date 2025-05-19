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
    // これにより、ログが存在しない場合でも、すべての定義済みラベルが凡例に表示される基盤となります。
    for (var labelName in colorLabels.keys) {
      colorDurations[labelName] = Duration.zero;
    }

    if (logs.isNotEmpty) {
      for (var log in logs) {
        // `log.duration` が null でないことを確認します。
        if (log.duration != null) {
          // `colorDurations` マップに現在のログの `colorLabelName` が存在する場合にのみ、
          // そのラベルの合計継続時間に現在のログの継続時間を加算します。
          if (colorDurations.containsKey(log.colorLabelName)) {
            colorDurations[log.colorLabelName] =
                (colorDurations[log.colorLabelName] ?? Duration.zero) +
                    log.duration!;
          } else {
            // ログに `colorLabels` で定義されていない `colorLabelName` が含まれている場合の処理。
            // 現状の実装では、定義済みのラベルが使用されることを想定しているため、
            // 未知のラベルは無視するか、デバッグ用に警告を出すなどの対応が考えられます。
            // print('Warning: Unknown colorLabelName "${log.colorLabelName}" found in logs. This log will be ignored for chart summation.');
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
    // `logs` リスト内のすべての `LogEntry` オブジェクトの `duration` を合計します。
    // `log.duration` が null の場合は `Duration.zero` として扱います。
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
    final Color chartBackgroundColor = theme.canvasColor; // チャートの背景色（ドーナツの穴の色）

    Map<String, Duration> displayColorDurations;
    Duration displayTotalSessionDuration;

    // 実際のログデータから色ごとの期間と合計期間を計算
    Map<String, Duration> actualColorDurations = _calculateColorLabelDurations();
    Duration actualTotalSessionDuration = _calculateTotalSessionDuration();

    // ログがない、または合計期間が0ミリ秒の場合の処理
    if (logs.isEmpty || actualTotalSessionDuration.inMilliseconds == 0) {
      // `colorLabels` が空の場合は、色定義がないことを示すメッセージを表示
      if (colorLabels.isEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              '色定義がありません',
              style: textTheme.bodyMedium
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ),
        );
      }
      // データがない場合、凡例に均等表示するためのダミーデータを生成
      displayColorDurations = {};
      // 0秒より大きい最小限の期間としてマイクロ秒を使用
      const Duration equalShareDuration = Duration(microseconds: 1);
      int numberOfColors = 0;
      for (var labelName in colorLabels.keys) {
        displayColorDurations[labelName] = equalShareDuration;
        numberOfColors++;
      }
      // ダミーデータの場合の合計期間 (0にならないように)
      displayTotalSessionDuration = Duration(
          microseconds: numberOfColors * equalShareDuration.inMicroseconds);
      // 合計期間が0で、かつ色が1つ以上ある場合は、フォールバックとして最小期間を設定
      if (displayTotalSessionDuration.inMicroseconds == 0 &&
          numberOfColors > 0) {
        displayTotalSessionDuration = const Duration(microseconds: 1);
      }
    } else {
      // 有効なログデータがある場合は、計算結果をそのまま使用
      displayColorDurations = actualColorDurations;
      displayTotalSessionDuration = actualTotalSessionDuration;
    }

    // 期間が0ミリ秒より大きい有効なエントリのみをフィルタリング
    final List<MapEntry<String, Duration>> validEntries = displayColorDurations
        .entries
        .where((entry) => entry.value.inMilliseconds > 0)
        .toList();

    // 表示するデータがない場合のフォールバック表示
    // (合計期間が0、または、ログはあるが全てのログの期間が0の場合など)
    if (displayTotalSessionDuration.inMilliseconds == 0 ||
        (colorLabels.isNotEmpty &&
            validEntries.isEmpty &&
            logs.isNotEmpty)) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            '表示するデータがありません (期間0または有効なエントリなし)',
            style: textTheme.bodyMedium
                ?.copyWith(color: colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // パーセンテージリストを事前に計算し、合計が100%になるように調整
    List<double> adjustedPercentages = [];
    if (validEntries.isNotEmpty &&
        displayTotalSessionDuration.inMilliseconds > 0) {
      // 1. 各エントリの生のパーセンテージをミリ秒ベースで計算
      List<double> rawPercentages = validEntries.map((entry) {
        return (entry.value.inMilliseconds /
                displayTotalSessionDuration.inMilliseconds) *
            100.0;
      }).toList();

      // 2. 生のパーセンテージを小数点以下1桁に丸める
      List<double> roundedPercentages = rawPercentages.map((p) {
        return (p * 10).round() / 10.0;
      }).toList();

      // 3. 丸めたパーセンテージの合計を計算（合計も小数点以下1桁に丸める）
      double sumOfRoundedPercentages =
          roundedPercentages.fold(0.0, (sum, p) => sum + p);
      sumOfRoundedPercentages = (sumOfRoundedPercentages * 10).round() / 10.0;

      // 4. 100%との差分を計算（差分も小数点以下1桁に丸める）
      double difference = 100.0 - sumOfRoundedPercentages;
      difference = (difference * 10).round() / 10.0;

      // 5. 差分が存在する場合、調整を行う
      if (difference != 0.0 && roundedPercentages.isNotEmpty) {
        int indexToAdjust = -1;
        double maxRawPercentage = -1.0;

        // 調整対象のインデックスを決定（元の生パーセンテージが最大の要素）
        for (int i = 0; i < rawPercentages.length; i++) {
          if (rawPercentages[i] > maxRawPercentage) {
            maxRawPercentage = rawPercentages[i];
            indexToAdjust = i;
          }
        }
        
        // 調整対象が見つかった場合
        if (indexToAdjust != -1) {
          // 調整後の値が負にならないように、かつ元の値が0の場合は差分が正の場合のみ調整
          double currentRounded = roundedPercentages[indexToAdjust];
          double potentialAdjustedValue = currentRounded + difference;

          if (potentialAdjustedValue < 0 && currentRounded > 0) {
            // 調整によって負になる場合は、0にクリップし、残りの差分は再分配しない（簡略化）
            // difference -= (0 - potentialAdjustedValue); // 実際に吸収できなかった差分
            // roundedPercentages[indexToAdjust] = 0.0;
            // より高度なロジック: 他の要素に差分を再分配するか、エラーとして扱うなど
            // 今回は、最大の要素が調整を引き受けるシンプルな方針を維持
          } else if (currentRounded == 0.0 && difference < 0) {
            // 元が0%の項目から負の差分を引くことはできないため、何もしない
          }
          else {
            roundedPercentages[indexToAdjust] = (potentialAdjustedValue * 10).round() / 10.0;
          }

          // 最終確認：浮動小数点演算の誤差により、まだ合計が100%でない場合、再度微調整
          double finalSum = roundedPercentages.fold(0.0, (sum, p) => sum + p);
          finalSum = (finalSum * 10).round() / 10.0;
          double finalDifference = 100.0 - finalSum;
          finalDifference = (finalDifference * 10).round() / 10.0;

          if (finalDifference != 0.0) {
             // 再度、最大の要素（または調整可能な別の要素）で調整
             // ここでは、前回調整した要素が引き続き調整を引き受ける
            double finalAdjustedValue = roundedPercentages[indexToAdjust] + finalDifference;
            if (!((roundedPercentages[indexToAdjust] == 0.0 && finalDifference < 0) || (finalAdjustedValue < 0 && roundedPercentages[indexToAdjust] > 0) )) {
                 roundedPercentages[indexToAdjust] = (finalAdjustedValue * 10).round() / 10.0;
            }
          }
        }
      }
      adjustedPercentages = roundedPercentages;
    }

    // UIの構築
    return LayoutBuilder(
      builder: (context, constraints) {
        final double availableHeight = constraints.maxHeight;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              // 左側: 凡例 (カラーアイコンと調整済み割合)
              Expanded(
                flex: 2, // 凡例表示エリアのフレックス比率
                child: Container(
                  height: availableHeight, // 親の高さに合わせる
                  child: ListView.builder(
                    itemCount: validEntries.length, // 有効なエントリの数
                    itemBuilder: (context, index) {
                      final entry = validEntries[index];
                      final String labelName = entry.key;
                      final Color color =
                          colorLabels[labelName] ?? Colors.grey; // 色定義から色を取得

                      // 調整済みのパーセンテージを使用、範囲外アクセスのフォールバックも考慮
                      final String percentageText = (adjustedPercentages.isNotEmpty &&
                              index < adjustedPercentages.length)
                          ? '${adjustedPercentages[index].toStringAsFixed(1)}%'
                          : '0.0%'; // フォールバック

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
                                shape: BoxShape.rectangle, // 四角いカラーアイコン
                              ),
                            ),
                            const SizedBox(width: 8), // アイコンとテキストの間隔
                            Text(
                              percentageText,
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurface,
                                fontSize: 11, // フォントサイズ調整
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8), // 凡例と円グラフの間隔
              // 右側: 円グラフ
              Expanded(
                flex: 3, // 円グラフ表示エリアのフレックス比率
                child: Container(
                  height: availableHeight, // 親の高さに合わせる
                  child: LayoutBuilder(
                    builder: (context, chartConstraints) {
                      // チャートの直径を、利用可能な幅と高さの小さい方に合わせる
                      final double chartDiameter = min(
                          chartConstraints.maxWidth, chartConstraints.maxHeight);
                      // 直径が小さすぎる場合は描画しない
                      if (chartDiameter <= 10) {
                        return const SizedBox.shrink();
                      }
                      return Center(
                        child: SizedBox(
                          width: chartDiameter,
                          height: chartDiameter,
                          child: CustomPaint(
                            painter: PieChartPainter(
                              // PieChartPainter には、調整前のオリジナルの期間データを渡す
                              // 円グラフのセグメント角度は、実際の期間比率に基づくべきため
                              colorDurations: displayColorDurations,
                              totalDuration: displayTotalSessionDuration,
                              colorMapping: colorLabels,
                              backgroundColor: chartBackgroundColor,
                              holeRadiusRatio: 0.90, // ドーナツグラフの穴の半径比率
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

// 円グラフを描画するための CustomPainter
class PieChartPainter extends CustomPainter {
  final Map<String, Duration> colorDurations; // 色ごとの期間
  final Duration totalDuration; // 合計期間
  final Map<String, Color> colorMapping; // ラベル名と色のマッピング
  final Color backgroundColor; // 背景色（ドーナツの穴の色）
  final double holeRadiusRatio; // ドーナツの穴の半径の比率 (0.0 から 1.0)

  PieChartPainter({
    required this.colorDurations,
    required this.totalDuration,
    required this.colorMapping,
    required this.backgroundColor,
    this.holeRadiusRatio = 0.9, // デフォルト値を設定
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 合計期間が0ミリ秒の場合は何も描画しない
    if (totalDuration.inMilliseconds == 0) return;

    double startAngle = -pi / 2; // グラフの開始角度 (12時の方向)

    final Paint sectionPaint = Paint()..style = PaintingStyle.fill;
    // 描画領域の矩形
    final Rect rect = Rect.fromLTWH(0, 0, size.width, size.height);

    // 色ごとの期間データを反復処理して、円グラフのセグメントを描画
    colorDurations.forEach((labelName, duration) {
      // 期間が0ミリ秒より大きい場合のみ描画
      if (duration.inMilliseconds > 0) {
        // ミリ秒単位でスイープ角度（セグメントの角度）を計算
        final double sweepAngle =
            (duration.inMilliseconds / totalDuration.inMilliseconds) * 2 * pi;
        sectionPaint.color =
            colorMapping[labelName] ?? Colors.grey; // 色マッピングから色を取得
        canvas.drawArc(rect, startAngle, sweepAngle, true, sectionPaint);
        startAngle += sweepAngle; // 次のセグメントの開始角度を更新
      }
    });

    // ドーナツグラフの内側の円（穴）を描画
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
    // 描画に関連するプロパティが変更された場合にのみ再描画
    return oldDelegate.colorDurations != colorDurations ||
        oldDelegate.totalDuration != totalDuration ||
        oldDelegate.colorMapping != colorMapping ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.holeRadiusRatio != holeRadiusRatio;
  }
}
