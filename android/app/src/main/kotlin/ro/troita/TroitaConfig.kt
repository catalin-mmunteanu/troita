package ro.troita

/**
 * Tuning knobs and identifiers shared between the native side and the bridge.
 *
 * Much smaller than it was: the geofencing window, the journey sampling rates
 * and the OEM battery workarounds all went away with those features. What
 * remains is the notification surface and the keys the bridge uses.
 */
object TroitaConfig {

    const val PREFS = "troita_prefs"

    /**
     * Whether the user has been through onboarding.
     *
     * A separate flag on purpose: onboarding used to be gated on the location
     * permission, which meant anyone who declined location saw it on every
     * launch. Location is optional now — the calendar works without it — so
     * "have we introduced ourselves" and "may we use location" are different
     * questions and need different answers.
     */
    const val KEY_ONBOARDED = "onboarded"

    const val EXTRA_CHURCH_ID = "ro.troita.extra.CHURCH_ID"
    const val EXTRA_FEAST_ID = "ro.troita.extra.FEAST_ID"
}
