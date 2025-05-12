import 'package:flutter/material.dart';
// flutter/services.dart はこのファイルでは直接使用しないため、必要に応じて削除またはコメントアウト
// import 'package:flutter/services.dart';

// セッションのタイトルとコメントを入力・編集するためのダイアログを表示します。
// 保存された場合はタイトルとコメントを含むMapを、キャンセルの場合はnullを返します。
Future<Map<String, String>?> showSessionDetailsInputDialog({
  required BuildContext context,
  required String dialogTitle,
  String initialTitle = '', // 新規作成時は空
  String initialComment = '', // 新規作成時は空
  String positiveButtonText = '保存', // デフォルトは「保存」
}) async {
  final TextEditingController titleController =
      TextEditingController(text: initialTitle);
  final TextEditingController commentController =
      TextEditingController(text: initialComment);
  final GlobalKey<FormState> formKey = GlobalKey<FormState>(); // バリデーション用

  return await showDialog<Map<String, String>?>(
    context: context,
    barrierDismissible: true, // ダイアログ外タップで閉じるのを許可
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: Text(dialogTitle),
        // AlertDialog自体の左右のパディングを調整して、表示領域を広げる
        insetPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0), // ★ 左右のパディングを減らす
        content: SizedBox( // AlertDialogのコンテンツの幅を調整
          // insetPaddingで確保された領域内で、可能な限り幅を取るようにする
          // MediaQuery.of(dialogContext).size.width * 0.9 のように、画面幅に対する割合で指定することも可能
          width: MediaQuery.of(dialogContext).size.width, // 利用可能な最大幅を指定
          child: SingleChildScrollView(
            child: Form(
              // バリデーションのためにFormウィジェットでラップ
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextFormField(
                    // タイトル入力フィールド
                    controller: titleController,
                    autofocus: true, // ダイアログ表示時に自動フォーカス
                    decoration: const InputDecoration(
                      labelText: "タイトル",
                      hintText: "セッションのタイトルを入力",
                      border: OutlineInputBorder(),
                    ),
                    textInputAction: TextInputAction.next, // 次のフィールドへ移動
                    validator: (value) {
                      // バリデーションルール
                      if (value == null || value.trim().isEmpty) {
                        return 'タイトルは必須です。';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    // コメント入力フィールド
                    controller: commentController,
                    decoration: const InputDecoration(
                      labelText: "コメント (任意)",
                      hintText: "セッション全体に関するコメントを入力",
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.multiline, // 複数行入力可能
                    maxLines: null, // 内容に応じて高さを自動調整
                    minLines: 3, // 最小3行分の高さを確保
                    textInputAction: TextInputAction.newline,
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('キャンセル'),
            onPressed: () {
              Navigator.of(dialogContext).pop(null); // nullを返してダイアログを閉じる
            },
          ),
          ElevatedButton(
            // 保存/更新ボタン
            child: Text(positiveButtonText),
            onPressed: () {
              // Formのバリデーションを実行
              if (formKey.currentState!.validate()) {
                // バリデーションが通れば結果を返す
                Navigator.of(dialogContext).pop({
                  'title': titleController.text.trim(),
                  'comment': commentController.text.trim(),
                });
              }
            },
          ),
        ],
      );
    },
  );
}
