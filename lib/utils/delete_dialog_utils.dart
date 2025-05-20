// utils/dialog_utils.dart (または delete_dialog.dart)
import 'package:flutter/material.dart';

Future<bool?> showDeleteConfirmationDialog({
  required BuildContext context,
  String title = '削除の確認', // デフォルトタイトル
  required String content,    // 削除対象に応じたメッセージ
  String confirmButtonText = '削除',
  String cancelButtonText = 'キャンセル',
}) async {
  return await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      final ThemeData theme = Theme.of(dialogContext);
      final ColorScheme dialogColorScheme = theme.colorScheme;

      return AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: <Widget>[
          TextButton(
            child: Text(cancelButtonText),
            onPressed: () {
              Navigator.of(dialogContext).pop(false);
            },
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: dialogColorScheme.error,
            ),
            child: Text(confirmButtonText),
            onPressed: () {
              Navigator.of(dialogContext).pop(true);
            },
          ),
        ],
      );
    },
  );
}