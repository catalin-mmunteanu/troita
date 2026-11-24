import 'package:shared_preferences/shared_preferences.dart';

import '../models/saved_name.dart';

/// The names the user follows, on the device. A short list, so one JSON
/// string in shared_preferences rather than a table.
class SavedNamesRepository {
  static const String _key = 'saved_names';

  Future<List<SavedName>> load() async {
    final SharedPreferences p = await SharedPreferences.getInstance();
    return SavedName.decodeList(p.getString(_key));
  }

  Future<void> save(List<SavedName> names) async {
    final SharedPreferences p = await SharedPreferences.getInstance();
    await p.setString(_key, SavedName.encodeList(names));
  }
}
