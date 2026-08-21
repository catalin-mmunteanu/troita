package ro.troita.data

/**
 * Mirrors the `churches` table one-to-one, which in turn mirrors the future
 * API DTO. If you add a field, add it in tool/schema.sql first.
 */
data class Church(
    val id: String,
    val name: String,
    val kind: String,
    val denomination: String?,
    val lat: Double,
    val lon: Double,
    val patron: String?,
    val feastDay: String?,
    val yearBuilt: Int?,
    val history: String?,
    val photoRef: String?,
    val geofenceRadiusM: Int?,
    val priority: Int,
    val address: String?,
    val distanceM: Double = 0.0,
) {
    fun toMap(): Map<String, Any?> = mapOf(
        "id" to id, "name" to name, "kind" to kind, "denomination" to denomination,
        "lat" to lat, "lon" to lon, "patron" to patron, "feast_day" to feastDay,
        "year_built" to yearBuilt, "history" to history, "photo_ref" to photoRef,
        "geofence_radius_m" to geofenceRadiusM, "priority" to priority,
        "address" to address, "distance_m" to distanceM,
    )
}
