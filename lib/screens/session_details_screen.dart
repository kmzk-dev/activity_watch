// lib/screens/session_details_screen.dart
import 'dart:convert'; // jsonDecode, jsonEncode のために必要
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart'; // SharedPreferences のために必要

import '../models/log_entry.dart'; // LogEntryモデルをインポート
import '../models/saved_log_session.dart'; // SavedLogSessionモデルをインポート
import '../utils/session_dialog_utils.dart'; // 共通セッション編集ダイアログ関数をインポート
import '../utils/dialog_utils.dart'; // ログ編集ダイアログ関数をインポート
import '../utils/session_storage.dart'; // 共通ストレージ関数をインポート (updateSession を利用)
import '../screens/widgets/log_table.dart'; // LogTableウィジェットをインポート
import '../theme/color_constants.dart'; // カラーラベル定義をインポート
import '../utils/string_utils.dart'; // 文字列ユーティリティ (カタカナ→ひらがな変換) をインポート

// セッション詳細を表示するStatefulWidget
class SessionDetailsScreen extends StatefulWidget {
  final SavedLogSession session; // 表示するセッションデータ

  const SessionDetailsScreen({super.key, required this.session});

  @override
  State<SessionDetailsScreen> createState() => _SessionDetailsScreenState();
}

class _SessionDetailsScreenState extends State<SessionDetailsScreen> {
  late SavedLogSession _editableSession; // 編集可能なセッションデータ
  List<String> _commentSuggestions = []; // コメントサジェスチョン
  // static const String _suggestionsKey = 'comment_suggestions'; // サジェスチョン用SharedPreferencesキー

  static const String _savedSessionsKey = 'saved_log_sessions'; // SharedPreferencesのキー

  @override
  void initState() {
    super.initState();
    // widgetから渡されたセッションデータを編集可能データとして初期化
    _editableSession = widget.session.copyWith();
    // _loadSuggestions(); // 必要であればサジェスチョンを読み込む
  }

  @override
  void dispose() {
    super.dispose();
  }

  // // 必要であればコメントサジェスチョンを読み込む関数
  // Future<void> _loadSuggestions() async {
  //   final SharedPreferences prefs = await SharedPreferences.getInstance();
  //   if (!mounted) return;
  //   setState(() {
  //     _commentSuggestions = prefs.getStringList(_suggestionsKey) ?? [];
  //   });
  // }

  // セッション全体の情報を編集するためのダイアログを表示する非同期関数
  Future<void> _showEditSessionDialog() async {
    final Map<String, String>? updatedData = await showSessionDetailsInputDialog(
      context: context,
      dialogTitle: 'セッション情報を編集',
      initialTitle: _editableSession.title,
      initialComment: _editableSession.sessionComment ?? '',
      positiveButtonText: '更新',
    );

    if (!mounted) return;
    FocusScope.of(context).unfocus();

    if (updatedData != null && updatedData['title'] != null) {
      final newTitle = updatedData['title']!;
      final newComment = updatedData['comment'];

      // データに変更があった場合のみ更新処理を実行
      if (newTitle != _editableSession.title ||
          (newComment ?? '') != (_editableSession.sessionComment ?? '')) {
        setState(() {
          _editableSession = _editableSession.copyWith(
            title: newTitle,
            sessionComment: newComment,
          );
        });
        await _updateSessionInStorage();
      }
    }
  }

  // 個別のログエントリを編集するためのダイアログを表示する非同期関数
  Future<void> _editLogEntry(int logIndex) async {
    if (logIndex < 0 || logIndex >= _editableSession.logEntries.length) return;

    final LogEntry currentLog = _editableSession.logEntries[logIndex];

    final Map<String, String>? result = await showLogCommentEditDialog(
      context: context,
      initialMemo: currentLog.memo,
      initialColorLabelName: currentLog.colorLabelName,
      commentSuggestions: _commentSuggestions,
      katakanaToHiraganaConverter: katakanaToHiragana,
      availableColorLabels: colorLabels,
    );

    if (!mounted) return;

    if (result != null) {
      final String newMemo = result['memo'] ?? currentLog.memo;
      final String newColorLabel = result['colorLabel'] ?? currentLog.colorLabelName;

      // データに変更があった場合のみ更新処理を実行
      if (newMemo != currentLog.memo || newColorLabel != currentLog.colorLabelName) {
        setState(() {
          _editableSession.logEntries[logIndex].memo = newMemo;
          _editableSession.logEntries[logIndex].colorLabelName = newColorLabel;
        });
        await _updateSessionInStorage();
      }
    }
    FocusScope.of(context).unfocus();
  }

