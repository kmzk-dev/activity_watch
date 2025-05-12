// lib/screens/session_details_screen.dart
import 'dart:convert'; // jsonDecode, jsonEncode のために必要
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/log_entry.dart';
import '../models/saved_log_session.dart';
import '../utils/session_dialog_utils.dart';
import '../utils/dialog_utils.dart';
import '../utils/session_storage.dart';
import '../screens/widgets/log_card_list.dart';
import '../screens/widgets/log_color_summary_chart.dart';
import '../theme/color_constants.dart'; // colorLabels のために必要
import '../utils/string_utils.dart'; // katakanaToHiragana のために必要

class SessionDetailsScreen extends StatefulWidget {
  final SavedLogSession session;

  const SessionDetailsScreen({super.key, required this.session});

  @override
  State<SessionDetailsScreen> createState() => _SessionDetailsScreenState();
}

class _SessionDetailsScreenState extends State<SessionDetailsScreen> {
  late SavedLogSession _editableSession;
  List<String> _commentSuggestions = []; // サジェスト候補を保持するリスト

  static const String _savedSessionsKey = 'saved_log_sessions';
  static const String _suggestionsKey = 'comment_suggestions'; // サジェスト用のキー
  static const double _chartHeight = 200.0;

  @override
  void initState() {
    super.initState();
    _editableSession = widget.session.copyWith();
    _loadCommentSuggestions(); // 初期化時にサジェストを読み込む
  }

