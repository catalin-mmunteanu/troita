import 'dart:math' as math;

import 'package:sqflite/sqflite.dart';

import '../models/church.dart';
import '../models/feast_calendar.dart';
import 'church_repository.dart';

/// Reads the same SQLite file the native background path uses.
///
/// Opened read-only: Kotlin is the single writer. Two writers on one file is
/// the kind of thing that works in testing and corrupts on a cheap phone during
/// a Doze wake-up.
class LocalChurchRepository implements ChurchRepository {
  LocalChurchRepository(this._db);

  final Database _db;

  static Future<LocalChurchRepository> open(String path) async =>
      LocalChurchRepository(await openDatabase(path, readOnly: true));

  static const String _cols =
      'id, name, kind, denomination, lat, lon, patron, feast_day, year_built, '
      'history, photo_ref, priority, address';

  @override
  Future<List<Church>> nearby({
    required double lat,
    required double lon,
    double radiusM = 20000,
    int limit = 100,
  }) async {
    // Bounding-box prefilter on the indexed columns, then an exact haversine
    // sort in memory. sqflite has no spatial extension and at county scale the
    // in-memory pass is sub-millisecond, so this is not worth optimising until
    // the dataset is national.
    final double dLat = _degLat(radiusM);
    final double dLon = _degLon(radiusM, lat);

    final List<Map<String, Object?>> rows = await _db.query(
      'churches',
      columns: _cols.split(', '),
      where: 'deleted = 0 AND lat BETWEEN ? AND ? AND lon BETWEEN ? AND ?',
      whereArgs: <Object?>[lat - dLat, lat + dLat, lon - dLon, lon + dLon],
    );

    final List<Church> withDistance = rows
        .map(Church.fromRow)
        .map((Church c) => c.copyWith(
              distanceM: _haversineM(lat, lon, c.lat, c.lon),
            ))
        .where((Church c) => c.distanceM! <= radiusM)
        .toList()
      ..sort((Church a, Church b) => a.distanceM!.compareTo(b.distanceM!));

    return withDistance.take(limit).toList(growable: false);
  }