  // ストレージ内のセッション情報を更新する非同期関数
  Future<void> _updateSessionInStorage() async {
    // session_storage.dart の updateSession 関数を利用
    final bool success = await updateSession(
      context: context, // SnackBar表示のため
      updatedSession: _editableSession,
      savedSessionsKey: _savedSessionsKey,
    );

    if (!mounted) return;
    if (success) {
      // SnackBarは updateSession 関数内で表示される
    } else {
      // SnackBarは updateSession 関数内で表示される
    }
  }

  // 現在のセッションを削除する処理
  Future<void> _deleteCurrentSession() async {
    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('セッション削除の確認'),
          content: const Text('このセッションを本当に削除しますか？この操作は元に戻せません。'),
          actions: <Widget>[
            TextButton(
              child: const Text('キャンセル'),
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('削除'),
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
            ),
          ],
        );
      },
    );

    if (!mounted) return;

    if (confirmDelete == true) {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;

      final String? sessionsJson = prefs.getString(_savedSessionsKey);
      List<SavedLogSession> allSessions = [];

      if (sessionsJson != null && sessionsJson.isNotEmpty) {
        try {
          final List<dynamic> decodedList = jsonDecode(sessionsJson) as List<dynamic>;
          allSessions = decodedList
              .map((jsonItem) =>
                  SavedLogSession.fromJson(jsonItem as Map<String, dynamic>))
              .toList();
        } catch (e) {
          // JSONデコードエラー
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('セッションデータの読み込みに失敗しました。')),
            );
          }
          return; // 削除処理を中断
        }
      }

      // IDで該当セッションを検索し、リストから削除
      allSessions.removeWhere((session) => session.id == _editableSession.id);

      // 更新されたセッションリストをJSON文字列にエンコードして保存
      final String updatedSessionsJson = jsonEncode(allSessions.map((s) => s.toJson()).toList());
      await prefs.setString(_savedSessionsKey, updatedSessionsJson);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('セッションを削除しました。')),
        );
        // 前の画面に戻り、削除が成功したことを伝える (true を渡す)
        Navigator.of(context).pop(true);
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final String formattedDate =
        DateFormat('yyyy/MM/dd HH:mm').format(_editableSession.saveDate);

    return Scaffold(
      appBar: AppBar(
        title: Text(_editableSession.title, style: const TextStyle(fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'セッション情報を編集',
            onPressed: _showEditSessionDialog,
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
                Row(
                  children: [
                    Icon(Icons.calendar_month_outlined,
                        size: 16, color: Colors.grey[700]),
                    const SizedBox(width: 6),
                    Text(formattedDate,
                        style: Theme.of(context).textTheme.titleSmall),
                  ],
                ),
                if (_editableSession.sessionComment != null &&
                    _editableSession.sessionComment!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12.0), 
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8.0), 
                      border: Border.all(color: Colors.grey[300]!) 
                    ),
                    child: Text(
                      _editableSession.sessionComment!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5), 
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: _editableSession.logEntries.isEmpty
                ? const Center(child: Text('このセッションにはログがありません。'))
                : LogTable(
                    logs: _editableSession.logEntries,
                    onEditLog: _editLogEntry,
                  ),
          ),
        ],
      ),
      // 画面下部にフッターとして削除アイコンボタンを中央に配置
      bottomNavigationBar: BottomAppBar(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center, // IconButtonを中央寄せにする
          children: <Widget>[
            IconButton(
              icon: const Icon(Icons.delete_forever),
              color: Colors.redAccent, // アイコンの色を赤系に
              tooltip: 'このセッションを削除',
              iconSize: 30.0, // アイコンサイズを少し大きくする (任意)
              onPressed: _deleteCurrentSession,
            ),
          ],
        ),
      ),
    );
  }
}
