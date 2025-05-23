import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// 共通のメモ入力と色ラベル選択フィールドを構築するプライベート関数
Widget _buildSharedLogInputFields({
  required BuildContext context,
  required TextEditingController memoController,
  required String selectedColorLabel,
  required Function(String?) onColorLabelChanged,
  required List<String> commentSuggestions,
  required String Function(String) katakanaToHiraganaConverter,
  required Map<String, Color> availableColorLabels,
  required bool autofocusMemoField,
}) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Autocomplete<String>(
        // Autocompleteの初期値をmemoControllerの現在のテキストで設定
        initialValue: TextEditingValue(text: memoController.text),
        optionsBuilder: (TextEditingValue textEditingValue) {
          final String query = textEditingValue.text;
          // 入力が1文字～3文字の場合のみサジェスト（前方完全一致）を表示
          // ignore: prefer_is_empty
          if (query.length >= 1 && query.length <= 3) {
            final String normalizedQuery = katakanaToHiraganaConverter(query.toLowerCase());
            final Iterable<String> filteredSuggestions = commentSuggestions.where((String option) {
              final String normalizedOption = katakanaToHiraganaConverter(option.toLowerCase());
              final bool isMatch = normalizedOption.startsWith(normalizedQuery);
              return isMatch;
            });
            return filteredSuggestions;
          } else {
            // それ以外の場合は空のIterableを返す
            return const Iterable<String>.empty();
          }
        },
        onSelected: (String selection) {
          memoController.text = selection;
          memoController.selection = TextSelection.fromPosition(
              TextPosition(offset: memoController.text.length));
        },
        fieldViewBuilder: (BuildContext context,
            TextEditingController
                fieldTextEditingController, // Autocompleteが内部で管理するコントローラ
            FocusNode fieldFocusNode, // Autocompleteが内部で管理するFocusNode
            VoidCallback onFieldSubmitted) {
          return TextField(
            controller: fieldTextEditingController, // Autocompleteのコントローラを使用
            focusNode: fieldFocusNode, // AutocompleteのFocusNodeを使用
            autofocus: autofocusMemoField,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'COMMENT',
              hintText: 'コメントを入力',
            ),
            maxLines: 1,
            keyboardType: TextInputType.text,
            inputFormatters: [
              FilteringTextInputFormatter.deny(RegExp(r'[\n\r]')),
            ],
            onChanged: (text) {
              memoController.text = text;
            },
            onSubmitted: (_) {
              onFieldSubmitted();
            },
          );
        },
        optionsViewBuilder: (BuildContext context,
            AutocompleteOnSelected<String> onSelected,
            Iterable<String> options) {
          // サジェスト候補がない、かつテキストフィールドにフォーカスがある場合は何も表示しない
          // ただし、入力が空で全てのサジェストを表示する場合はこの条件に合致させない
          if (options.isEmpty &&
              FocusScope.of(context).hasFocus &&
              memoController.text.isNotEmpty) {
            return const SizedBox.shrink();
          }
          return Align(
            alignment: Alignment.topLeft,
            child: Material(
              child: ConstrainedBox(
                // サジェストボックスの最大幅をダイアログ幅の80%からパディング分を引いた値に調整
                constraints: BoxConstraints(
                    maxHeight: 200,
                    maxWidth: MediaQuery.of(context).size.width * 0.8 - 48),
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: options.length,
                  itemBuilder: (BuildContext context, int index) {
                    final String option = options.elementAt(index);
                    return InkWell(
                      onTap: () => onSelected(option),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(option),
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
      const SizedBox(height: 20),
      Wrap(
        spacing: 8.0,
        runSpacing: 8.0,
        children: availableColorLabels.keys.map((String labelName) {
          final bool isSelected = labelName == selectedColorLabel;
          // availableColorLabels から Color オブジェクトを取得。存在しない場合はデフォルト色（例: Colors.grey）
          final Color labelActualColor = availableColorLabels[labelName] ?? Colors.grey;
          final Color invisibleColor = Colors.transparent; // 透明色

          // ラベルの色に基づいて選択時の文字色を決定 (暗い背景なら白文字、明るい背景なら黒文字)
          final Brightness colorBrightness = ThemeData.estimateBrightnessForColor(labelActualColor);
          final Color selectedForegroundColor = colorBrightness == Brightness.dark ? Colors.white : Colors.black;

          return SizedBox(
            child: ElevatedButton(
              onPressed: () {
                onColorLabelChanged(labelName);
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0), // 内側のパディングを調整
                backgroundColor: isSelected
                    ? labelActualColor
                    : invisibleColor,
                foregroundColor: isSelected
                    ? selectedForegroundColor
                    : labelActualColor,
                shape: RoundedRectangleBorder(
                  side: BorderSide(
                    color: labelActualColor,
                  ),
                ),
                minimumSize: const Size(0, 32),
              ),
              child: Text(
                labelName,
                textAlign: TextAlign.center, // 中央揃え
              ),
            ),
          );
        }).toList(),
      ),
    ],
  );
}

// 汎用的なログ入力ダイアログを表示するコア関数
Future<Map<String, dynamic>?> _showCoreLogInputDialog({
  required BuildContext context,
  required String dialogTitle,
  String? contentText,
  required String initialMemo,
  required String initialColorLabel,
  required List<String> commentSuggestions,
  required String Function(String) katakanaToHiraganaConverter,
  required Map<String, Color> availableColorLabels,
  required List<Widget> Function(BuildContext dialogContext,
      TextEditingController memoController, String selectedColorLabel)
      actionsBuilder,
  bool autofocusMemoField = true,
}) async {
  final TextEditingController memoController =
      TextEditingController(text: initialMemo);
  String selectedColorInDialog = initialColorLabel;

  // ダイアログ内での色ラベル選択を管理するための変数
  return await showDialog<Map<String, dynamic>?>(
    context: context,
    barrierDismissible: true, // ダイアログ外タップで閉じるのを許可
    builder: (BuildContext dialogContext) {
      // AlertDialog内で状態を管理するためにStatefulBuilderを使用
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setStateDialog) {
          return AlertDialog(
            title: Text(dialogTitle),
            insetPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0), // AlertDialog自体の左右のパディングを調整して、表示領域を広げる
            content: SizedBox(
              width: MediaQuery.of(dialogContext).size.width, // 利用可能な最大幅を指定
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (contentText != null && contentText.isNotEmpty) ...[
                      Text(contentText,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                    ],
                    _buildSharedLogInputFields(
                      context: dialogContext, // AlertDialogのBuildContextを渡す
                      memoController: memoController, // memoControllerを渡す
                      selectedColorLabel: selectedColorInDialog,
                      onColorLabelChanged: (String? newValue) {
                        if (newValue != null) {
                          setStateDialog(() {
                            // StatefulBuilderのsetStateを呼び出してダイアログ内のUIを更新
                            selectedColorInDialog = newValue;
                          });
                        }
                      },
                      commentSuggestions: commentSuggestions,
                      katakanaToHiraganaConverter: katakanaToHiraganaConverter,
                      availableColorLabels: availableColorLabels,
                      autofocusMemoField: autofocusMemoField,
                    ),
                  ],
                ),
              ),
            ),
            actions:
                actionsBuilder(dialogContext, memoController, selectedColorInDialog),
          );
        },
      );
    },
  );
}

