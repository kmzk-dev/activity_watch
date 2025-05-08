import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:visibility_detector/visibility_detector.dart'; // VisibilityDetectorをインポート

import 'main.dart'; // LogEntry, SavedLogSession モデルのため
import 'session_details_screen.dart'; // 詳細画面のため

class SavedSessionsScreen extends StatefulWidget {
  const SavedSessionsScreen({super.key});

  @override
  State<SavedSessionsScreen> createState() => _SavedSessionsScreenState();
}

class _SavedSessionsScreenState extends State<SavedSessionsScreen> {
  List<SavedLogSession> _savedSessions = [];
  bool _isLoading = true;
  DateTime? _lastVisibleTime;


  static const String _savedSessionsKey = 'saved_log_sessions';

  @override
  void initState() {
    super.initState();
    // initStateでの初回ロードはVisibilityDetectorに任せることもできるが、残しておく
    // _loadSavedSessions();
  }

  Future<void> _loadSavedSessions({bool force = false}) async {
    if (!force && _lastVisibleTime != null && DateTime.now().difference(_lastVisibleTime!) < const Duration(seconds: 1)) {
      return;
    }

    if (!mounted) return;
    if (!_isLoading) {
      setState(() {
        _isLoading = true;
      });
    }


    final prefs = await SharedPreferences.getInstance();
    final String? sessionsJson = prefs.getString(_savedSessionsKey);
    List<SavedLogSession> loadedSessions = [];
    if (sessionsJson != null && sessionsJson.isNotEmpty) {
      try {
        final List<dynamic> decodedList = jsonDecode(sessionsJson) as List<dynamic>;
        loadedSessions = decodedList
            .map((jsonItem) => SavedLogSession.fromJson(jsonItem as Map<String, dynamic>))
            .toList();
        loadedSessions.sort((a, b) => b.saveDate.compareTo(a.saveDate));
      } catch (e) {
        print('Error decoding saved sessions on list screen: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('保存済みセッションの読み込みに失敗しました。')),
          );
        }
      }
    }
    
    if (mounted) {
      setState(() {
        _savedSessions = loadedSessions;
        _isLoading = false;
        _lastVisibleTime = DateTime.now();
      });
    }
  }

  Future<void> _deleteSession(String sessionId) async {
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

    if (confirmDelete == true) {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _savedSessions.removeWhere((session) => session.id == sessionId);
        _isLoading = true;
      });
      final String updatedSessionsJson = jsonEncode(_savedSessions.map((s) => s.toJson()).toList());
      await prefs.setString(_savedSessionsKey, updatedSessionsJson);
      
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('セッションを削除しました。')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: const Key('saved_sessions_screen_visibility_detector'),
      onVisibilityChanged: (visibilityInfo) {
        final visiblePercentage = visibilityInfo.visibleFraction * 100;
        if (mounted && visiblePercentage > 50 ) {
            _loadSavedSessions();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          // title: const Text('保存済みログセッション'), // タイトル削除済み
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _savedSessions.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        '保存されたセッションはありません。',
                        style: TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: _savedSessions.length,
                    itemBuilder: (context, index) {
                      final session = _savedSessions[index];
                      final String formattedDate = DateFormat('yyyy/MM/dd HH:mm').format(session.saveDate);

                      // ★ subtitle を修正: コメント表示部分を削除
                      Widget subtitleWidget = Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.calendar_month_outlined, size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(formattedDate, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                          ],
                        );

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                        child: ListTile(
                          title: Text(session.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: subtitleWidget, // ★ 修正した subtitle を設定
                          // isThreeLine は不要に
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                            tooltip: 'このセッションを削除',
                            onPressed: () => _deleteSession(session.id),
                          ),
                          onTap: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SessionDetailsScreen(session: session),
                              ),
                            );
                            // VisibilityDetectorがリロードするので、ここでの処理は不要
                          },
                        ),
                      );
                    },
                  ),
          floatingActionButton: FloatingActionButton(
          onPressed: () => _loadSavedSessions(force: true),
          tooltip: 'リストを更新',
          child: const Icon(Icons.refresh),
        ),
      ),
    );
  }
}
