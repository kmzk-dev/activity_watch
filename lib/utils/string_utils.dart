// lib/utils/string_utils.dart

// カタカナ文字列をひらがな文字列に変換します。
// 主にサジェストの大文字・小文字、全角・半角の違いを吸収するために使用されます。
String katakanaToHiragana(String katakana) {
  return katakana.replaceAllMapped(RegExp(r'[\u30A1-\u30F6]'), (match) {
    return String.fromCharCode(match.group(0)!.codeUnitAt(0) - 0x60);
  });
}
