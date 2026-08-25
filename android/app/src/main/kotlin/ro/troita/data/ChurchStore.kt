package ro.troita.data

import android.content.Context
import android.database.Cursor
import android.database.sqlite.SQLiteDatabase
import android.util.Log
import ro.troita.TroitaConfig
import ro.troita.util.Geo
import java.io.File

/**
 * Installs and opens the bundled church + feast database.
 *
 * Much narrower than it was. With geofencing gone, nothing native queries this
 * at runtime — Dart reads the same file through sqflite. What remains is the
 * one job Kotlin still has to do: copy the seed out of assets on first launch
 * (and again when a new seed version ships) before Dart tries to open it.
 *
 * Deliberately not Room: a prepopulated Room database means shipping
 * `room_master_table` with a matching identity hash, which buys nothing here.
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

    /** Idempotent and cheap after the first call. */
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
            file.absolutePath, null, SQLiteDatabase.OPEN_READONLY
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
     * A straight overwrite. Nothing user-generated lives in this file — that is
     * the whole reason favourites and visits belong in a separate database that
     * re-seeding never touches.
     */
    private fun copySeed(context: Context, target: File) {
        db?.takeIf { it.isOpen }?.close()
        db = null
        val tmp = File(target.parentFile, "$DB_NAME.tmp")
        context.assets.open(ASSET_DB).use { input ->
            tmp.outputStream().use { output -> input.copyTo(output, 64 * 1024) }
        }
        if (!tmp.renameTo(target)) {
            tmp.copyTo(target, overwrite = true)
            tmp.delete()
        }
        Log.i(TAG, "seeded church database (${target.length()} bytes)")
    }

    // ---------------------------------------------------------------- queries

    private const val COLS =
        "id,name,kind,denomination,lat,lon,patron,feast_day,year_built,history," +
            "photo_ref,priority,address"

    fun byId(context: Context, id: String): Church? =
        open(context).rawQuery("SELECT $COLS FROM churches WHERE id = ? LIMIT 1", arrayOf(id))
            .use { c -> c.toChurches(0.0, 0.0).firstOrNull() }

    fun meta(context: Context): Map<String, String> =
        open(context).rawQuery("SELECT key, value FROM meta", null).use { c ->
            buildMap { while (c.moveToNext()) put(c.getString(0), c.getString(1)) }
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
            priority = getInt(11),
            address = if (isNull(12)) null else getString(12),
            distanceM = if (fromLat == 0.0 && fromLon == 0.0) 0.0
            else Geo.distanceM(fromLat, fromLon, lat, lon),
        )
    }
}
