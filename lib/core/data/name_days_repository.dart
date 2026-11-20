import 'package:flutter/services.dart';

import '../models/name_days.dart';

/// Loads the bundled name days once, on first use.
class NameDaysRepository {
  NameDaysRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  Future<NameDays>? _loading;

  static const String asset = 'assets/data/name_days.json';

  Future<NameDays> load() =>
      _loading ??= _bundle.loadString(asset).then(NameDays.parse);
}
