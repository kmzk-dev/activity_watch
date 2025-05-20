import 'package:shared_preferences/shared_preferences.dart';

const String _suggestionsKey = 'comment_suggestions';

Future<List<String>> loadSuggestions() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  return prefs.getStringList(_suggestionsKey) ?? [];
}