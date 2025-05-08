import 'dart:convert'; // JSON処理のため
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart'; // SharedPreferencesのため
import 'main.dart'; // LogEntry, SavedLogSession モデルのため

class SessionDetailsScreen extends StatefulWidget {
  final SavedLogSession session;

  const SessionDetailsScreen({super.key, required this.session});

  @override
  State<SessionDetailsScreen> createState() => _SessionDetailsScreenState();
}

class _SessionDetailsScreenState extends State<SessionDetailsScreen> {
  late SavedLogSession _editableSession;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();

  static const String _savedSessionsKey = 'saved_log_sessions'; // main.dart と共通

  @override
  void initState() {
    super.initState();
    _editableSession = widget.session;
    _titleController.text = _editableSession.title;
    _commentController.text = _editableSession.sessionComment ?? '';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _showEditDialog() async {
    // ダイアログ表示前に現在の値をコントローラーに設定
    _titleController.text = _editableSession.title;
    _commentController.text = _editableSession.sessionComment ?? '';

    final Map<String, String>? updatedData = await showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: true, // ダイアログ外タップで閉じる
      builder: (BuildContext dialogContext) {
        // ★ FocusNodeの定義を削除
        return AlertDialog(
          title: const Text('セッション情報を編集'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(
                  controller: _titleController,
                  // focusNode: titleFocusNode, // 削除
                  autofocus: true, // ★ タイトル欄に自動フォーカス
                  decoration: const InputDecoration(
                    labelText: "タイトル",
                    hintText: "セッションのタイトルを入力",
                  ),
                   textInputAction: TextInputAction.next, // Enterで次のフィールドへ
                   // onSubmitted: (_) => FocusScope.of(dialogContext).requestFocus(commentFocusNode), // 削除
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _commentController,
                  // focusNode: commentFocusNode, // 削除
                  decoration: const InputDecoration(
                    labelText: "コメント (任意)",
                    hintText: "セッション全体に関するコメントを入力",
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.multiline,
                  maxLines: null,
                  minLines: 3,
                  textInputAction: TextInputAction.done, // 完了アクション
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('キャンセル'),
              onPressed: () {
                // ★ フォーカス制御削除
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              child: const Text('保存'),
              onPressed: () {
                if (_titleController.text.trim().isEmpty) {
                   ScaffoldMessenger.of(dialogContext).showSnackBar(
                     const SnackBar(content: Text('タイトルは必須です。')),
                   );
                   // ★ フォーカス制御削除
                   return;
                }
                // ★ フォーカス制御削除
                Navigator.of(dialogContext).pop({
                  'title': _titleController.text.trim(),
                  'comment': _commentController.text.trim(),
                });
              },
            ),
          ],
        );
      },
    ).then((value) {
        // ★ ダイアログが閉じた後のフォーカス解除（キーボード対策）は残す
        FocusScope.of(context).unfocus();
        return value;
    });


    if (updatedData != null && updatedData['title'] != null) {
      final newTitle = updatedData['title']!;
      final newComment = updatedData['comment'];

      if (newTitle != _editableSession.title || (newComment ?? '') != (_editableSession.sessionComment ?? '')) {
        setState(() {
          _editableSession = _editableSession.copyWith(
            title: newTitle,
            sessionComment: newComment,
          );
        });
        await _updateSessionInStorage();
         if (mounted) {
           // ★ フォーカス制御削除
           Navigator.pop(context, true); // 変更があったことを伝える
        }
      }
    }
     // ★ ダイアログがキャンセルされた場合もフォーカス解除
     else {
        FocusScope.of(context).unfocus();
     }
  }

  Future<void> _updateSessionInStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final String? sessionsJson = prefs.getString(_savedSessionsKey);
    List<SavedLogSession> allSessions = [];

    if (sessionsJson != null && sessionsJson.isNotEmpty) {
      try {
        final List<dynamic> decodedList = jsonDecode(sessionsJson) as List<dynamic>;
        allSessions = decodedList
            .map((jsonItem) => SavedLogSession.fromJson(jsonItem as Map<String, dynamic>))
            .toList();
      } catch (e) {
        print('Error decoding saved sessions for update: $e');
        if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('セッションデータの読み込みに失敗し、更新できませんでした。')),
            );
        }
        return;
      }
    }

    final int sessionIndex = allSessions.indexWhere((s) => s.id == _editableSession.id);
    if (sessionIndex != -1) {
      allSessions[sessionIndex] = _editableSession;
      final String updatedSessionsJson = jsonEncode(allSessions.map((s) => s.toJson()).toList());
      await prefs.setString(_savedSessionsKey, updatedSessionsJson);
      if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('セッション情報を更新しました。')),
          );
      }
    } else {
        if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('更新対象のセッションが見つかりませんでした。')),
            );
        }
    }
  }


  Widget _buildLogTableHeader(BuildContext context) {
    final theme = Theme.of(context);
    final dataTableTheme = theme.dataTableTheme;
    final headingTextStyle = dataTableTheme.headingTextStyle ??
        const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 14);
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor,
            width: 1.0,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        children: <Widget>[
          Expanded(
            flex: 2,
            child: Text('START', style: headingTextStyle),
          ),
          Expanded(
            flex: 2,
            child: Text('END', style: headingTextStyle),
          ),
          Expanded(
            flex: 3,
            child: Text('COMMENT', style: headingTextStyle),
          ),
        ],
      ),
    );
  }

  Widget _buildLogRow(BuildContext context, LogEntry log) {
    final theme = Theme.of(context);
    final dataTableTheme = theme.dataTableTheme;
    final dataRowMinHeight = dataTableTheme.dataRowMinHeight ?? 48.0;
    return Container(
      constraints: BoxConstraints(minHeight: dataRowMinHeight),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor.withOpacity(0.5),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            flex: 2,
            child: Text(log.startTime),
          ),
          Expanded(
            flex: 2,
            child: Text(log.endTime),
          ),
          Expanded(
            flex: 3,
            child: Tooltip(
              message: log.memo,
              child: Text(
                log.memo,
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String formattedDate = DateFormat('yyyy/MM/dd HH:mm').format(_editableSession.saveDate);

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'セッション情報を編集',
            onPressed: _showEditDialog,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _editableSession.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.calendar_month_outlined, size: 16, color: Colors.grey[700]),
                    const SizedBox(width: 6),
                    Text(formattedDate, style: Theme.of(context).textTheme.titleSmall),
                  ],
                ),
                if (_editableSession.sessionComment != null && _editableSession.sessionComment!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8.0),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(4.0),
                    ),
                    child: Text(
                      _editableSession.sessionComment!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ],
            ),
          ),
          _buildLogTableHeader(context),
          Expanded(
            child: _editableSession.logEntries.isEmpty
                ? const Center(child: Text('このセッションにはログがありません。'))
                : ListView.builder(
                    itemCount: _editableSession.logEntries.length,
                    itemBuilder: (context, index) {
                      final log = _editableSession.logEntries[index];
                      return _buildLogRow(context, log);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
