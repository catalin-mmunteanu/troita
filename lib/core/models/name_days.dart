import 'dart:convert';

import 'feast_calendar.dart';

/// One feast with its celebrated first names, from assets/data/name_days.json.
///
/// The same file is copied to the website (troita-web: data/name-days.json),
/// so the app and troita.ro show the same names on the same day. Sources: the
/// DGEP lists published for each great feast, and saints whose own name is the
/// celebrated name. tool/check_name_days.py checks the file in CI.
class NameFeast {
  const NameFeast({
    required this.id,
    required this.saint,
    required this.source,
    required this.feastDay,
    required this.male,
    required this.female,
    this.sourceUrl,
  });

  final String id;
  final String saint;

  /// 'dgep' or 'calendar'.
  final String source;

  /// 'MM-DD' or 'movable:<key>', the format [FeastCalendar.resolve] reads.
  final String feastDay;
  final List<String> male;
  final List<String> female;
  final String? sourceUrl;

  List<String> get names => <String>[...male, ...female];

  /// The date in [year]; Sf. Gheorghe moves out of Holy Week like the feast.
  DateTime? dateIn(int year) => FeastCalendar.resolve(feastDay, year: year);

  factory NameFeast.fromJson(Map<String, Object?> j) => NameFeast(
        id: j['id']! as String,
        saint: j['saint']! as String,
        source: j['source']! as String,
        feastDay: j['date'] as String? ?? 'movable:${j['movable']}',
        male: (j['m']! as List<Object?>).cast<String>(),
        female: (j['f']! as List<Object?>).cast<String>(),
        sourceUrl: j['sourceUrl'] as String?,
      );
}

/// All name days, indexed by date and by name.
class NameDays {
  NameDays(this.feasts, {required this.primary, required this.notes});

  factory NameDays.parse(String json) {
    final Map<String, Object?> doc = jsonDecode(json) as Map<String, Object?>;
    return NameDays(
      (doc['feasts']! as List<Object?>)
          .map((Object? f) => NameFeast.fromJson(f! as Map<String, Object?>))
          .toList(growable: false),
      primary: (doc['primary'] as Map<String, Object?>? ?? const <String, Object?>{})
          .cast<String, String>(),
      notes: (doc['notes'] as Map<String, Object?>? ?? const <String, Object?>{})
          .cast<String, String>(),
    );
  }

  final List<NameFeast> feasts;

  /// Name → feast id of the day most people keep, where a name has several.
  final Map<String, String> primary;

  /// Name → a sentence on why the name has more than one day.
  final Map<String, String> notes;

  final Map<int, Map<int, List<NameFeast>>> _byYear =
      <int, Map<int, List<NameFeast>>>{};

  static int _key(DateTime d) => d.month * 100 + d.day;

  /// The name-day feasts on [date].
  List<NameFeast> on(DateTime date) {
    final Map<int, List<NameFeast>> index =
        _byYear.putIfAbsent(date.year, () {
      final Map<int, List<NameFeast>> m = <int, List<NameFeast>>{};
      for (final NameFeast f in feasts) {
        final DateTime? d = f.dateIn(date.year);
        if (d != null) m.putIfAbsent(_key(d), () => <NameFeast>[]).add(f);
      }
      return m;
    });
    return index[_key(date)] ?? const <NameFeast>[];
  }

  /// Every name celebrated on [date], each once, in the file's order.
  List<String> namesOn(DateTime date) {
    final List<String> out = <String>[];
    for (final NameFeast f in on(date)) {
      for (final String n in f.names) {
        if (!out.contains(n)) out.add(n);
      }
    }
    return out;
  }

  /// The feasts that list [name], the primary one first.
  List<NameFeast> feastsFor(String name) {
    final List<NameFeast> list =
        feasts.where((NameFeast f) => f.names.contains(name)).toList();
    final String? p = primary[name];
    list.sort((NameFeast a, NameFeast b) =>
        (a.id == p ? 0 : 1).compareTo(b.id == p ? 0 : 1));
    return list;
  }

  /// Every distinct name, for search.
  late final List<String> allNames = <String>{
    for (final NameFeast f in feasts) ...f.names,
  }.toList(growable: false);
}
