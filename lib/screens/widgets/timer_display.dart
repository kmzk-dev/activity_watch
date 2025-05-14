// lib/screens/widgets/timer_display.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/scale.dart';

class TimerDisplay extends StatelessWidget {
  final String elapsedTime; // 表示する経過時間 (HH:MM:SS:MS形式)

  const TimerDisplay({
    super.key,
    required this.elapsedTime,
  });

  @override
  Widget build(BuildContext context) {
    // elapsedTime 文字列を時分秒部分とミリ秒部分に分割 00:00:00:00" のような形式であることを前提
    String mainTime = '00:00:00';
    String milliseconds = '00';
    // 文字列を ':' で分割して、hh:mm:ssとmsに再構築
    if (elapsedTime.contains(':')) {
      int lastColonIndex = elapsedTime.lastIndexOf(':');
      if (lastColonIndex > 0 && lastColonIndex < elapsedTime.length - 1) {
        mainTime = elapsedTime.substring(0, lastColonIndex);
        milliseconds = elapsedTime.substring(lastColonIndex + 1);
      }
    }

    // --- フォントサイズ計算ロジック ---
    // mainTime:画面幅の18%を基本とし、最小40px, 最大80px に制限
    final screenWidth = MediaQuery.of(context).size.width;
    final double mainTimeFontSize = (screenWidth * 0.15).clamp(40.0, 80.0);
    // milliseconds:mainTimeFontSize の約40% (0.4倍) を基本とし、最小18px, 最大36px に制限
    final double millisecondsFontSize = (mainTimeFontSize * 0.4).clamp(18.0, 36.0);

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.top,// ステータスバーの高さをbottomに追加
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withAlpha(Scale.alpha50),
            width: Scale.bordersizetin, 
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            mainTime,
            style: GoogleFonts.shareTech(
              fontSize: mainTimeFontSize,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          Text(
            '.$milliseconds',
            style: GoogleFonts.shareTech(
              fontSize: millisecondsFontSize,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ]
      ),
    );
  }
}
