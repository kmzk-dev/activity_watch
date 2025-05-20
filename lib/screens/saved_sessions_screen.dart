// lib/screens/saved_sessions_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../models/saved_log_session.dart';
import 'session_details_screen.dart';
import '../theme/scale.dart';
import '../utils/confirmation_dialog_utils.dart';

class SavedSessionsScreen extends StatefulWidget {
  const SavedSessionsScreen({super.key});

  @override
  State<SavedSessionsScreen> createState() => _SavedSessionsScreenState();
}

class _SavedSessionsScreenState extends State<SavedSessionsScreen> {
  static const String _savedSessionsKey = 'saved_log_sessions';
  List<SavedLogSession> _savedSessions = [];
  bool _isLoading = true;
  DateTime? _lastVisibleTime;
  bool _isSelectionMode = false;
  final Set<String> _selectedSessionIds = {};

  @override
  void initState() {
    super.initState();
    // 初期ロードもVisibilityDetectorで行うため、ここでは何もしない
  }

// ----------------------------------------------------------<データロード処理:ここから>
  Future<bool> _prepareLoadSavedSessions({bool force = false}) async {
    if (!mounted) return false;
    if (!force &&
        _lastVisibleTime != null &&
        DateTime.now().difference(_lastVisibleTime!) <
            const Duration(seconds: 1)) {
      return false;
    }

    setState(() {
      _isLoading = true;
      // 強制ロード時、または保存済みセッションが空の場合、選択モードを解除
      if (force || _savedSessions.isEmpty) {
        _isSelectionMode = false;
        _selectedSessionIds.clear();
      }
    });
    return true;
  }

  Future<void> _performLoadSavedSessions() async {
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
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
            SnackBar(
              content: Text('保存済みセッションの読み込みに失敗しました'),               
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

  // ロードに必要な処理を実行するラッパー
  Future<void> _loadSavedSessions({bool force = false}) async {
    if (!mounted) return;
    final bool shouldPerformLoad = await _prepareLoadSavedSessions(force: force);
    if (shouldPerformLoad && mounted) {
      await _performLoadSavedSessions();
    }
  }

// ----------------------------------------------------------<データロード処理:ここまで>

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

  // セッション削除の確認ダイアログを表示し、選択されたセッションを削除する
  Future<void> _deleteSelectedSessions() async {
    if (_selectedSessionIds.isEmpty) return;

    if(!mounted) return;
    final bool? confirmDelete = await showConfirmationDialog(
      context: context,
      title: 'セッション削除の確認',
      content: '選択した ${_selectedSessionIds.length} 件のセッションを本当に削除しますか？この操作は元に戻せません。',
    );
    if(confirmDelete != true) return;
    
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    _savedSessions.removeWhere((session) => _selectedSessionIds.contains(session.id));
    final String updatedSessionsJson = jsonEncode(_savedSessions.map((s) => s.toJson()).toList());
    
    if (!mounted) return;
    await prefs.setString(_savedSessionsKey, updatedSessionsJson);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_selectedSessionIds.length} 件のセッションを削除しました。'),
        ),
      );
      _clearSelection();
        setState(() { 
        _isLoading = false; // 画面から削除されたことを即時反映するためにisLoadingをfalseに
      });
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
        onPressed: _clearSelection,
      );
      titleWidget = Text('${_selectedSessionIds.length} item selected', style: textTheme.titleMedium);
      actionsWidgets = null;
    } else {
      leadingWidget = null;
      titleWidget = const Text('History');
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
          backgroundColor: colorScheme.surface,
          elevation: 0,
          scrolledUnderElevation: 0.0,
          surfaceTintColor: colorScheme.surface,
          leading: leadingWidget,
          title: titleWidget,
          actions: actionsWidgets,
          automaticallyImplyLeading: _isSelectionMode,
        ),
        body: _isLoading
            ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
            : _savedSessions.isEmpty
                ? Center(
                    child: 
                      Text(
                        'No items',
                        textAlign: TextAlign.center,
                      ),
                  )
                : ListView.builder(
                    itemCount: _savedSessions.length,
                    itemBuilder: (context, index) {
                      final session = _savedSessions[index];
                      final isSelected = _selectedSessionIds.contains(session.id);
                      final String formattedDate = DateFormat('yyyy/MM/dd HH:mm').format(session.saveDate);

                      final Color? cardBackgroundColor = isSelected
                          ? colorScheme.primary.withAlpha(Scale.alpha12)
                          : theme.cardTheme.color;

                      Widget subtitleWidget = Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.calendar_month_outlined,
                            size: 14,
                            color: textTheme.bodySmall?.color?.withAlpha(Scale.alpha70), 
                          ),
                          const SizedBox(width: 4),
                          Text(
                            formattedDate,
                            style: textTheme.bodySmall?.copyWith(
                              color: textTheme.bodySmall?.color?.withAlpha(Scale.alpha70), 
                            ),
                          ),
                        ],
                      );

                      return Card(
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
                                    color: isSelected ? colorScheme.primary : iconTheme.color?.withAlpha(Scale.alpha60),
                                  )
                                : Icon(
                                    isSelected ? Icons.radio_button_unchecked : Icons.radio_button_unchecked,
                                  ),
                            title: Text(session.title, style: textTheme.titleMedium),
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
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
              )
            : null,
      ),
    );
  }
}
