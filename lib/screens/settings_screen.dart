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
 
    final String? updatedSuggestion = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {

        return AlertDialog(
          title: const Text('サジェスチョンを編集'),
          content: TextField(
            controller: _suggestionEditController,
            autofocus: true,
            decoration: const InputDecoration(hintText: "新しいサジェスチョン"),
          ),
          actions: <Widget>[
            TextButton(
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
      appBar: AppBar(
        title: const Text('サジェスト設定'), // titleTextStyle は appBarTheme から
      ),
      body: SafeArea(
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(
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
                            decoration: const InputDecoration(
                              labelText: '新しいサジェスチョン',
                              hintText: '例: 会議',
                            ),
                            onSubmitted: (_) => _addSuggestion(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
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
                                  margin: const EdgeInsets.symmetric(vertical: 4.0),
                                  child: ListTile(
                                    title: Text(suggestion),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined),
                                          color: iconTheme.color, // デフォルトのアイコン色
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
