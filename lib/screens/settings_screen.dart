// settings_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late List<String> _suggestions;
  bool _isLoading = true;
  final TextEditingController _suggestionAddController = TextEditingController();
  final TextEditingController _suggestionEditController = TextEditingController();

  static const String _suggestionsKey = 'comment_suggestions';

  @override
  void initState() {
    super.initState();
    _suggestions = [];
    _loadSuggestions();
  }

  Future<void> _loadSuggestions() async {
    setState(() {
      _isLoading = true;
    });
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _suggestions = prefs.getStringList(_suggestionsKey) ?? [];
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSuggestions() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_suggestionsKey, _suggestions);
  }

  void _addSuggestion() {
    final String newSuggestion = _suggestionAddController.text.trim();
    // テーマから色を取得
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    if (newSuggestion.isNotEmpty && !_suggestions.contains(newSuggestion)) {
      setState(() {
        _suggestions.add(newSuggestion);
        _suggestionAddController.clear();
      });
      _saveSuggestions();
    } else if (newSuggestion.isNotEmpty && _suggestions.contains(newSuggestion)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('このサジェスチョンは既に追加されています。', style: TextStyle(color: colorScheme.onError)),
          backgroundColor: colorScheme.error,
        ),
      );
    }
  }

  void _removeSuggestion(int index) {
    setState(() {
      _suggestions.removeAt(index);
    });
    _saveSuggestions();
  }

  Future<void> _editSuggestion(int index) async {
    _suggestionEditController.text = _suggestions[index];
    // テーマから色を取得 (ダイアログ内で Theme.of(context) を使うため、ここで取得しなくても良いが、
    // もしダイアログのボタンの色などをこのメソッド内で制御したい場合はここで取得)
    // final ColorScheme colorScheme = Theme.of(context).colorScheme;
    // final TextTheme textTheme = Theme.of(context).textTheme;

    final String? updatedSuggestion = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        // ダイアログ内でテーマを取得
        final ThemeData theme = Theme.of(dialogContext);
        final ColorScheme colorSchemeDialog = theme.colorScheme;
        final TextTheme textThemeDialog = theme.textTheme;

        return AlertDialog(
          // titleTextStyle, contentTextStyle は app_theme.dart の dialogTheme から適用される想定
          title: const Text('サジェスチョンを編集'),
          content: TextField(
            controller: _suggestionEditController,
            autofocus: true,
            // decoration は app_theme.dart の inputDecorationTheme から適用される想定
            decoration: const InputDecoration(hintText: "新しいサジェスチョン"),
            // style は app_theme.dart の textTheme から適用される想定
          ),
          actions: <Widget>[
            TextButton(
              // TextButton のスタイルは app_theme.dart の textButtonTheme から適用される想定
              // child: Text('破棄', style: TextStyle(color: colorSchemeDialog.secondary)), // 個別に色を変えたい場合
              child: const Text('破棄'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              // child: Text('保存', style: TextStyle(color: colorSchemeDialog.primary)), // 個別に色を変えたい場合
              child: const Text('保存'),
              onPressed: () {
                Navigator.of(dialogContext).pop(_suggestionEditController.text.trim());
              },
            ),
          ],
        );
      },
    );

    if (!mounted) return;
    // テーマから色を取得
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    if (updatedSuggestion != null && updatedSuggestion.isNotEmpty) {
      if (!_suggestions.contains(updatedSuggestion) || _suggestions[index] == updatedSuggestion) {
        setState(() {
          _suggestions[index] = updatedSuggestion;
        });
        _saveSuggestions();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('この名前は重複しています。', style: TextStyle(color: colorScheme.onError)),
            backgroundColor: colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // テーマから色やスタイルを取得
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final TextTheme textTheme = theme.textTheme;
    final IconThemeData iconTheme = theme.iconTheme;

    return Scaffold(
      // AppBarのスタイルは app_theme.dart の appBarTheme から適用される想定
      appBar: AppBar(
        title: const Text('サジェスト設定'), // titleTextStyle は appBarTheme から
      ),
      body: SafeArea(
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  // CircularProgressIndicator の色は colorScheme.primary になるのが一般的
                  // color: colorScheme.primary, // 明示的に指定も可能
                ),
              )
            : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: TextField(
                            controller: _suggestionAddController,
                            // decoration は app_theme.dart の inputDecorationTheme から適用される想定
                            decoration: const InputDecoration(
                              labelText: '新しいサジェスチョン',
                              hintText: '例: 会議',
                            ),
                            onSubmitted: (_) => _addSuggestion(),
                            // style は app_theme.dart の textTheme から適用される想定
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          // ElevatedButton のスタイルは app_theme.dart の elevatedButtonTheme から適用される想定
                          onPressed: _addSuggestion,
                          child: const Text('追加'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Expanded(
                      child: _suggestions.isEmpty
                          ? Center(child: Text('データがありません', style: textTheme.bodyMedium))
                          : ListView.builder(
                              itemCount: _suggestions.length,
                              itemBuilder: (context, index) {
                                final suggestion = _suggestions[index];
                                return Card(
                                  // Card のスタイルは app_theme.dart の cardTheme から適用される想定
                                  margin: const EdgeInsets.symmetric(vertical: 4.0),
                                  child: ListTile(
                                    // title のスタイルは textTheme.titleMedium や subtitle1 などが適用される想定
                                    title: Text(suggestion),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined),
                                          // アイコンの色は iconTheme.color または colorScheme.primary を使用
                                          color: iconTheme.color, // デフォルトのアイコン色
                                          // color: colorScheme.primary, // プライマリアクションとして強調する場合
                                          tooltip: '編集',
                                          onPressed: () => _editSuggestion(index),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outlined),
                                          color: colorScheme.error, // 削除はエラーカラーを使用
                                          tooltip: '削除',
                                          onPressed: () => _removeSuggestion(index),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