  @override
  Future<Church?> byId(String id) async {
    final List<Map<String, Object?>> rows = await _db.query(
      'churches',
      columns: _cols.split(', '),
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    return rows.isEmpty ? null : Church.fromRow(rows.first);
  }

  @override
  Future<List<Church>> search(String query, {int limit = 50}) async {
    final String folded = foldForSearch(query);
    if (folded.isEmpty) return const <Church>[];

    // Matched against the precomputed search_fold column rather than name,
    // patron and address directly. SQLite has no unaccent, so a LIKE on the
    // raw columns cannot match "Voronet" against "Voroneț" — and on a phone
    // keyboard nobody types ț or ă. The column is built by hram._fold at seed
    // time and holds name, hram and address together, which is why "Curtici"
    // finds the churches in that village and "Parascheva" finds the ones
    // dedicated to her.
    final List<Map<String, Object?>> rows = await _db.query(
      'churches',
      columns: _cols.split(', '),
      where: 'deleted = 0 AND search_fold LIKE ?',
      whereArgs: <Object?>['%$folded%'],
      orderBy: 'priority DESC, name ASC',
      limit: limit,
    );
    return rows.map(Church.fromRow).toList(growable: false);
  }

  /// Must produce the same text as `hram._fold` in tool/build_seed.py.
  ///
  /// Two implementations of one rule is a liability, so the rule is kept
  /// deliberately small: lowercase, strip Romanian diacritics, replace anything
  /// that is not a letter or digit with a space, collapse the spaces. If this
  /// ever diverges from the Python, search stops matching and nothing else
  /// breaks — so the failure is at least loud in testing.
  static String foldForSearch(String input) {
    const Map<String, String> diacritics = <String, String>{
      'ș': 's', 'ş': 's', 'ț': 't', 'ţ': 't',
      'ă': 'a', 'â': 'a', 'á': 'a', 'à': 'a',
      'î': 'i', 'í': 'i',
      'é': 'e', 'è': 'e', 'ê': 'e',
      'ó': 'o', 'ö': 'o',
      'ú': 'u', 'ü': 'u',
    };

    final String lower = input.toLowerCase();
    final StringBuffer out = StringBuffer();
    for (final String ch in lower.split('')) {
      final String mapped = diacritics[ch] ?? ch;
      final int code = mapped.codeUnitAt(0);
      final bool alnum = (code >= 0x61 && code <= 0x7A) || // a-z
          (code >= 0x30 && code <= 0x39); // 0-9
      out.write(alnum ? mapped : ' ');
    }
    final String folded =
        out.toString().replaceAll(RegExp(r'\s+'), ' ').trim();

    // Same fallback the seed uses: a query in an alphabet this does not know
    // folds to nothing, and searching for nothing would match every row.
    // Falling back to the trimmed original keeps the Cyrillic names the border
    // margin drags in reachable by anyone who can type them.
    return folded.isEmpty ? lower.trim() : folded;
  }

  @override
  Future<List<Church>> upcomingFeasts({int days = 14, int limit = 50}) async {
    // Movable feasts can't be expressed in SQL, so the filter happens in Dart.
    // The table is small enough that reading the feast column for every row is
    // cheaper than maintaining a materialised per-year feast date.
    final List<Map<String, Object?>> rows = await _db.query(
      'churches',
      columns: _cols.split(', '),
      where: 'deleted = 0 AND feast_day IS NOT NULL',
    );

    final List<Church> churches = rows.map(Church.fromRow).toList();
    final List<Church> soon = churches.where((Church c) {
      final int? until = FeastCalendar.daysUntil(c.feastDay);
      return until != null && until <= days;
    }).toList()
      ..sort((Church a, Church b) {
        final int cmp = (FeastCalendar.daysUntil(a.feastDay) ?? 999)
            .compareTo(FeastCalendar.daysUntil(b.feastDay) ?? 999);
        return cmp != 0 ? cmp : b.priority.compareTo(a.priority);
      });

    return soon.take(limit).toList(growable: false);
  }

  Future<Map<String, String>> meta() async {
    final List<Map<String, Object?>> rows = await _db.query('meta');
    return <String, String>{
      for (final Map<String, Object?> r in rows)
        r['key']! as String: r['value']! as String,
    };
  }

  @override
  Future<Map<String, Object?>> allAsGeoJson() async {
    final List<Map<String, Object?>> rows = await _db.query(
      'churches',
      columns: <String>['id', 'name', 'kind', 'lat', 'lon'],
      where: 'deleted = 0 AND lat IS NOT NULL AND lon IS NOT NULL',
    );

    final List<Map<String, Object?>> features = <Map<String, Object?>>[];
    int since = 0;
    for (final Map<String, Object?> r in rows) {
      // Yield periodically: this runs on the UI isolate, because sqflite has
      // to, and thirteen thousand rows in one uninterrupted pass is long
      // enough to drop frames while the map is appearing.
      if (++since >= 4000) {
        since = 0;
        await Future<void>.delayed(Duration.zero);
      }
      features.add(<String, Object?>{
        'type': 'Feature',
        'geometry': <String, Object?>{
          'type': 'Point',
          'coordinates': <Object?>[r['lon'], r['lat']],
        },
        'properties': <String, Object?>{
          'id': r['id'],
          'name': r['name'] ?? '',
          'kind': r['kind'] ?? 'church',
        },
      });
    }

    return <String, Object?>{
      'type': 'FeatureCollection',
      'features': features,
    };
  }

  Future<int> count() async =>
      Sqflite.firstIntValue(
        await _db.rawQuery('SELECT COUNT(*) FROM churches WHERE deleted = 0'),
      ) ??
      0;

  Future<void> close() => _db.close();

  // ------------------------------------------------------------------ maths

  static const double _earthR = 6371008.8;

  static double _degLat(double m) => m / _earthR * 180 / math.pi;

  static double _degLon(double m, double lat) =>
      m / (_earthR * math.max(0.0001, math.cos(lat * math.pi / 180))) *
      180 /
      math.pi;

  static double _haversineM(
      double aLat, double aLon, double bLat, double bLon) {
    final double p1 = aLat * math.pi / 180;
    final double p2 = bLat * math.pi / 180;
    final double dp = p2 - p1;
    final double dl = (bLon - aLon) * math.pi / 180;
    final double h = math.sin(dp / 2) * math.sin(dp / 2) +
        math.cos(p1) * math.cos(p2) * math.sin(dl / 2) * math.sin(dl / 2);
    return 2 * _earthR * math.asin(math.min(1, math.sqrt(h)));
  }
}