  // SharedPreferencesからコメントのサジェストを読み込む
  Future<void> _loadCommentSuggestions() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _commentSuggestions = prefs.getStringList(_suggestionsKey) ?? [];
      });
    }
  }

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

  Future<void> _editLogEntry(int logIndex) async {
    // LogCardList に渡す logs は _editableSession.logEntries をそのまま渡しているので、
    // logIndex はそのリストに対するインデックスとなる。
    if (logIndex < 0 || logIndex >= _editableSession.logEntries.length) return;

    // サジェストが最新であることを確認するために、ダイアログ表示前に読み込む
    await _loadCommentSuggestions();
    if (!mounted) return;

    final LogEntry currentLog = _editableSession.logEntries[logIndex];

    final Map<String, String>? result = await showLogCommentEditDialog(
      context: context,
      initialMemo: currentLog.memo,
      initialColorLabelName: currentLog.colorLabelName,
      commentSuggestions: _commentSuggestions, // 読み込んだサジェストを渡す
      katakanaToHiraganaConverter: katakanaToHiragana, // 文字列ユーティリティを渡す
      availableColorLabels: colorLabels, // `color_constants.dart` から
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

  Future<void> _updateSessionInStorage() async {
    final bool success = await updateSession(
      context: context,
      updatedSession: _editableSession,
      savedSessionsKey: _savedSessionsKey,
    );

    // SnackBar は updateSession 関数内でテーマに基づいて表示されることを期待
    if (!mounted) return;
    // if (success) {
    //   // 必要であれば、ここでも成功のSnackBarを表示
    // } else {
    //   // 必要であれば、ここでも失敗のSnackBarを表示
    // }
  }

  Future<void> _deleteCurrentSession() async {
    final ColorScheme colorScheme = Theme.of(context).colorScheme; // ダイアログ外でテーマを取得

    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        // ダイアログ内でテーマを取得
        final ThemeData theme = Theme.of(dialogContext);
        final ColorScheme dialogColorScheme = theme.colorScheme;
        // final TextTheme dialogTextTheme = theme.textTheme;

        return AlertDialog(
          // titleTextStyle, contentTextStyle は app_theme.dart の dialogTheme から適用される想定
          title: const Text('セッション削除の確認'),
          content: const Text('このセッションを本当に削除しますか？この操作は元に戻せません。'),
          actions: <Widget>[
            TextButton(
              // TextButton のスタイルは app_theme.dart の textButtonTheme から適用される想定
              child: const Text('キャンセル'),
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: dialogColorScheme.error), // テーマのエラーカラーを使用
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
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('セッションデータの読み込みに失敗しました。', style: TextStyle(color: colorScheme.onError)),
                backgroundColor: colorScheme.error,
              ),
            );
          }
          return;
        }
      }

      allSessions.removeWhere((session) => session.id == _editableSession.id);

      final String updatedSessionsJson = jsonEncode(allSessions.map((s) => s.toJson()).toList());
      await prefs.setString(_savedSessionsKey, updatedSessionsJson);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('セッションを削除しました。', style: TextStyle(color: colorScheme.onSurface)), // 通常の通知
            backgroundColor: colorScheme.surface,
          ),
        );
        Navigator.of(context).pop(true);
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;
    final IconThemeData iconTheme = theme.iconTheme;

    final String formattedDate =
        DateFormat('yyyy/MM/dd HH:mm').format(_editableSession.saveDate);

    return Scaffold(
      appBar: AppBar(
        // AppBarのタイトルを削除
        // title: Text(_editableSession.title, style: textTheme.titleLarge?.copyWith(fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'セッション情報を編集',
            onPressed: _showEditSessionDialog,
          ),
        ],
      ),
      body: SingleChildScrollView( // スクロール可能にするために SingleChildScrollView を追加
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // セッションタイトルをBodyの最初に追加
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0), // 上部に適切なパディングを追加
              child: Text(
                _editableSession.title,
                style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold), // より目立つスタイルに変更
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0), // タイトル下、日付上のパディング調整
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_month_outlined,
                        size: 16,
                        color: iconTheme.color?.withOpacity(0.7),
                      ),
                      const SizedBox(width: 6),
                      Text(formattedDate, style: textTheme.titleSmall),
                    ],
                  ),
                  if (_editableSession.sessionComment != null &&
                      _editableSession.sessionComment!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12.0),
                      width: double.infinity,
                      //decoration: BoxDecoration(
                      //  color: colorScheme.surface.withOpacity(0.5),
                      //  borderRadius: BorderRadius.circular(8.0),
                      //  border: Border.all(color: colorScheme.onSurface.withOpacity(0.12))
                      //),
                      child: Text(
                        _editableSession.sessionComment!,
                        style: textTheme.bodyMedium?.copyWith(height: 1.5),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (_editableSession.logEntries.isNotEmpty)
              SizedBox(
                height: _chartHeight,
                child: LogColorSummaryChart(
                  logs: _editableSession.logEntries,
                ),
              )
            else
              Container(
                height: _chartHeight,
                alignment: Alignment.center,
                margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: theme.cardTheme.color?.withOpacity(0.3) ?? colorScheme.surface.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(color: colorScheme.onSurface.withOpacity(0.12))
                ),
                child: Text(
                  'グラフ表示対象のログデータがありません。',
                  style: textTheme.bodySmall?.copyWith(color: textTheme.bodySmall?.color?.withOpacity(0.7)),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 8),
            // LogCardListがExpanded内にあるとSingleChildScrollViewとの組み合わせで問題が起きる可能性があるため、
            // ListViewの高さを固定するか、shrinkWrap: true と physics: NeverScrollableScrollPhysics() を指定するなどの対応が必要
            // ここでは、LogCardListが可変の高さを持つことを想定し、Expandedを削除し、ListViewのスクロールに任せる
            LogCardList(
              logs: _editableSession.logEntries, // 表示するログエントリのリスト
              onEditLog: _editLogEntry, // 編集ボタンが押されたときのコールバック
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            IconButton(
              icon: const Icon(Icons.delete_forever),
              color: colorScheme.error,
              tooltip: 'このセッションを削除',
              iconSize: 30.0,
              onPressed: _deleteCurrentSession,
            ),
          ],
        ),
      ),
    );
  }
}
