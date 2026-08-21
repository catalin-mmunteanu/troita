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
}