// 既存のログコメントを編集するためのダイアログ
Future<Map<String, String>?> showLogCommentEditDialog({
  required BuildContext context,
  required String initialMemo,
  required String initialColorLabelName,
  required List<String> commentSuggestions,
  required String Function(String) katakanaToHiraganaConverter,
  required Map<String, Color> availableColorLabels,
}) async {
  final result = await _showCoreLogInputDialog(
    context: context,
    dialogTitle: 'ログを編集',
    initialMemo: initialMemo,
    initialColorLabel: initialColorLabelName,
    commentSuggestions: commentSuggestions,
    katakanaToHiraganaConverter: katakanaToHiraganaConverter,
    availableColorLabels: availableColorLabels,
    actionsBuilder: (dialogContext, memoCtrl, selectedColor) {
      return [
        TextButton(
          child: const Text('キャンセル'),
          onPressed: () {
            Navigator.of(dialogContext).pop(null);
          },
        ),
        ElevatedButton(
          child: const Text('保存'),
          onPressed: () {
            Navigator.of(dialogContext).pop({
              'memo': memoCtrl.text.trim(),
              'colorLabel': selectedColor,
            });
          },
        ),
      ];
    },
  );
  // _showCoreLogInputDialog はMap<String, dynamic>?を返す可能性があるため、期待する Map<String, String>? に安全に変換。
  if (result == null) return null;
  return result.map((key, value) => MapEntry(key, value as String));
}
