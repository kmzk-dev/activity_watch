// lib/theme/color_constants.dart

import 'package:flutter/material.dart';

// ログのカテゴリ別ラベルカラー (既存の定義)
// こちらも新しいパレットに合わせて調整するか、既存のままにするか検討が必要です。
// 例として、一部新しいパレットの色を参照するように変更しています。
const Map<String, Color> colorLabels = {
  'dark': Color.fromARGB(255, 102, 93, 112), // デフォルトの色をパレットのParagraphに
  // 以下は従来の定義例 (必要に応じて調整)
  'fire': Color.fromARGB(255, 206, 26, 26), // より明確な赤など
  'water': Color.fromARGB(255, 88, 107, 177),
  'Earth': Color.fromARGB(255, 69, 134, 92),
  'Light': Color.fromARGB(255, 146, 125, 2),
};