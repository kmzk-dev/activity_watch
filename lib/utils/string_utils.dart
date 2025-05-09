// lib/utils/string_utils.dart

// カタカナ文字列をひらがな文字列に変換します。
// 主に検索時の大文字・小文字、全角・半角の違いを吸収するために使用されます。
String katakanaToHiragana(String katakana) {
  // カタカナの範囲（ァ U+30A1 から ヶ U+30F6 まで）を正規表現で検索
  return katakana.replaceAllMapped(RegExp(r'[\u30A1-\u30F6]'), (match) {
    // マッチしたカタカナの文字コードから0x60を引くことで、対応するひらがなの文字コードに変換
    return String.fromCharCode(match.group(0)!.codeUnitAt(0) - 0x60);
  });
}
