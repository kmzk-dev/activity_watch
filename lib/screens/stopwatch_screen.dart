import 'dart:async';
import 'dart:convert'; // jsonDecode を使用するために必要
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../theme/color_constants.dart';
import '../models/log_entry.dart';
import '../models/saved_log_session.dart';
import 'settings_screen.dart';

class StopwatchScreenWidget extends StatefulWidget {
  const StopwatchScreenWidget({super.key});

  @override
  State<StopwatchScreenWidget> createState() => _StopwatchScreenWidgetState();
}

class _StopwatchScreenWidgetState extends State<StopwatchScreenWidget> {
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  bool _isRunning = false;
  String _elapsedTime = '00:00:00:00';
  final TextEditingController _logMemoController = TextEditingController();
  final TextEditingController _editLogMemoController = TextEditingController();
  final TextEditingController _sessionTitleController = TextEditingController();
  final TextEditingController _sessionCommentController = TextEditingController();

  // ★ final を追加
  final List<LogEntry> _logs = [];
  DateTime? _currentActualSessionStartTime;

  List<String> _commentSuggestions = [];
  static const String _suggestionsKey = 'comment_suggestions';
  static const String _savedSessionsKey = 'saved_log_sessions';
  DateTime? _lastSuggestionsLoadTime;

  String _selectedColorLabelInDialog = colorLabels.keys.first;


  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stopwatch.stop();
    _logMemoController.dispose();
    _editLogMemoController.dispose();
    _sessionTitleController.dispose();
    _sessionCommentController.dispose();
    super.dispose();
  }


  Future<void> loadSuggestionsFromPrefs({bool force = false}) async {
      if (!force && _lastSuggestionsLoadTime != null && DateTime.now().difference(_lastSuggestionsLoadTime!) < const Duration(seconds: 1)) {
      return;
    }
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
        _commentSuggestions = prefs.getStringList(_suggestionsKey) ?? [];
        _lastSuggestionsLoadTime = DateTime.now();
    });
  }

  String _katakanaToHiragana(String katakana) {
    return katakana.replaceAllMapped(RegExp(r'[\u30A1-\u30F6]'), (match) {
      return String.fromCharCode(match.group(0)!.codeUnitAt(0) - 0x60);
    });
  }

  void _handleFABPress() {
    setState(() {
      if (_isRunning) {
        _showLogDialog(_formatLogTime(_stopwatch.elapsed));
      } else {
        _logs.clear(); // final なリストでも clear() は可能
        _stopwatch.stop();
        _stopwatch.reset();
        _timer?.cancel();
        _elapsedTime = '00:00:00:00';
        _currentActualSessionStartTime = DateTime.now();

        _stopwatch.start();
        _timer = Timer.periodic(const Duration(milliseconds: 10), (timer) {
          if (!_stopwatch.isRunning) {
            timer.cancel();
            return;
          }
          if (mounted) {
            setState(() {
              _elapsedTime = _formatDisplayTime(_stopwatch.elapsed);
            });
          }
        });
        _isRunning = true;
      }
    });
  }

  void _stopCounter() {
    if (mounted) {
      setState(() {
        if (_isRunning) {
          _stopwatch.stop();
          _timer?.cancel();
          _isRunning = false;
        }
      });
    }
  }

  String _formatDateTimeForCsv(DateTime dt) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return "${dt.year.toString().padLeft(4, '0')}-${twoDigits(dt.month)}-${twoDigits(dt.day)} ${twoDigits(dt.hour)}:${twoDigits(dt.minute)}:${twoDigits(dt.second)}";
  }

  String _generateCsvData() {
    final StringBuffer csvBuffer = StringBuffer();
    csvBuffer.writeln('SESSION,START,END,COMMENT,ELAPSED,COLOR_LABEL');
    for (int i = _logs.length - 1; i >= 0; i--) {
      final log = _logs[i];
      final memoField = '"${log.memo.replaceAll('"', '""')}"';
      final String formattedActualStartTime = _formatDateTimeForCsv(log.actualSessionStartTime);
      csvBuffer.writeln('$formattedActualStartTime,${log.startTime},${log.endTime},$memoField,${log.elapsedTime},${log.colorLabelName}');
    }
    return csvBuffer.toString();
  }

  void _shareLogs() {
    if (_logs.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('共有するログがありません。')),
      );
      return;
    }
    final String csvData = _generateCsvData();
    Share.share(csvData, subject: 'ActivityWatch ログデータ');
  }

  String _formatDisplayTime(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    final milliseconds = (duration.inMilliseconds.remainder(1000) ~/ 10);
    return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}:${twoDigits(milliseconds)}';
  }

  String _formatLogTime(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  Future<void> _showLogDialog(String timeForLogDialog) async {
    _logMemoController.clear();
    _selectedColorLabelInDialog = colorLabels.keys.first;

    await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder( 
          builder: (BuildContext context, StateSetter setStateDialog) {
            return AlertDialog(
              contentPadding: const EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 0),
              titlePadding: EdgeInsets.zero,
              content: SizedBox(
                width: MediaQuery.of(dialogContext).size.width * 0.8,
                child: SingleChildScrollView(
                  child: ListBody(
                    children: <Widget>[
                      Text('LOGGING TIME: $timeForLogDialog', style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      Autocomplete<String>(
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          final query = textEditingValue.text;
                          if (query == '') return const Iterable<String>.empty();
                          final String inputTextHiragana = _katakanaToHiragana(query.toLowerCase());
                          return _commentSuggestions.where((String option) {
                            final String optionHiragana = _katakanaToHiragana(option.toLowerCase());
                            return optionHiragana.contains(inputTextHiragana);
                          });
                        },
                        onSelected: (String selection) {
                            _logMemoController.text = selection;
                            _logMemoController.selection = TextSelection.fromPosition(
                                TextPosition(offset: _logMemoController.text.length));
                        },
                        fieldViewBuilder: (BuildContext context,
                            TextEditingController fieldTextEditingController,
                            FocusNode fieldFocusNode,
                            VoidCallback onFieldSubmitted) {
                          if (fieldTextEditingController.text.isEmpty && _logMemoController.text.isNotEmpty) {
                               WidgetsBinding.instance.addPostFrameCallback((_){
                                  if(mounted && fieldTextEditingController.text.isEmpty){
                                      fieldTextEditingController.text = _logMemoController.text;
                                  }
                                });
                          }
                          return TextField(
                            controller: fieldTextEditingController,
                            focusNode: fieldFocusNode,
                            autofocus: true,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              labelText: 'COMMENT',
                              hintText: 'Enter your comment here',
                            ),
                            maxLines: 1,
                            keyboardType: TextInputType.text,
                            inputFormatters: [
                              FilteringTextInputFormatter.deny(RegExp(r'[\n\r]')),
                            ],
                            onChanged: (text) {
                                _logMemoController.text = text;
                            },
                            onSubmitted: (_){
                              onFieldSubmitted();
                            },
                          );
                        },
                        optionsViewBuilder: (BuildContext context, AutocompleteOnSelected<String> onSelected, Iterable<String> options) {
                            return Align(
                              alignment: Alignment.topLeft,
                              child: Material(
                                elevation: 4.0,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(maxHeight: 200, maxWidth: MediaQuery.of(dialogContext).size.width * 0.8 - 48),
                                  child: ListView.builder(
                                    padding: EdgeInsets.zero,
                                    itemCount: options.length,
                                    itemBuilder: (BuildContext context, int index) {
                                      final String option = options.elementAt(index);
                                      return InkWell(
                                        onTap: () => onSelected(option),
                                        child: Padding(
                                          padding: const EdgeInsets.all(16.0),
                                          child: Text(option),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            );
                        },
                      ),
                      const SizedBox(height: 16), 
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: '色ラベル',
                          border: OutlineInputBorder(),
                        ),
                        value: _selectedColorLabelInDialog,
                        items: colorLabels.keys.map((String labelName) {
                          return DropdownMenuItem<String>(
                            value: labelName,
                            child: Row(
                              children: [
                                Icon(Icons.circle, color: colorLabels[labelName], size: 16),
                                const SizedBox(width: 8),
                                Text(labelName),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setStateDialog(() { 
                              _selectedColorLabelInDialog = newValue;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
              actions: <Widget>[
                Tooltip(
                  message: '終了して記録',
                  child: IconButton(
                    icon: const Icon(Icons.stop_circle, color: Colors.redAccent, size: 28),
                    onPressed: () {
                      String memo = _logMemoController.text.trim();
                      if (memo.isEmpty) memo = '(活動終了)';
                      final String startTime = _logs.isEmpty ? '00:00:00' : _logs.last.endTime;
                      final newLog = LogEntry(
                        actualSessionStartTime: _currentActualSessionStartTime!,
                        startTime: startTime,
                        endTime: timeForLogDialog,
                        memo: memo,
                        colorLabelName: _selectedColorLabelInDialog,
                      );
                      newLog.calculateDuration();
                      if (mounted) setState(() => _logs.add(newLog));
                      Navigator.of(dialogContext).pop(true);
                      _stopCounter();
                    },
                  ),
                ),
                const Spacer(),
                Tooltip(
                  message: '保存して記録を続ける',
                  child: IconButton(
                    icon: Icon(Icons.edit, color: Theme.of(dialogContext).colorScheme.primary, size: 28),
                    onPressed: () {
                      String memo = _logMemoController.text.trim();
                      if (memo.isEmpty) memo = '(ラップを記録)';
                      final String startTime = _logs.isEmpty ? '00:00:00' : _logs.last.endTime;
                      final newLog = LogEntry(
                        actualSessionStartTime: _currentActualSessionStartTime!,
                        startTime: startTime,
                        endTime: timeForLogDialog,
                        memo: memo,
                        colorLabelName: _selectedColorLabelInDialog,
                      );
                      newLog.calculateDuration();
                        if (mounted) setState(() => _logs.add(newLog));
                      Navigator.of(dialogContext).pop(true);
                    },
                  ),
                ),
              ],
            );
          }
        );
      },
    );

    if (!mounted) return;
    FocusScope.of(context).unfocus();
  }

  Future<void> _showEditLogDialog(int logIndex) async {
    final LogEntry currentLog = _logs[logIndex];
    _editLogMemoController.text = currentLog.memo;
    
    String selectedColorLabelInEditDialog = currentLog.colorLabelName;


    await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setStateDialog) {
            return AlertDialog(
              title: const Text('Edit COMMENT'),
              contentPadding: const EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 0),
              content: SizedBox(
                width: MediaQuery.of(dialogContext).size.width * 0.8,
                child: SingleChildScrollView( 
                  child: Column( 
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Autocomplete<String>(
                        initialValue: TextEditingValue(text: _editLogMemoController.text),
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          final query = textEditingValue.text;
                          if (query == '') return const Iterable<String>.empty();
                          final String inputTextHiragana = _katakanaToHiragana(query.toLowerCase());
                          return _commentSuggestions.where((String option) {
                            final String optionHiragana = _katakanaToHiragana(option.toLowerCase());
                            return optionHiragana.contains(inputTextHiragana);
                          });
                        },
                        onSelected: (String selection) {
                          _editLogMemoController.text = selection;
                          _editLogMemoController.selection = TextSelection.fromPosition(
                                TextPosition(offset: _editLogMemoController.text.length));
                        },
                        fieldViewBuilder: (BuildContext context,
                            TextEditingController fieldTextEditingController,
                            FocusNode fieldFocusNode,
                            VoidCallback onFieldSubmitted) {
                              if (fieldTextEditingController.text.isEmpty && _editLogMemoController.text.isNotEmpty) {
                                   WidgetsBinding.instance.addPostFrameCallback((_){
                                      if(mounted && fieldTextEditingController.text.isEmpty){
                                          fieldTextEditingController.text = _editLogMemoController.text;
                                      }
                                   });
                              }
                          return TextField(
                            controller: fieldTextEditingController,
                            focusNode: fieldFocusNode,
                            autofocus: true,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              labelText: 'NEW COMMENT',
                            ),
                            maxLines: 1,
                            keyboardType: TextInputType.text,
                            inputFormatters: [
                              FilteringTextInputFormatter.deny(RegExp(r'[\n\r]')),
                            ],
                              onChanged: (text) {
                                  _editLogMemoController.text = text;
                              },
                            onSubmitted: (_){
                              onFieldSubmitted();
                            },
                          );
                        },
                        optionsViewBuilder: (BuildContext context, AutocompleteOnSelected<String> onSelected, Iterable<String> options) {
                            return Align(
                              alignment: Alignment.topLeft,
                              child: Material(
                                elevation: 4.0,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(maxHeight: 200, maxWidth: MediaQuery.of(dialogContext).size.width * 0.8 - 48),
                                  child: ListView.builder(
                                    padding: EdgeInsets.zero,
                                    itemCount: options.length,
                                    itemBuilder: (BuildContext context, int index) {
                                      final String option = options.elementAt(index);
                                      return InkWell(
                                        onTap: () => onSelected(option),
                                        child: Padding(
                                          padding: const EdgeInsets.all(16.0),
                                          child: Text(option),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            );
                        },
                      ),
                      const SizedBox(height: 16), 
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: '色ラベル',
                          border: OutlineInputBorder(),
                        ),
                        // ★ アンダースコアを削除した変数を使用
                        value: selectedColorLabelInEditDialog,
                        items: colorLabels.keys.map((String labelName) {
                          return DropdownMenuItem<String>(
                            value: labelName,
                            child: Row(
                              children: [
                                Icon(Icons.circle, color: colorLabels[labelName], size: 16),
                                const SizedBox(width: 8),
                                Text(labelName),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setStateDialog(() { 
                              // ★ アンダースコアを削除した変数を使用
                              selectedColorLabelInEditDialog = newValue;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
              actions: <Widget>[
                TextButton(
                  child: const Text('Dissmiss'),
                  onPressed: () {
                    Navigator.of(dialogContext).pop(false);
                  },
                ),
                ElevatedButton(
                  child: const Text('Save'),
                  onPressed: () {
                    final String newMemo = _editLogMemoController.text.trim();
                    if (mounted) {
                      setState(() {
                        _logs[logIndex].memo = newMemo;
                        // ★ アンダースコアを削除した変数を使用
                        _logs[logIndex].colorLabelName = selectedColorLabelInEditDialog; 
                      });
                    }
                    Navigator.of(dialogContext).pop(true);
                  },
                ),
              ],
            );
          }
        );
      },
    );

    if (!mounted) return;
    FocusScope.of(context).unfocus();
  }

  Future<void> _showSaveSessionDialog() async {
    if (_logs.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('保存するログがありません。')),
      );
      return;
    }
    if (_isRunning) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('まずストップウォッチを停止してください。')),
      );
      return;
    }

    _sessionTitleController.clear();
    _sessionCommentController.clear();

    final Map<String, String>? sessionData = await showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('セッションを保存'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(
                  controller: _sessionTitleController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: "タイトル",
                    hintText: "セッションのタイトルを入力"
                  ),
                    textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _sessionCommentController,
                  decoration: const InputDecoration(
                    labelText: "コメント (任意)",
                    hintText: "セッション全体に関するコメントを入力",
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.multiline,
                  maxLines: null,
                  minLines: 3,
                  textInputAction: TextInputAction.done,
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('キャンセル'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              child: const Text('保存'),
              onPressed: () {
                if (_sessionTitleController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(content: Text('タイトルは必須です。')),
                    );
                    return;
                }
                Navigator.of(dialogContext).pop({
                  'title': _sessionTitleController.text.trim(),
                  'comment': _sessionCommentController.text.trim(),
                });
              },
            ),
          ],
        );
      },
    );

    if (!mounted) return;
    FocusScope.of(context).unfocus();

    if (sessionData != null && sessionData['title'] != null && sessionData['title']!.isNotEmpty) {
      await _saveCurrentSession(sessionData['title']!, sessionData['comment']);
    }
  }

  Future<void> _saveCurrentSession(String title, String? comment) async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    final String newSessionId = DateTime.now().millisecondsSinceEpoch.toString();

    final newSavedSession = SavedLogSession(
      id: newSessionId,
      title: title,
      sessionComment: comment,
      saveDate: DateTime.now(),
      logEntries: List<LogEntry>.from(_logs),
    );

    final String? existingSessionsJson = prefs.getString(_savedSessionsKey);
    List<SavedLogSession> savedSessions = [];
    if (existingSessionsJson != null && existingSessionsJson.isNotEmpty) {
      try {
        final List<dynamic> decodedList = jsonDecode(existingSessionsJson) as List<dynamic>;
        savedSessions = decodedList
            .map((jsonItem) => SavedLogSession.fromJson(jsonItem as Map<String, dynamic>))
            .toList();
      } catch (e) {
        savedSessions = []; 
      }
    }
    
    savedSessions.add(newSavedSession);
    savedSessions.sort((a, b) => b.saveDate.compareTo(a.saveDate));

    final String updatedSessionsJson = jsonEncode(savedSessions.map((s) => s.toJson()).toList());
    await prefs.setString(_savedSessionsKey, updatedSessionsJson);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('「$title」としてセッションを保存しました。')),
    );}


  Widget _buildLogTableHeader(BuildContext context) {
    final theme = Theme.of(context);
    final dataTableTheme = theme.dataTableTheme;
    final headingTextStyle = dataTableTheme.headingTextStyle ??
        const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 14);
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
            child: Text('END', style: headingTextStyle),
          ),
          Expanded(
            flex: 4,
            child: Text('COMMENT', style: headingTextStyle),
          ),
          Expanded(
            flex: 3,
            child: Text('ELAPSED', style: headingTextStyle),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildLogRow(BuildContext context, LogEntry log, int index) {
    final theme = Theme.of(context);
    final dataTableTheme = theme.dataTableTheme;
    final dataRowMinHeight = dataTableTheme.dataRowMinHeight ?? 48.0;
    return Container(
      constraints: BoxConstraints(minHeight: dataRowMinHeight),
      padding: const EdgeInsets.only(left: 16.0, right: 0, top: 8.0, bottom: 8.0),
      child: Row(
        children: <Widget>[
          Expanded(
            flex: 2,
            child: Text(log.endTime),
          ),
          Expanded(
            flex: 4,
            child: Tooltip(
              message: log.memo,
              child: Text(
                log.memo,
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
                style: TextStyle(color: log.labelColor), 
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(log.elapsedTime),
          ),
          SizedBox(
            width: 48,
            child: Tooltip(
              message: 'EDIT COMMENT',
              child: IconButton(
                icon: const Icon(Icons.edit_note, size: 20),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  _showEditLogDialog(index);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildFloatingActionButton() {
    if (!_isRunning) {
      return FloatingActionButton(
        onPressed: _handleFABPress,
        tooltip: '開始',
        heroTag: 'startFab',
        child: const Icon(Icons.play_arrow, size: 36.0),
      );
    } else {
      return FloatingActionButton(
        onPressed: _handleFABPress,
        tooltip: 'ラップ記録',
        heroTag: 'lapRecordFab',
        child: const Icon(Icons.format_list_bulleted_add, size: 36.0),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: const Key('stopwatch_screen_widget_visibility_detector'),
      onVisibilityChanged: (visibilityInfo) {
        final visiblePercentage = visibilityInfo.visibleFraction * 100;
        if (mounted && visiblePercentage > 50) {
          loadSuggestionsFromPrefs();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          actions: <Widget>[
            IconButton(
              icon: const Icon(Icons.settings),
              tooltip: '設定',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsScreen()),
                );
              },
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(top: 48.0, bottom: 32.0),
                child: Text(
                  _elapsedTime,
                  style: const TextStyle(
                    fontSize: 56.0,
                    fontWeight: FontWeight.bold,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              Padding( 
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Tooltip(
                      message: '現在のログを保存',
                      child: IconButton(
                        icon: const Icon(Icons.save),
                        onPressed: (_logs.isNotEmpty && !_isRunning) ? _showSaveSessionDialog : null,
                      ),
                    ),
                    Tooltip(
                      message: 'ログを共有 (CSV)',
                      child: IconButton(
                        icon: const Icon(Icons.share),
                        onPressed: _logs.isNotEmpty ? _shareLogs : null,
                      ),
                    ),
                  ],
                ),
              ),
              _buildLogTableHeader(context),
              Expanded(
                child: _logs.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            'NO DATA',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ))
                    : ListView.builder(
                        itemCount: _logs.length,
                        itemBuilder: (context, index) {
                          final logIndex = _logs.length - 1 - index;
                          return _buildLogRow(context, _logs[logIndex], logIndex);
                        },
                      ),
              ),
            ],
          ),
        ),
        floatingActionButton: SizedBox(
          width: 70.0,
          height: 70.0,
          child: _buildFloatingActionButton(),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      ),
    );
  }
}