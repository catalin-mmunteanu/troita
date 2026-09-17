import '../models/church.dart';

/// The one query contract.
///
/// The local SQLite implementation and the future `GET /churches/nearby`
/// endpoint both satisfy this interface and return identical shapes. Keeping
/// the signatures identical now is what makes the backend migration additive
/// instead of a rewrite — see [ChurchSyncService] for the other half.
abstract interface class ChurchRepository {
  /// Nearest churches to a point, ordered by great-circle distance.
  ///
  /// Server equivalent:
  ///   SELECT * FROM churches
  ///   WHERE NOT deleted AND ST_DWithin(geom, :point::geography, :radius)
  ///   ORDER BY geom <-> :point
  ///   LIMIT :limit;
  Future<List<Church>> nearby({
    required double lat,
    required double lon,
    double radiusM = 20000,
    int limit = 100,
  });

  Future<Church?> byId(String id);

  Future<List<Church>> search(String query, {int limit = 50});

  /// Churches whose hram falls within [days] — the "hram în apropiere" feed.
  Future<List<Church>> upcomingFeasts({int days = 14, int limit = 50});

  /// Every church as a GeoJSON `FeatureCollection`, for the map.
  ///
  /// A decoded map rather than a JSON string, and that distinction is
  /// load-bearing: MapLibre's Android bridge treats a `String` in a source's
  /// `data` as a *URL* to fetch, so handing it the document itself produces a
  /// source that silently fails to be created. The map then draws perfectly
  /// and shows nothing.
  ///
  /// Not a list of [Church] either — at thirteen thousand points that would
  /// build thirteen thousand model objects only to discard them.
  /// Properties carry what a marker or cluster label needs; the detail page
  /// reloads the full row by id when it is actually opened.
  ///
  /// Server equivalent: `SELECT json_build_object(...)` / ST_AsGeoJSON.
  Future<Map<String, Object?>> allAsGeoJson();
}
