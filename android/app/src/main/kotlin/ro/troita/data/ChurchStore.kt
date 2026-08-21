package ro.troita.data

import android.content.Context
import android.database.Cursor
import android.database.sqlite.SQLiteDatabase
import android.util.Log
import ro.troita.TroitaConfig
import ro.troita.geofence.Geo
import java.io.File

/**
 * The single source of truth on device.
 *
 * Deliberately NOT Room: this is opened from a BroadcastReceiver in a possibly
 * cold process, and a prepopulated Room database means shipping
 * `room_master_table` with a matching identity hash — a build-time trap that
 * buys nothing here. Plain SQLite also means no annotation processor on the
 * background path and Dart can open the same file with sqflite.
 *
 * When the backend lands, nothing in this class changes: the sync service
 * upserts into these same tables. The geofencing path must never touch the
 * network, so the local mirror stays authoritative forever.
 */
object ChurchStore {

    private const val TAG = "ChurchStore"
    private const val DB_NAME = "churches.db"
    private const val ASSET_DB = "seed/churches.db"
    private const val ASSET_VERSION = "seed/version.txt"
    private const val KEY_SEED_VERSION = "seed_version"

    @Volatile
    private var db: SQLiteDatabase? = null

    fun databaseFile(context: Context): File {
        val dir = File(context.filesDir, "troita").apply { mkdirs() }
        return File(dir, DB_NAME)
    }

    /**
     * Idempotent, cheap after first call. Safe to call from a receiver.
     * Copies (or re-copies, on seed upgrade) the bundled database, then opens it.
     */
    @Synchronized
    fun open(context: Context): SQLiteDatabase {
        db?.let { if (it.isOpen) return it }
        val ctx = context.applicationContext
        val file = databaseFile(ctx)

        val bundled = readAssetVersion(ctx)
        val installed = ctx.getSharedPreferences(TroitaConfig.PREFS, Context.MODE_PRIVATE)
            .getString(KEY_SEED_VERSION, null)

        if (!file.exists() || (bundled != null && bundled != installed)) {
            copySeed(ctx, file)
            ctx.getSharedPreferences(TroitaConfig.PREFS, Context.MODE_PRIVATE)
                .edit().putString(KEY_SEED_VERSION, bundled).apply()
        }

        val opened = SQLiteDatabase.openDatabase(
            file.absolutePath, null, SQLiteDatabase.OPEN_READWRITE
        )
        db = opened
        return opened
    }

    private fun readAssetVersion(context: Context): String? = try {
        context.assets.open(ASSET_VERSION).bufferedReader().use { it.readText().trim() }
    } catch (e: Exception) {
        Log.w(TAG, "no bundled seed version marker", e)
        null
    }

    /**
     * Re-seeding preserves the encounter log — the user's history of churches
     * they have passed shouldn't vanish because we shipped new church data.
     */
    private fun copySeed(context: Context, target: File) {
        val encounters = if (target.exists()) readEncounters(target) else emptyList()
        val tmp = File(target.parentFile, "$DB_NAME.tmp")
        context.assets.open(ASSET_DB).use { input ->
            tmp.outputStream().use { output -> input.copyTo(output, 64 * 1024) }
        }
        if (!tmp.renameTo(target)) {
            tmp.copyTo(target, overwrite = true)
            tmp.delete()
        }
        if (encounters.isNotEmpty()) restoreEncounters(target, encounters)
        Log.i(TAG, "seeded church database (${target.length()} bytes)")
    }

    private fun readEncounters(file: File): List<Array<Any>> = try {
        SQLiteDatabase.openDatabase(file.absolutePath, null, SQLiteDatabase.OPEN_READONLY).use { old ->
            old.rawQuery("SELECT church_id, notified_at, mode, dismissed, opened FROM encounters", null)
                .use { c ->
                    buildList {
                        while (c.moveToNext()) {
                            // Explicit <Any>: inferring from mixed String/Long/Int
                            // arguments yields Array<Comparable<*> & Serializable>,
                            // which will not assign to List<Array<Any>>.
                            add(
                                arrayOf<Any>(
                                    c.getString(0), c.getLong(1), c.getString(2),
                                    c.getInt(3), c.getInt(4),
                                )
                            )
                        }
                    }
                }
        }
    } catch (e: Exception) {
        Log.w(TAG, "could not preserve encounter log", e); emptyList()
    }

    private fun restoreEncounters(file: File, rows: List<Array<Any>>) = try {
        SQLiteDatabase.openDatabase(file.absolutePath, null, SQLiteDatabase.OPEN_READWRITE).use { fresh ->
            fresh.beginTransaction()
            rows.forEach {
                fresh.execSQL(
                    "INSERT INTO encounters (church_id, notified_at, mode, dismissed, opened) VALUES (?,?,?,?,?)",
                    it
                )
            }
            fresh.setTransactionSuccessful()
            fresh.endTransaction()
        }
    } catch (e: Exception) {
        Log.w(TAG, "could not restore encounter log", e)
    }

    // ---------------------------------------------------------------- queries

