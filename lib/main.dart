import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Clipboardのために必要
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart'; // ★追加: shared_preferencesをインポート
import 'settings_screen.dart'; 

// アプリケーションのメイン関数
void main() {
  runApp(const ActivityWatchApp());
}

// ログエントリのデータ構造
class LogEntry {
  final DateTime actualSessionStartTime; 
  final String startTime; 
  final String endTime;   
  String memo;      

  LogEntry({
    required this.actualSessionStartTime,
    required this.startTime,
    required this.endTime,
    required this.memo,
  });
}

// アプリケーションのルートウィジェット
class ActivityWatchApp extends StatelessWidget {
  const ActivityWatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        primarySwatch: Colors.blue,
        dialogTheme: DialogTheme(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
        ),
        dataTableTheme: DataTableThemeData(
          dataRowMinHeight: 48, 
          columnSpacing: 16, 
          headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 14),
        ),
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(
            foregroundColor: Colors.grey[700],
          )
        ),
      ),
      home: const StopwatchScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// ストップウォッチ画面のウィジェット
class StopwatchScreen extends StatefulWidget {
  const StopwatchScreen({super.key});

  @override
  State<StopwatchScreen> createState() => _StopwatchScreenState();
}

// ストップウォッチ画面の状態を管理するクラス
class _StopwatchScreenState extends State<StopwatchScreen> {
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  bool _isRunning = false; 
  String _elapsedTime = '00:00:00:00'; 
  final TextEditingController _logMemoController = TextEditingController();
  final TextEditingController _editLogMemoController = TextEditingController(); 

  final List<LogEntry> _logs = [];
  DateTime? _currentActualSessionStartTime; 

  List<String> _commentSuggestions = [];
  // ★追加: SharedPreferencesのキー (SettingsScreenと共通)
  static const String _suggestionsKey = 'comment_suggestions';

  @override
  void initState() {
    super.initState();
    _loadInitialSuggestions(); // ★追加: アプリ起動時にサジェスチョンを読み込む
  }

