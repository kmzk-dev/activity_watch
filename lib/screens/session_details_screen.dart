// lib/screens/session_details_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/color.dart';
import '../models/log_entry.dart';
import '../models/saved_log_session.dart';
import '../utils/session_dialog_utils.dart';
import '../utils/dialog_utils.dart';
import '../utils/session_storage.dart';
import '../screens/widgets/log_card_list.dart';
import '../screens/widgets/log_color_summary_chart.dart';
import '../utils/string_utils.dart';
import '../utils/suggestion_utils.dart' as suggestion_utils;
import '../utils/confirmation_dialog_utils.dart';

class SessionDetailsScreen extends StatefulWidget {
  final SavedLogSession session;

  const SessionDetailsScreen({super.key, required this.session});

  @override
  State<SessionDetailsScreen> createState() => _SessionDetailsScreenState();
}

class _SessionDetailsScreenState extends State<SessionDetailsScreen> {
  late SavedLogSession _editableSession;
  List<String> _commentSuggestions = []; // サジェスト候補を保持するリスト
// ----------------------------------------------------------------- <固有の定数:各種設定>
  static const String _savedSessionsKey = 'saved_log_sessions';
  static const double _chartHeight = 200.0; // グラフの固定高さ

  @override
  void initState() {
    super.initState();
    _editableSession = widget.session.copyWith();
    _initialize();
  }

  // 非同期的な初期化:リファクタリング済み
  Future<void> _initialize() async {
    final List<String> loadedSuggestions = await suggestion_utils.loadSuggestions();
    if (mounted) {
      setState(() {
        _commentSuggestions = loadedSuggestions;
      });
    }
  }
  // セッションを更新:リファクタリング済み
  Future<void> _showEditSessionDialog() async {
    final Map<String, String>? updatedData =
        await showSessionDetailsInputDialog(
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

      if (newTitle != _editableSession.title || (newComment ?? '') != (_editableSession.sessionComment ?? '')) {
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
  // ログエントリを編集:リファクタリング済み
  Future<void> _editLogEntry(int logIndex) async {
    if (logIndex < 0 || logIndex >= _editableSession.logEntries.length) return;

    if (!mounted) return;
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
      final String newColorLabel =
          result['colorLabel'] ?? currentLog.colorLabelName;

      if (newMemo != currentLog.memo || newColorLabel != currentLog.colorLabelName) {
        setState(() {
          _editableSession.logEntries[logIndex].memo = newMemo;
          _editableSession.logEntries[logIndex].colorLabelName = newColorLabel;
        });
        await _updateSessionInStorage();
      }
    }

    if(mounted) {
      FocusScope.of(context).unfocus();
    }
  }

  // セッションを更新:リファクタリング済み
  Future<void> _updateSessionInStorage() async {
    // ignore: unused_local_variable
    final bool success = await updateSession(
      context: context,
      updatedSession: _editableSession,
      savedSessionsKey: _savedSessionsKey,
    );
    if (!mounted) return;
  }

  // セッションを削除:リファクタリング済み
  Future<void> _deleteCurrentSession() async {
    
    if (!mounted) return;
    final bool? confirmDelete = await showConfirmationDialog(
      context: context,
      title: 'セッション削除の確認',
      content: 'このセッションを本当に削除しますか？この操作は元に戻せません。',
    );

    if (confirmDelete != true) return;
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final String? sessionsJson = prefs.getString(_savedSessionsKey);
    List<SavedLogSession> allSessions = [];

    if (sessionsJson != null && sessionsJson.isNotEmpty) {
      try {
        final List<dynamic> decodedList =
            jsonDecode(sessionsJson) as List<dynamic>;
        allSessions = decodedList
            .map((jsonItem) =>
                SavedLogSession.fromJson(jsonItem as Map<String, dynamic>))
            .toList();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('セッションデータの読み込みに失敗しました。'),
            ),
          );
        }
        return;
      }
    }

    allSessions.removeWhere((session) => session.id == _editableSession.id);

    final String updatedSessionsJson = jsonEncode(allSessions.map((s) => s.toJson()).toList());
    if (!mounted) return;
    await prefs.setString(_savedSessionsKey, updatedSessionsJson);

    if (mounted) {
      Navigator.of(context).pop(true); // 削除後に前の画面に戻るため、通知はしない
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;
    final String formattedDate =
        DateFormat('yyyy/MM/dd HH:mm').format(_editableSession.saveDate);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          formattedDate,
          style: textTheme.titleSmall
          ),
        backgroundColor: colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0.0, // スクロール時の変化をなくす
        surfaceTintColor: colorScheme.surface,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_square),
            onPressed: _showEditSessionDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: _chartHeight,
            child: LogColorSummaryChart(
              logs: _editableSession.logEntries,
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // タイトル
                    Text(
                      _editableSession.title,
                      style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    // コメント
                    Container(
                      padding: const EdgeInsets.all(8.0),
                      width: double.infinity,
                      child: Text(
                        _editableSession.sessionComment!,
                        style: textTheme.bodyMedium?.copyWith(height: 1.5),
                      ),
                    ),
                    // リスト
                    LogCardList(
                      logs: _editableSession.logEntries,
                      onEditLog: _editLogEntry,
                    ),
                    const SizedBox(height: 16.0), // リストの下のセーフティマージン
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            IconButton(
              icon: const Icon(Icons.delete_forever),
              color: colorScheme.error,
              onPressed: _deleteCurrentSession,
            ),
          ],
        ),
      ),
    );
  }
}
