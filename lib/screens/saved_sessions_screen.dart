// lib/screens/saved_sessions_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../models/saved_log_session.dart';
import 'session_details_screen.dart';
import '../theme/scale.dart';

class SavedSessionsScreen extends StatefulWidget {
  const SavedSessionsScreen({super.key});

  @override
  State<SavedSessionsScreen> createState() => _SavedSessionsScreenState();
}

class _SavedSessionsScreenState extends State<SavedSessionsScreen> {
  List<SavedLogSession> _savedSessions = [];
  bool _isLoading = true;
  DateTime? _lastVisibleTime;

  bool _isSelectionMode = false;
  final Set<String> _selectedSessionIds = {};

  static const String _savedSessionsKey = 'saved_log_sessions';

  @override
  void initState() {
    super.initState();
    // 初期ロードは VisibilityDetector に任せるか、ここで一度呼ぶことも検討
    // _loadSavedSessions();
  }

  Future<void> _loadSavedSessions({bool force = false}) async {
    if (!mounted) return;

    if (!force &&
        _lastVisibleTime != null &&
        DateTime.now().difference(_lastVisibleTime!) <
            const Duration(seconds: 1)) {
      return;
    }

    setState(() {
      _isLoading = true;
      if (force || _savedSessions.isEmpty) {
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
          final colorScheme = Theme.of(context).colorScheme;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('保存済みセッションの読み込みに失敗しました。', style: TextStyle(color: colorScheme.onError)),
              backgroundColor: colorScheme.error,
            ),
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

  void _clearSelection() {
    if (!mounted) return;
    setState(() {
      _selectedSessionIds.clear();
      _isSelectionMode = false;
    });
  }

  Future<void> _deleteSelectedSessions() async {
    if (_selectedSessionIds.isEmpty) return;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        final ThemeData theme = Theme.of(dialogContext);
        final ColorScheme dialogColorScheme = theme.colorScheme;

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
              style: TextButton.styleFrom(foregroundColor: dialogColorScheme.error),
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
          SnackBar(
            content: Text('${_selectedSessionIds.length} 件のセッションを削除しました。', style: TextStyle(color: colorScheme.onSurface)),
            backgroundColor: colorScheme.surface,
          ),
        );
        _clearSelection();
        // _loadSavedSessions(force: true); // 削除後すぐに再読み込みする場合
         setState(() { // 画面から削除されたことを即時反映するためにisLoadingをfalseに
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;
    final IconThemeData iconTheme = theme.iconTheme;

    Widget? leadingWidget;
    List<Widget>? actionsWidgets;
    Widget? titleWidget;

    if (_isSelectionMode && _selectedSessionIds.isNotEmpty) {
      leadingWidget = IconButton(
        icon: const Icon(Icons.deselect),
        // iconTheme.color が適用される
        tooltip: '選択をすべて解除',
        onPressed: _clearSelection,
      );
      titleWidget = Text('${_selectedSessionIds.length} item selected', style: textTheme.titleLarge); // AppBarのタイトルスタイル
      actionsWidgets = null;
    } else {
      leadingWidget = null;
      titleWidget = const Text('History'); // 通常時のタイトル
      // actionsWidgets = [
      //   IconButton(
      //     icon: const Icon(Icons.refresh),
      //     // iconTheme.color が適用される
      //     tooltip: 'リストを更新',
      //     onPressed: () => _loadSavedSessions(force: true),
      //   ),
      // ];
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
          // AppBarのスタイルは app_theme.dart の appBarTheme から適用される想定
          backgroundColor: colorScheme.surface, // AppBarの背景色を固定
          elevation: 0, // 通常時の影を消す場合 (任意)
          scrolledUnderElevation: 0.0, // スクロール時の影 (色の変化の原因の一つ) をなくす
          surfaceTintColor: colorScheme.surface,
          //
          leading: leadingWidget,
          title: titleWidget,
          actions: actionsWidgets,
          automaticallyImplyLeading: _isSelectionMode, // 選択モードの時だけ戻るボタンを非表示にするなど調整可能
        ),
        body: _isLoading
            ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
            : _savedSessions.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'No items',
                        style: textTheme.titleMedium, // より適切なテキストスタイルに変更
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

                      final Color? cardBackgroundColor = isSelected
                          ? colorScheme.primary.withAlpha(Scale.alpha12)// withOpacity(0.1) // テーマのプライマリカラーを薄く
                          : theme.cardTheme.color; // テーマのカード背景色

                      Widget subtitleWidget = Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.calendar_month_outlined,
                            size: 14,
                            color: textTheme.bodySmall?.color?.withAlpha(Scale.alpha70) // withOpacity(0.7), // サブタイトルのテキスト色を少し薄く
                          ),
                          const SizedBox(width: 4),
                          Text(
                            formattedDate,
                            style: textTheme.bodySmall?.copyWith(
                              color: textTheme.bodySmall?.color?.withAlpha(Scale.alpha70) // withOpacity(0.7), // サブタイトルのテキスト色を少し薄く
                            ),
                          ),
                        ],
                      );

                      return Card(
                        // Cardのスタイルは app_theme.dart の cardTheme から適用される想定
                        margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                        color: cardBackgroundColor,
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
                                    color: isSelected ? colorScheme.primary : iconTheme.color?.withAlpha(Scale.alpha60) // withOpacity(0.6),
                                  )
                                : null,
                            title: Text(session.title, style: textTheme.titleMedium), // テーマのテキストスタイル
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
                backgroundColor: colorScheme.error, // テーマのエラーカラーを使用
                foregroundColor: colorScheme.onError, // foregroundColor は FABTheme から取得されるか、colorScheme.onError を使用
                // foregroundColor は FABTheme から取得されるか、colorScheme.onError を使用
              )
            : null,
      ),
    );
  }
}
