// session_details_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/log_entry.dart'; // LogEntryモデルをインポート
import '../models/saved_log_session.dart'; // SavedLogSessionモデルをインポート
import '../utils/session_dialog_utils.dart'; // 共通セッション編集ダイアログ関数をインポート
import '../utils/dialog_utils.dart'; // ログ編集ダイアログ関数をインポート
import '../utils/session_storage.dart'; // 共通ストレージ関数をインポート
import '../screens/widgets/log_table.dart'; // LogTableウィジェットをインポート
import '../theme/color_constants.dart'; // カラーラベル定義をインポート
import '../utils/string_utils.dart'; // 文字列ユーティリティ (カタカナ→ひらがな変換) をインポート
// import 'package:shared_preferences/shared_preferences.dart'; // サジェスチョン読み込みに必要なら

// セッション詳細を表示するStatefulWidget
class SessionDetailsScreen extends StatefulWidget {
  final SavedLogSession session; // 表示するセッションデータ

  const SessionDetailsScreen({super.key, required this.session});

  @override
  State<SessionDetailsScreen> createState() => _SessionDetailsScreenState();
}

class _SessionDetailsScreenState extends State<SessionDetailsScreen> {
  late SavedLogSession _editableSession; // 編集可能なセッションデータ
  List<String> _commentSuggestions = []; // コメントサジェスチョン (今回は空のまま)
  // static const String _suggestionsKey = 'comment_suggestions'; // サジェスチョン用

  static const String _savedSessionsKey = 'saved_log_sessions'; // SharedPreferencesのキー

  @override
  void initState() {
    super.initState();
    // widgetから渡されたセッションデータを編集可能データとして初期化
    _editableSession = widget.session.copyWith(); // 念のためコピーを作成
    // _loadSuggestions(); // 必要であればサジェスチョンを読み込む
  }

  @override
  void dispose() {
    super.dispose();
  }

  // // 必要であればコメントサジェスチョンを読み込む関数 (stopwatch_screen.dart を参考)
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
    final bool success = await updateSession(
      context: context,
      updatedSession: _editableSession,
      savedSessionsKey: _savedSessionsKey,
    );

    if (!mounted) return;
    if (success) {
      // SnackBarは updateSession 関数内で表示される想定
    } else {
      // SnackBarは updateSession 関数内で表示される想定
    }
  }

  @override
  Widget build(BuildContext context) {
    final String formattedDate =
        DateFormat('yyyy/MM/dd HH:mm').format(_editableSession.saveDate);

    return Scaffold(
      appBar: AppBar(
        // title: Text(_editableSession.title, style: const TextStyle(fontSize: 18)), // AppBarのタイトルを削除
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
                // セッションタイトルを本文中に表示
                Text(
                  _editableSession.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
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
    );
  }
}
