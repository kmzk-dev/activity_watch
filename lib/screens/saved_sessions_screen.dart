// lib/screens/saved_sessions_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../models/saved_log_session.dart';
import 'session_details_screen.dart';

class SavedSessionsScreen extends StatefulWidget {
  const SavedSessionsScreen({super.key});

  @override
  State<SavedSessionsScreen> createState() => _SavedSessionsScreenState();
}

class _SavedSessionsScreenState extends State<SavedSessionsScreen> {
  List<SavedLogSession> _savedSessions = [];
  bool _isLoading = true;
  DateTime? _lastVisibleTime;

  // 選択モード関連の状態変数
  bool _isSelectionMode = false;
  final Set<String> _selectedSessionIds = {};

  static const String _savedSessionsKey = 'saved_log_sessions';

  @override
  void initState() {
    super.initState();
  }

  Future<void> _loadSavedSessions({bool force = false}) async {
    if (!mounted) return; 

    if (!force &&
        _lastVisibleTime != null &&
        DateTime.now().difference(_lastVisibleTime!) <
            const Duration(seconds: 1)) {
      return;
    }

    // ロード開始前に isLoading を true に設定し、選択モードであれば解除する
    setState(() {
      _isLoading = true;
      if (force || _savedSessions.isEmpty) { // 強制更新時や初回ロード時
        _isSelectionMode = false;
        _selectedSessionIds.clear();
      }
    });
    
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return; 

    final String? sessionsJson = prefs.getString(_savedSessionsKey);
    List<SavedLogSession> loadedSessions = [];
    if (sessionsJson != null && sessionsJson.isNotEmpty) {
      try {
        final List<dynamic> decodedList =
            jsonDecode(sessionsJson) as List<dynamic>;
        loadedSessions = decodedList
            .map((jsonItem) =>
                SavedLogSession.fromJson(jsonItem as Map<String, dynamic>))
            .toList();
        loadedSessions.sort((a, b) => b.saveDate.compareTo(a.saveDate));
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('保存済みセッションの読み込みに失敗しました。')),
          );
        }
        loadedSessions = []; 
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

  void _toggleSelection(String sessionId) {
    if (!mounted) return;
    setState(() {
      if (_selectedSessionIds.contains(sessionId)) {
        _selectedSessionIds.remove(sessionId);
      } else {
        _selectedSessionIds.add(sessionId);
      }
      if (_selectedSessionIds.isEmpty) {
        _isSelectionMode = false; 
      } else {
        _isSelectionMode = true; 
      }
    });
  }

  void _startSelectionMode(String sessionId) {
    if (!mounted) return;
    setState(() {
      _isSelectionMode = true;
      _selectedSessionIds.add(sessionId);
    });
  }

  // すべての選択を解除するメソッド
  void _clearSelection() {
    if (!mounted) return;
    setState(() {
      _selectedSessionIds.clear();
      _isSelectionMode = false; 
    });
  }

  Future<void> _deleteSelectedSessions() async {
    if (_selectedSessionIds.isEmpty) return;

    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('選択したセッションの削除'),
          content: Text('${_selectedSessionIds.length} 件のセッションを本当に削除しますか？この操作は元に戻せません。'),
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

      _savedSessions.removeWhere((session) => _selectedSessionIds.contains(session.id));
      
      final String updatedSessionsJson = jsonEncode(_savedSessions.map((s) => s.toJson()).toList());
      await prefs.setString(_savedSessionsKey, updatedSessionsJson);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_selectedSessionIds.length} 件のセッションを削除しました。')),
        );
        _clearSelection(); 
        setState(() {
          _isLoading = false; 
        });
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    Widget? leadingWidget;
    List<Widget>? actionsWidgets;
    Widget? titleWidget;

    if (_isSelectionMode && _selectedSessionIds.isNotEmpty) {
      // 選択モード中で、かつ選択アイテムがある場合
      leadingWidget = IconButton(
        icon: const Icon(Icons.deselect),
        tooltip: '選択をすべて解除',
        onPressed: _clearSelection,
      );
      titleWidget = Text('${_selectedSessionIds.length} 件選択中');
      actionsWidgets = null; // 右側には何も表示しない (または他のアクションを追加可能)
    } else {
      // それ以外の場合 (非選択モード or 選択モードだが選択アイテムなし)
      leadingWidget = null; // 左側には何も表示しない
      titleWidget = null; // 通常のタイトル表示なし
      actionsWidgets = [
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'リストを更新',
          onPressed: () => _loadSavedSessions(force: true),
        ),
      ];
    }

    return VisibilityDetector(
      key: const Key('saved_sessions_screen_visibility_detector'),
      onVisibilityChanged: (visibilityInfo) {
        final visiblePercentage = visibilityInfo.visibleFraction * 100;
        if (mounted && visiblePercentage > 50) {
          if (!_isSelectionMode) { 
             _loadSavedSessions();
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: leadingWidget,
          title: titleWidget,
          actions: actionsWidgets,
          automaticallyImplyLeading: false, // leadingを明示的に制御するため、自動的な戻るボタンなどを無効化
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
                      final isSelected = _selectedSessionIds.contains(session.id);
                      final String formattedDate = DateFormat('yyyy/MM/dd HH:mm').format(session.saveDate);

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
                        color: isSelected ? Theme.of(context).primaryColorLight.withOpacity(0.3) : null,
                        child: InkWell(
                          onLongPress: () {
                            if (!_isSelectionMode) { 
                              _startSelectionMode(session.id);
                            } else { 
                              _toggleSelection(session.id);
                            }
                          },
                          onTap: () {
                            if (_isSelectionMode) {
                              _toggleSelection(session.id);
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SessionDetailsScreen(session: session),
                                ),
                              ).then((_) {
                                if (mounted && !_isSelectionMode) {
                                  _loadSavedSessions(force: true);
                                }
                              });
                            }
                          },
                          child: ListTile(
                            leading: _isSelectionMode 
                                ? Icon(
                                    isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                                    color: isSelected ? Theme.of(context).primaryColor : Colors.grey,
                                  )
                                : null, 
                            title: Text(session.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: subtitleWidget,
                          ),
                        ),
                      );
                    },
                  ),
        floatingActionButton: _isSelectionMode && _selectedSessionIds.isNotEmpty
            ? FloatingActionButton.extended(
                onPressed: _deleteSelectedSessions,
                label: const Text('選択項目を削除'),
                icon: const Icon(Icons.delete_sweep),
                backgroundColor: Colors.redAccent,
              )
            : null, 
      ),
    );
  }
}
