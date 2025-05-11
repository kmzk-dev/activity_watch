// lib/screens/widgets/timer_display.dart
import 'package:flutter/material.dart';

class TimerDisplay extends StatelessWidget {
  final String elapsedTime; // 表示する経過時間 (HH:MM:SS:MS形式)

  const TimerDisplay({
    super.key,
    required this.elapsedTime,
  });

  @override
  Widget build(BuildContext context) {
    // elapsedTime 文字列を時分秒部分とミリ秒部分に分割
    // elapsedTime が "00:00:00:00" のような形式であることを前提とします。
    String mainTime = '00:00:00';
    String milliseconds = '00';

    if (elapsedTime.contains(':')) {
      int lastColonIndex = elapsedTime.lastIndexOf(':');
      if (lastColonIndex > 0 && lastColonIndex < elapsedTime.length - 1) {
        mainTime = elapsedTime.substring(0, lastColonIndex);
        milliseconds = elapsedTime.substring(lastColonIndex + 1);
      }
    }

    // ステータスバーの高さを取得
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    // 上部のパディング値を定義
    final double topPadding = statusBarHeight + 30.0;
    // 下部のパディング値を上部パディングの3/4に設定
    final double bottomPadding = topPadding * 0.35;

    return Container(
      // 上部と下部のパディングを個別に設定
      padding: EdgeInsets.only(
        top: topPadding,
        bottom: bottomPadding,
        left: 20.0, // 左右のパディングは変更なし
        right: 20.0, // 左右のパディングは変更なし
      ),
      decoration: BoxDecoration(
        color: Colors.grey[850], // 画像に近い濃いグレー
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(25.0),
          bottomRight: Radius.circular(25.0),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            mainTime,
            style: const TextStyle(
              fontSize: 64.0,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4.0, bottom: 4.0),
            child: Text(
              '.$milliseconds',
              style: TextStyle(
                fontSize: 22.0,
                fontWeight: FontWeight.w600,
                color: Colors.white.withOpacity(0.8),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