  // ★追加: SharedPreferencesからサジェスチョンリストを読み込むメソッド
  Future<void> _loadInitialSuggestions() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _commentSuggestions = prefs.getStringList(_suggestionsKey) ?? []; // 保存されたものがなければ空リスト
    });
  }


  // カタカナをひらがなに変換するユーティリティ関数
  String _katakanaToHiragana(String katakana) {
    return katakana.replaceAllMapped(RegExp(r'[\u30A1-\u30F6]'), (match) {
      return String.fromCharCode(match.group(0)!.codeUnitAt(0) - 0x60);
    });
  }

  // メインのフローティングアクションボタンの処理
  void _handleFABPress() {
    setState(() {
      if (_isRunning) {
        _showLogDialog(_formatLogTime(_stopwatch.elapsed)); 
      } else {
        _logs.clear(); 
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
          setState(() {
            _elapsedTime = _formatDisplayTime(_stopwatch.elapsed); 
          });
        });
        _isRunning = true;
      }
    });
  }

  // カウンターを停止する処理
  void _stopCounter() {
    setState(() {
      if (_isRunning) { 
        _stopwatch.stop();
        _timer?.cancel();
        _isRunning = false;
      }
    });
  }

  // DateTimeをCSV用の文字列にフォーマットするヘルパー
  String _formatDateTimeForCsv(DateTime dt) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return "${dt.year.toString().padLeft(4, '0')}-${twoDigits(dt.month)}-${twoDigits(dt.day)} ${twoDigits(dt.hour)}:${twoDigits(dt.minute)}:${twoDigits(dt.second)}";
  }

  // ログデータをCSV形式の文字列に変換するメソッド
  String _generateCsvData() {
    final StringBuffer csvBuffer = StringBuffer();
    csvBuffer.writeln('SESSION,START,END,COMMENT'); 
    for (int i = _logs.length - 1; i >= 0; i--) {
      final log = _logs[i];
      final memoField = '"${log.memo.replaceAll('"', '""')}"';
      final String formattedActualStartTime = _formatDateTimeForCsv(log.actualSessionStartTime);
      csvBuffer.writeln('$formattedActualStartTime,${log.startTime},${log.endTime},$memoField');
    }
    return csvBuffer.toString();
  }

  // ログデータを共有する処理
  void _shareLogs() {
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
    await showDialog<void>( 
      context: context,
      barrierDismissible: true, 
      builder: (BuildContext dialogContext) { 
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
                          if (textEditingValue.text == '') {
                            return const Iterable<String>.empty();
                          }
                          final String inputTextHiragana = _katakanaToHiragana(textEditingValue.text.toLowerCase());
                          return _commentSuggestions.where((String option) {
                            final String optionHiragana = _katakanaToHiragana(option.toLowerCase());
                            return optionHiragana.contains(inputTextHiragana);
                          });
                        },
                        onSelected: (String selection) {
                          _logMemoController.text = selection;
                        },
                        fieldViewBuilder: (BuildContext context, TextEditingController fieldTextEditingController,
                            FocusNode fieldFocusNode, VoidCallback onFieldSubmitted) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                             if (fieldTextEditingController.text != _logMemoController.text) {
                                fieldTextEditingController.text = _logMemoController.text;
                             }
                          });
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
                                      onTap: () {
                                        onSelected(option);
                                      },
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
                      if (memo.isEmpty) {
                        memo = '(活動終了)'; 
                      }
                      final String startTime = _logs.isEmpty ? '00:00:00' : _logs.last.endTime;
                      final newLog = LogEntry(
                        actualSessionStartTime: _currentActualSessionStartTime!, 
                        startTime: startTime,
                        endTime: timeForLogDialog, 
                        memo: memo, 
                      );
                      setState(() { 
                        _logs.add(newLog); 
                      });
                      Navigator.of(dialogContext).pop(); 
                      _stopCounter(); 
                    },
                  ),
                ),
                const Spacer(), 
                Tooltip(
                  message: '保存して記録を続ける',
                  child: IconButton(
                    icon: Icon(Icons.edit, color: Theme.of(dialogContext).primaryColor, size: 28), 
                    onPressed: () {
                      String memo = _logMemoController.text.trim();
                      if (memo.isEmpty) {
                        memo = '(ラップを記録)';
                      }
                      final String startTime = _logs.isEmpty ? '00:00:00' : _logs.last.endTime;
                      final newLog = LogEntry(
                        actualSessionStartTime: _currentActualSessionStartTime!, 
                        startTime: startTime,
                        endTime: timeForLogDialog, 
                        memo: memo, 
                      );
                      setState(() { 
                        _logs.add(newLog); 
                      });
                      Navigator.of(dialogContext).pop(); 
                    },
                  ),
                ),
              ],
            );
      },
    );
  }

  Future<void> _showEditLogDialog(int logIndex) async {
    final LogEntry currentLog = _logs[logIndex];
    _editLogMemoController.text = currentLog.memo; 

    await showDialog<void>(
      context: context,
      barrierDismissible: true, 
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Edit COMMENT'),
          contentPadding: const EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 0),
          content: SizedBox(
            width: MediaQuery.of(dialogContext).size.width * 0.8,
            child: Autocomplete<String>(
              initialValue: TextEditingValue(text: currentLog.memo), 
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text == '') {
                  return const Iterable<String>.empty();
                }
                final String inputTextHiragana = _katakanaToHiragana(textEditingValue.text.toLowerCase());
                return _commentSuggestions.where((String option) {
                  final String optionHiragana = _katakanaToHiragana(option.toLowerCase());
                  return optionHiragana.contains(inputTextHiragana);
                });
              },
              onSelected: (String selection) {
                _editLogMemoController.text = selection;
              },
              fieldViewBuilder: (BuildContext context, TextEditingController fieldTextEditingController,
                  FocusNode fieldFocusNode, VoidCallback onFieldSubmitted) {
                 WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (fieldTextEditingController.text != _editLogMemoController.text) {
                        fieldTextEditingController.text = _editLogMemoController.text;
                    }
                 });
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
                            onTap: () {
                              onSelected(option);
                            },
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
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
          actions: <Widget>[
            TextButton(
              child: const Text('Dissmiss'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            ElevatedButton(
              child: const Text('Save'),
              onPressed: () {
                final String newMemo = _editLogMemoController.text.trim();
                setState(() {
                  _logs[logIndex].memo = newMemo; 
                });
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      },
    );
  }


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
      padding: const EdgeInsets.only(left:16.0, right:0, top:8.0, bottom: 8.0), 
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
              ),
            ),
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

  // 設定画面へ遷移するメソッド
  void _navigateToSettingsScreen() async {
    final List<String>? updatedSuggestions = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SettingsScreen(initialSuggestions: List<String>.from(_commentSuggestions)),
      ),
    );

    if (updatedSuggestions != null) {
      setState(() {
        _commentSuggestions = updatedSuggestions;
        // ★変更点: StopwatchScreen側でも保存処理を呼び出す (SettingsScreenで変更があった場合)
        _saveSuggestionsToPrefs(updatedSuggestions); 
      });
    }
  }

  // ★追加: StopwatchScreen側でサジェスチョンを保存するメソッド
  Future<void> _saveSuggestionsToPrefs(List<String> suggestions) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_suggestionsKey, suggestions);
  }


  @override
  void dispose() {
    _timer?.cancel();
    _stopwatch.stop();
    _logMemoController.dispose();
    _editLogMemoController.dispose(); 
    super.dispose();
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
    return Scaffold(
      body: SafeArea( 
        child: Column( 
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Padding( 
              padding: const EdgeInsets.only(top: 50.0, bottom: 30.0), 
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
                    message: 'ログを共有 (CSV)',
                    child: IconButton(
                      icon: const Icon(Icons.share),
                      onPressed: _shareLogs, 
                    ),
                  ),
                  Tooltip(
                    message: 'サジェスト設定',
                    child: IconButton(
                      icon: const Icon(Icons.settings),
                      onPressed: _navigateToSettingsScreen,
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
    );
  }
}