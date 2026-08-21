/// Mirrors `tool/schema.sql` exactly, which in turn is the future API DTO.
///
/// One shape, three consumers: the bundled seed, the on-device mirror, and the
/// eventual `GET /churches/nearby` response. If this class and the SQL ever
/// disagree, the SQL wins — change it there first.
class Church {
  const Church({
    required this.id,
    required this.name,
    required this.kind,
    required this.lat,
    required this.lon,
    this.denomination,
    this.patron,
    this.feastDay,
    this.yearBuilt,
    this.history,
    this.photoRef,
    this.geofenceRadiusM,
    this.priority = 0,
    this.address,
    this.distanceM,
  });

  final String id;
  final String name;
  final String kind;
  final double lat;
  final double lon;
  final String? denomination;
  final String? patron;

  /// Either `MM-DD` or `movable:<key>`; resolve with [FeastCalendar].
  final String? feastDay;
  final int? yearBuilt;
  final String? history;
  final String? photoRef;
  final int? geofenceRadiusM;
  final int priority;
  final String? address;

  /// Populated by proximity queries only; never persisted.
  final double? distanceM;

  bool get isWayside => kind == 'wayside_cross';

  factory Church.fromRow(Map<String, Object?> row) => Church(
        id: row['id']! as String,
        name: row['name']! as String,
        kind: row['kind']! as String,
        lat: (row['lat']! as num).toDouble(),
        lon: (row['lon']! as num).toDouble(),
        denomination: row['denomination'] as String?,
        patron: row['patron'] as String?,
        feastDay: row['feast_day'] as String?,
        yearBuilt: (row['year_built'] as num?)?.toInt(),
        history: row['history'] as String?,
        photoRef: row['photo_ref'] as String?,
        geofenceRadiusM: (row['geofence_radius_m'] as num?)?.toInt(),
        priority: (row['priority'] as num?)?.toInt() ?? 0,
        address: row['address'] as String?,
        distanceM: (row['distance_m'] as num?)?.toDouble(),
      );

  Church copyWith({double? distanceM}) => Church(
        id: id,
        name: name,
        kind: kind,
        lat: lat,
        lon: lon,
        denomination: denomination,
        patron: patron,
        feastDay: feastDay,
        yearBuilt: yearBuilt,
        history: history,
        photoRef: photoRef,
        geofenceRadiusM: geofenceRadiusM,
        priority: priority,
        address: address,
        distanceM: distanceM ?? this.distanceM,
      );
}
