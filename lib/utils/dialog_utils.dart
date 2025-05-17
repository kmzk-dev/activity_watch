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

          if (query.length >= 1 && query.length <= 3) {
            // 入力が空白の場合、全てのサジェスト候補を表示する
            final String normalizedQuery = katakanaToHiraganaConverter(query.toLowerCase());
            final Iterable<String> filteredSuggestions = commentSuggestions.where((String option) {
              final String normalizedOption = katakanaToHiraganaConverter(option.toLowerCase());
              final bool isMatch = normalizedOption.startsWith(normalizedQuery); // 前方一致でフィルタリング
              // print('Comparing: NormalizedOption "$normalizedOption" with NormalizedQuery "$normalizedQuery" -> Match: $isMatch');
              return isMatch;
            });
            return filteredSuggestions;
          } else {
            // サジェストを表示しない
            // print('Query is 3 or more characters, returning empty suggestions.');
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
              // AutocompleteのfieldViewBuilder内でmemoControllerを直接更新する代わりに、
              // AutocompleteのonSelectedや、このTextFieldのonSubmitted/onChangedで
              // 最終的な値をmemoControllerに反映する。
              // ここでは、ユーザーが入力するたびにmemoControllerにも反映させる。
              memoController.text = text;
            },
            onSubmitted: (_) {
              // AutocompleteのonFieldSubmittedを呼び出して、
              // 選択肢がない場合やEnterキーでのサブミットを処理
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
              elevation: 4.0,
              child: ConstrainedBox(
                // サジェストボックスの最大幅をダイアログ幅の80%からパディング分を引いた値に調整
                // maxWidth: MediaQuery.of(context).size.width * 0.8 - 48, // dialogContextではなくcontextを使用
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
      const Text(
        '色ラベル:',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8.0, // 横方向のスペース
        runSpacing: 8.0, // 縦方向のスペース（折り返し時）
        children: availableColorLabels.keys.map((String labelName) {
          final bool isSelected = labelName == selectedColorLabel;
          // availableColorLabels から Color オブジェクトを取得。存在しない場合はデフォルト色（例: Colors.grey）
          final Color labelActualColor =
              availableColorLabels[labelName] ?? Colors.grey;

          // ラベルの色に基づいて選択時の文字色を決定 (暗い背景なら白文字、明るい背景なら黒文字)
          final Brightness colorBrightness =
              ThemeData.estimateBrightnessForColor(labelActualColor);
          final Color selectedForegroundColor =
              colorBrightness == Brightness.dark ? Colors.white : Colors.black;

          return SizedBox(
            width: 85.0, // ボタンの幅を固定または適切に調整
            child: ElevatedButton(
              onPressed: () {
                onColorLabelChanged(labelName);
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8.0, vertical: 8.0), // 内側のパディングを調整
                backgroundColor: isSelected
                    ? labelActualColor
                    : Colors.transparent, // 選択時は背景色、非選択時は透明
                foregroundColor: isSelected
                    ? selectedForegroundColor
                    : labelActualColor, // 選択時は計算された文字色、非選択時はラベル色
                elevation: isSelected ? 2.0 : 0.0, // 選択されている場合は少し浮かせる
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.0), // 角丸の半径
                  side: BorderSide(
                    color: labelActualColor, // 枠線の色をラベルの色に
                    width: 1.5, // 枠線の太さ
                  ),
                ),
                minimumSize: const Size(0, 32), // ボタンの最小サイズを調整
              ),
              child: Text(
                // ラベル名が長い場合に省略表示
                labelName,
                style: const TextStyle(fontSize: 13), // フォントサイズを少し小さく
                overflow: TextOverflow.ellipsis, // はみ出したテキストを省略記号で表示
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
  bool autofocusMemoField = true, // メモフィールドに自動フォーカスするかのフラグ
}) async {
  final TextEditingController memoController =
      TextEditingController(text: initialMemo);
  String selectedColorInDialog = initialColorLabel;
  // final FocusNode memoFocusNode = FocusNode(); // フォーカスノードを作成

  // WidgetsBinding.instance.addPostFrameCallback((_) {
  //   if (autofocusMemoField) {
  //     // memoFocusNode.requestFocus();
  //   }
  // });

  return await showDialog<Map<String, dynamic>?>(
    context: context,
    barrierDismissible: true, // ダイアログ外タップで閉じるのを許可
    builder: (BuildContext dialogContext) {
      // AlertDialog内で状態を管理するためにStatefulBuilderを使用
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setStateDialog) {
          return AlertDialog(
            title: Text(dialogTitle),
            // AlertDialog自体の左右のパディングを調整して、表示領域を広げる
            insetPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0), // ★ 左右のパディングを減らす
            contentPadding:
                const EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 0), // 下パディングを0に
            content: SizedBox(
              width: MediaQuery.of(dialogContext).size.width, // 利用可能な最大幅を指定
              child: SingleChildScrollView(
                // 内容が長くなる可能性を考慮
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
                      // memoFocusNode: memoFocusNode, // FocusNodeを渡す
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
            actionsPadding:
                const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            actions:
                actionsBuilder(dialogContext, memoController, selectedColorInDialog),
          );
        },
      );
    },
  );
  // .whenComplete(() {
  //   memoFocusNode.dispose(); // ダイアログが閉じられたらFocusNodeを破棄
  // });
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
  // _showCoreLogInputDialog は Map<String, dynamic>? を返す可能性があるため、
  // ここで期待する Map<String, String>? に安全に変換する。
  if (result == null) return null;
  return result.map((key, value) => MapEntry(key, value as String));
}
