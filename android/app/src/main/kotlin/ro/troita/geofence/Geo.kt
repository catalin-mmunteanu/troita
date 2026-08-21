package ro.troita.geofence

import kotlin.math.abs
import kotlin.math.asin
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin
import kotlin.math.sqrt

/** Great-circle helpers. Deliberately dependency-free: this runs in a receiver. */
object Geo {

    private const val EARTH_R = 6_371_008.8

    fun distanceM(aLat: Double, aLon: Double, bLat: Double, bLon: Double): Double {
        val p1 = Math.toRadians(aLat)
        val p2 = Math.toRadians(bLat)
        val dp = p2 - p1
        val dl = Math.toRadians(bLon - aLon)
        val h = sin(dp / 2) * sin(dp / 2) + cos(p1) * cos(p2) * sin(dl / 2) * sin(dl / 2)
        return 2 * EARTH_R * asin(min(1.0, sqrt(h)))
    }

    /** Latitude/longitude deltas that bound a circle of [radiusM] — the SQL prefilter. */
    fun bbox(lat: Double, lon: Double, radiusM: Double): DoubleArray {
        val dLat = Math.toDegrees(radiusM / EARTH_R)
        // Guard against the poles; irrelevant in Romania but free.
        val cosLat = max(0.0001, cos(Math.toRadians(lat)))
        val dLon = Math.toDegrees(radiusM / (EARTH_R * cosLat))
        return doubleArrayOf(lat - dLat, lon - dLon, lat + dLat, lon + dLon)
    }

    fun clamp(v: Double, lo: Double, hi: Double): Double = max(lo, min(hi, v))

    fun isPlausible(lat: Double, lon: Double): Boolean =
        abs(lat) <= 90.0 && abs(lon) <= 180.0 && !(lat == 0.0 && lon == 0.0)
}
