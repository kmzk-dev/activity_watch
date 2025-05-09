import 'dart:convert'; // jsonEncode, jsonDecode のために必要
import 'package:flutter/material.dart'; // BuildContext, ScaffoldMessenger のために必要
import 'package:shared_preferences/shared_preferences.dart'; // SharedPreferences のために必要
import '../models/log_entry.dart'; // LogEntry モデルのために必要
import '../models/saved_log_session.dart'; // SavedLogSession モデルのために必要

// 現在のセッションを指定されたタイトルとコメントでSharedPreferencesに保存します。
Future<void> saveSession({
  required BuildContext context,
  required String title,
  required String? comment,
  required List<LogEntry> logs,
  required String savedSessionsKey, // SharedPreferencesで使用するキー
}) async {
  if (!ScaffoldMessenger.of(context).mounted) return; // contextが有効かチェック

  final prefs = await SharedPreferences.getInstance();
  
  // 新しいセッションIDを生成 (現在のエポックミリ秒)
  final String newSessionId = DateTime.now().millisecondsSinceEpoch.toString();

  // 保存する新しいSavedLogSessionオブジェクトを作成
  final newSavedSession = SavedLogSession(
    id: newSessionId,
    title: title,
    sessionComment: comment,
    saveDate: DateTime.now(),
    logEntries: List<LogEntry>.from(logs), // ログのリストをコピーして渡す
  );

  // 既存の保存済みセッションリストを取得
  final String? existingSessionsJson = prefs.getString(savedSessionsKey);
  List<SavedLogSession> savedSessions = [];
  if (existingSessionsJson != null && existingSessionsJson.isNotEmpty) {
    try {
      final List<dynamic> decodedList = jsonDecode(existingSessionsJson) as List<dynamic>;
      savedSessions = decodedList
          .map((jsonItem) => SavedLogSession.fromJson(jsonItem as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // JSONデコードエラーの場合はリストを初期化
      print('Error decoding existing sessions: $e'); // エラーログ
      savedSessions = []; 
    }
  }
  
  // 新しいセッションをリストに追加し、保存日で降順ソート
  savedSessions.add(newSavedSession);
  savedSessions.sort((a, b) => b.saveDate.compareTo(a.saveDate));

  // 更新されたセッションリストをJSON文字列にエンコードして保存
  final String updatedSessionsJson = jsonEncode(savedSessions.map((s) => s.toJson()).toList());
  await prefs.setString(savedSessionsKey, updatedSessionsJson);

  // 保存完了をユーザーに通知
  if (ScaffoldMessenger.of(context).mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('「$title」としてセッションを保存しました。')),
    );
  }
}
