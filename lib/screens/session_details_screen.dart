// session_details_screen.dart
import 'dart:convert'; // JSON処理のため (session_storage.dartに移動するため、このファイルでは不要になる可能性)
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
// SharedPreferencesはsession_storage.dartで扱われるため、このファイルでは直接不要になる可能性
// import 'package:shared_preferences/shared_preferences.dart';
import '../models/log_entry.dart'; // LogEntryモデルをインポート
import '../models/saved_log_session.dart'; // SavedLogSessionモデルをインポート
import '../utils/session_dialog_utils.dart'; // 共通ダイアログ関数をインポート
import '../utils/session_storage.dart'; // 共通ストレージ関数をインポート (updateSession を利用)

// セッション詳細を表示するStatefulWidget
class SessionDetailsScreen extends StatefulWidget {
  final SavedLogSession session; // 表示するセッションデータ

  const SessionDetailsScreen({super.key, required this.session});

  @override
  State<SessionDetailsScreen> createState() => _SessionDetailsScreenState();
}

class _SessionDetailsScreenState extends State<SessionDetailsScreen> {
  late SavedLogSession _editableSession; // 編集可能なセッションデータ

  static const String _savedSessionsKey = 'saved_log_sessions'; // SharedPreferencesのキー (session_storage.dartと共通)

  @override
  void initState() {
    super.initState();
    // widgetから渡されたセッションデータを編集可能データとして初期化
    _editableSession = widget.session;
  }

  // disposeメソッドは特に変更なし
  @override
  void dispose() {
    super.dispose();
  }

  // セッション情報を編集するためのダイアログを表示する非同期関数
  Future<void> _showEditDialog() async {
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
        // ストレージ内のセッション情報を更新 (session_storage.dartの関数を呼び出す)
        await _updateSessionInStorage();
        // mountedプロパティを確認後、画面遷移は行わない
        if (mounted) {
          // Navigator.pop(context, true); // この行をコメントアウトまたは削除することで、現在の画面に留まります。
          // 変更があったことを前の画面に伝える必要がもしあれば、別の方法を検討します。
          // (例: Provider, Riverpod, BLoCなどの状態管理ライブラリで状態を共有・通知する)
          // 今回は「ページにとどめる」が要件のため、popしません。
        }
      }
    }
  }

  // ストレージ内のセッション情報を更新する非同期関数 (session_storage.dartの関数を利用)
  Future<void> _updateSessionInStorage() async {
    final bool success = await updateSession(
      context: context,
      updatedSession: _editableSession,
      savedSessionsKey: _savedSessionsKey,
    );

    if (!mounted) return;
    if (success) {
      // print('セッションの更新に成功しました。'); // デバッグ用
      // SnackBarは updateSession 関数内で表示される想定
    } else {
      // print('セッションの更新に失敗しました。'); // デバッグ用
      // SnackBarは updateSession 関数内で表示される想定
    }
  }

  // ログテーブルのヘッダーを構築するウィジェット (変更なし)
  Widget _buildLogTableHeader(BuildContext context) {
    final theme = Theme.of(context);
    final dataTableTheme = theme.dataTableTheme;
    final headingTextStyle = dataTableTheme.headingTextStyle ??
        const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
            fontSize: 14);
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

  // ログテーブルの各行を構築するウィジェット (変更なし)
  Widget _buildLogRow(BuildContext context, LogEntry log) {
    final theme = Theme.of(context);
    final dataTableTheme = theme.dataTableTheme;
    final dataRowMinHeight =
        dataTableTheme.dataRowMinHeight ?? 48.0;
    final borderColor = theme.dividerColor.withAlpha(128);

    return Container(
      constraints: BoxConstraints(minHeight: dataRowMinHeight),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: borderColor,
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
    final String formattedDate =
        DateFormat('yyyy/MM/dd HH:mm').format(_editableSession.saveDate);

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
