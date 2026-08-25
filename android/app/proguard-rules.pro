# MainActivity is referenced only from the manifest, so R8 cannot see it.
-keep class ro.troita.MainActivity { *; }

# Play services location — still used for the single fused-location call that
# centres the map.
-keep class com.google.android.gms.location.** { *; }
-dontwarn com.google.android.gms.**
