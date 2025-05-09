import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For FilteringTextInputFormatter
//import 'package:flutter/scheduler.dart'; // SchedulerPhase のために追加

// 共通のメモ入力と色ラベル選択フィールドを構築するプライベート関数
Widget _buildSharedLogInputFields({
  required BuildContext context,
  required TextEditingController memoController, // ダイアログの最終的な値を保持するコントローラ
  // required FocusNode memoFocusNode, // Autocomplete内部のFocusNodeを使用するため不要に
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
          // print('Autocomplete optionsBuilder triggered. Query: "$query"');
          // print('Available commentSuggestions: $commentSuggestions');

          if (query.isEmpty) {
            // print('Query is empty, returning empty suggestions.');
            return const Iterable<String>.empty();
          }
          
          final String normalizedQuery = katakanaToHiraganaConverter(query.toLowerCase());
          // print('Normalized query: "$normalizedQuery"');

          final Iterable<String> filteredSuggestions = commentSuggestions.where((String option) {
            final String normalizedOption = katakanaToHiraganaConverter(option.toLowerCase());
            final bool isMatch = normalizedOption.contains(normalizedQuery);
            // print('Comparing: NormalizedOption "$normalizedOption" with NormalizedQuery "$normalizedQuery" -> Match: $isMatch');
            return isMatch;
          });

          // print('Filtered suggestions: ${filteredSuggestions.toList()}');
          return filteredSuggestions;
        },
        onSelected: (String selection) {
          memoController.text = selection;
          memoController.selection = TextSelection.fromPosition(
              TextPosition(offset: memoController.text.length));
        },
        fieldViewBuilder: (BuildContext context,
            TextEditingController fieldTextEditingController, // Autocompleteが内部で管理するコントローラ
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
        optionsViewBuilder: (BuildContext context, AutocompleteOnSelected<String> onSelected, Iterable<String> options) {
          if (options.isEmpty && FocusScope.of(context).hasFocus) { 
             return const SizedBox.shrink(); 
          }
          return Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 4.0,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: 200, maxWidth: MediaQuery.of(context).size.width * 0.8 - 48),
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
      const Text(
        '色ラベル:',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8.0, 
        runSpacing: 8.0, 
        children: availableColorLabels.keys.map((String labelName) {
          final bool isSelected = labelName == selectedColorLabel;
          final Color labelActualColor = availableColorLabels[labelName] ?? Colors.grey; 

          final Brightness colorBrightness = ThemeData.estimateBrightnessForColor(labelActualColor);
          final Color selectedForegroundColor = colorBrightness == Brightness.dark ? Colors.white : Colors.black;
          
          return SizedBox(
            width: 85.0, 
            child: ElevatedButton(
              onPressed: () {
                onColorLabelChanged(labelName);
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0), 
                backgroundColor: isSelected ? labelActualColor : Colors.transparent, 
                foregroundColor: isSelected ? selectedForegroundColor : labelActualColor, 
                elevation: isSelected ? 2.0 : 0.0, 
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.0), 
                  side: BorderSide(
                    color: labelActualColor, 
                    width: 1.5, 
                  ),
                ),
                minimumSize: const Size(0, 32), 
              ),
              child: Text( 
                labelName,
                style: const TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis, 
                textAlign: TextAlign.center, 
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
  required List<Widget> Function(
    BuildContext dialogContext, 
    TextEditingController memoController, 
    String selectedColorLabel
  ) actionsBuilder,
  bool autofocusMemoField = true,
}) async {
  final TextEditingController memoController = TextEditingController(text: initialMemo);
  String selectedColorInDialog = initialColorLabel;

  return await showDialog<Map<String, dynamic>?>(
    context: context,
    barrierDismissible: true,
    builder: (BuildContext dialogContext) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setStateDialog) {
          return AlertDialog(
            title: Text(dialogTitle),
            contentPadding: const EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 0),
            content: SizedBox(
              width: MediaQuery.of(dialogContext).size.width * 0.8,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (contentText != null && contentText.isNotEmpty) ...[
                      Text(contentText, style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                    ],
                    _buildSharedLogInputFields(
                      context: dialogContext, 
                      memoController: memoController, 
                      // memoFocusNode: FocusNode(), // この行を削除
                      selectedColorLabel: selectedColorInDialog,
                      onColorLabelChanged: (String? newValue) {
                        if (newValue != null) {
                          setStateDialog(() {
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
            actionsPadding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            actions: actionsBuilder(dialogContext, memoController, selectedColorInDialog),
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
    dialogTitle: 'コメント編集',
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
  if (result == null) return null;
  return result.map((key, value) => MapEntry(key, value as String));
}

// 新しいログを追加するためのダイアログ
Future<Map<String, dynamic>?> showAddNewLogDialog({
  required BuildContext context,
  required String timeForLogDialog,
  required List<String> commentSuggestions,
  required String Function(String) katakanaToHiraganaConverter,
  required Map<String, Color> availableColorLabels,
  required String initialSelectedColorLabel,
}) async {
  return await _showCoreLogInputDialog(
    context: context,
    dialogTitle: 'ログ記録', 
    contentText: 'LOGGING TIME: $timeForLogDialog',
    initialMemo: '', 
    initialColorLabel: initialSelectedColorLabel,
    commentSuggestions: commentSuggestions,
    katakanaToHiraganaConverter: katakanaToHiraganaConverter,
    availableColorLabels: availableColorLabels,
    actionsBuilder: (dialogContext, memoCtrl, selectedColor) {
      return [
        Tooltip(
          message: '終了して記録',
          child: IconButton(
            icon: const Icon(Icons.stop_circle, color: Colors.redAccent, size: 28),
            onPressed: () {
              String memo = memoCtrl.text.trim();
              if (memo.isEmpty) memo = '(活動終了)';
              Navigator.of(dialogContext).pop({
                'action': 'stop',
                'memo': memo,
                'colorLabel': selectedColor,
              });
            },
          ),
        ),
        const Spacer(),
        Tooltip(
          message: '保存して記録を続ける',
          child: IconButton(
            icon: Icon(Icons.edit_note, color: Theme.of(dialogContext).colorScheme.primary, size: 28),
            onPressed: () {
              String memo = memoCtrl.text.trim();
              if (memo.isEmpty) memo = '(ラップを記録)';
              Navigator.of(dialogContext).pop({
                'action': 'lap',
                'memo': memo,
                'colorLabel': selectedColor,
              });
            },
          ),
        ),
      ];
    },
  );
}