    private const val COLS =
        "id,name,kind,denomination,lat,lon,patron,feast_day,year_built,history," +
            "photo_ref,geofence_radius_m,priority,address"

    /** Same 14 columns, qualified — required once the query has a JOIN. */
    private const val COLS_C =
        "c.id,c.name,c.kind,c.denomination,c.lat,c.lon,c.patron,c.feast_day," +
            "c.year_built,c.history,c.photo_ref,c.geofence_radius_m,c.priority,c.address"

    /**
     * Nearest-N by great-circle distance. Bounding-box prefilter on the indexed
     * lat/lon columns, then an exact sort in memory — the same result the server
     * gives with `ST_DWithin(geography) ORDER BY geom <-> point`.
     */
    fun nearest(
        context: Context,
        lat: Double,
        lon: Double,
        limit: Int,
        maxRadiusM: Double = 60_000.0,
    ): List<Church> {
        if (!Geo.isPlausible(lat, lon)) return emptyList()
        val database = open(context)
        var radius = 6_000.0
        while (true) {
            val box = Geo.bbox(lat, lon, radius)
            val rows = database.rawQuery(
                "SELECT $COLS FROM churches WHERE deleted = 0 " +
                    "AND lat BETWEEN ? AND ? AND lon BETWEEN ? AND ?",
                arrayOf(
                    box[0].toString(), box[2].toString(),
                    box[1].toString(), box[3].toString()
                )
            ).use { c -> c.toChurches(lat, lon) }

            val within = rows.filter { it.distanceM <= radius }
            if (within.size >= limit || radius >= maxRadiusM) {
                return within.sortedBy { it.distanceM }.take(limit)
            }
            radius = minOf(radius * 3, maxRadiusM)
        }
    }

    fun byId(context: Context, id: String): Church? =
        open(context).rawQuery("SELECT $COLS FROM churches WHERE id = ? LIMIT 1", arrayOf(id))
            .use { c -> c.toChurches(0.0, 0.0).firstOrNull() }

    fun meta(context: Context): Map<String, String> =
        open(context).rawQuery("SELECT key, value FROM meta", null).use { c ->
            buildMap { while (c.moveToNext()) put(c.getString(0), c.getString(1)) }
        }

    // ------------------------------------------------------------- encounters

    /** Cooldown gate. Called on every ENTER, so it must be a single indexed read. */
    fun recentlyNotified(
        context: Context,
        churchId: String,
        withinMs: Long = TroitaConfig.ENCOUNTER_COOLDOWN_MS,
    ): Boolean = open(context).rawQuery(
        "SELECT notified_at FROM encounters WHERE church_id = ? ORDER BY notified_at DESC LIMIT 1",
        arrayOf(churchId)
    ).use { c ->
        c.moveToFirst() && (System.currentTimeMillis() - c.getLong(0)) < withinMs
    }

    fun recordEncounter(context: Context, churchId: String, mode: String) {
        open(context).execSQL(
            "INSERT INTO encounters (church_id, notified_at, mode) VALUES (?,?,?)",
            arrayOf<Any>(churchId, System.currentTimeMillis(), mode)
        )
    }

    fun markOpened(context: Context, churchId: String) {
        open(context).execSQL(
            "UPDATE encounters SET opened = 1 WHERE rowid = " +
                "(SELECT rowid FROM encounters WHERE church_id = ? ORDER BY notified_at DESC LIMIT 1)",
            arrayOf<Any>(churchId)
        )
    }

    fun recentEncounters(context: Context, limit: Int = 100): List<Pair<Church, Long>> =
        open(context).rawQuery(
            "SELECT $COLS_C, e.notified_at FROM encounters e " +
                "JOIN churches c ON c.id = e.church_id ORDER BY e.notified_at DESC LIMIT ?",
            arrayOf(limit.toString())
        ).use { c ->
            buildList {
                while (c.moveToNext()) add(c.readChurch(0.0, 0.0) to c.getLong(14))
            }
        }

    // ------------------------------------------------------------------ utils

    private fun Cursor.toChurches(fromLat: Double, fromLon: Double): List<Church> = buildList {
        while (moveToNext()) add(readChurch(fromLat, fromLon))
    }

    private fun Cursor.readChurch(fromLat: Double, fromLon: Double): Church {
        val lat = getDouble(4)
        val lon = getDouble(5)
        return Church(
            id = getString(0),
            name = getString(1),
            kind = getString(2),
            denomination = if (isNull(3)) null else getString(3),
            lat = lat,
            lon = lon,
            patron = if (isNull(6)) null else getString(6),
            feastDay = if (isNull(7)) null else getString(7),
            yearBuilt = if (isNull(8)) null else getInt(8),
            history = if (isNull(9)) null else getString(9),
            photoRef = if (isNull(10)) null else getString(10),
            geofenceRadiusM = if (isNull(11)) null else getInt(11),
            priority = getInt(12),
            address = if (isNull(13)) null else getString(13),
            distanceM = if (fromLat == 0.0 && fromLon == 0.0) 0.0
            else Geo.distanceM(fromLat, fromLon, lat, lon),
        )
    }
}
