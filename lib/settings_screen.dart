import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // ★追加: shared_preferencesをインポート

class SettingsScreen extends StatefulWidget {
  final List<String> initialSuggestions;

  const SettingsScreen({super.key, required this.initialSuggestions});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late List<String> _suggestions;
  final TextEditingController _suggestionAddController = TextEditingController();
  final TextEditingController _suggestionEditController = TextEditingController(); 

  // ★追加: SharedPreferencesのキー
  static const String _suggestionsKey = 'comment_suggestions';

  @override
  void initState() {
    super.initState();
    _suggestions = List<String>.from(widget.initialSuggestions);
    // initStateでshared_preferencesから読み込む必要はない。
    // なぜなら、StopwatchScreenから常に最新（または保存された）リストが渡されるため。
    // ただし、この画面が直接起動されるケースを考慮するなら読み込み処理があっても良い。
    // 今回はStopwatchScreen経由なので、渡されたinitialSuggestionsを信頼する。
  }

  // ★追加: サジェスチョンリストをSharedPreferencesに保存するメソッド
  Future<void> _saveSuggestions() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_suggestionsKey, _suggestions);
  }

  void _addSuggestion() {
    final String newSuggestion = _suggestionAddController.text.trim();
    if (newSuggestion.isNotEmpty && !_suggestions.contains(newSuggestion)) {
      setState(() {
        _suggestions.add(newSuggestion);
        _suggestionAddController.clear();
        _saveSuggestions(); // ★変更点: 保存処理を呼び出し
      });
    } else if (newSuggestion.isNotEmpty && _suggestions.contains(newSuggestion)) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('This Suggestion is already added.')),
        );
    }
  }

  void _removeSuggestion(int index) {
    setState(() {
      _suggestions.removeAt(index);
      _saveSuggestions(); // ★変更点: 保存処理を呼び出し
    });
  }

  Future<void> _editSuggestion(int index) async {
    _suggestionEditController.text = _suggestions[index];
    
    final String? updatedSuggestion = await showDialog<String>(
      context: context, 
      builder: (BuildContext dialogContext) { 
        return AlertDialog(
          title: const Text('Edit Suggestion'),
          content: TextField(
            controller: _suggestionEditController,
            autofocus: true,
            decoration: const InputDecoration(hintText: "New Suggestion"),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Discard'),
              onPressed: () {
                Navigator.of(dialogContext).pop(); 
              },
            ),
            TextButton(
              child: const Text('Save'),
              onPressed: () {
                Navigator.of(dialogContext).pop(_suggestionEditController.text.trim());
              },
            ),
          ],
        );
      },
    );

    if (!mounted) return; 

    if (updatedSuggestion != null && updatedSuggestion.isNotEmpty) {
      if (!_suggestions.contains(updatedSuggestion) || _suggestions[index] == updatedSuggestion) {
         setState(() {
           _suggestions[index] = updatedSuggestion;
           _saveSuggestions(); // ★変更点: 保存処理を呼び出し
         });
      } else {
         ScaffoldMessenger.of(context).showSnackBar( 
            const SnackBar(content: Text('This name is duplicated.')),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Setting Suggestions'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // 戻る際に保存されたリストを返す (StopwatchScreen側で受け取る)
            Navigator.pop(context, _suggestions);
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _suggestionAddController,
                    decoration: const InputDecoration(
                      labelText: 'New Suggestion',
                      hintText: 'Ex: Meeting',
                    ),
                    onSubmitted: (_) => _addSuggestion(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addSuggestion,
                  child: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: _suggestions.isEmpty
                  ? const Center(child: Text('NO DATA'))
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
                                  icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                                  tooltip: '編集',
                                  onPressed: () => _editSuggestion(index),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outlined, color: Colors.red),
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
    );
  }
}