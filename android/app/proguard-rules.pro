# The receivers and the service are only ever referenced from the manifest and
# from PendingIntents, so R8 cannot see the references and will strip them.
-keep class ro.troita.geofence.GeofenceBroadcastReceiver { *; }
-keep class ro.troita.geofence.SystemEventReceiver { *; }
-keep class ro.troita.journey.JourneyForegroundService { *; }
-keep class ro.troita.MainActivity { *; }

# Play services location.
-keep class com.google.android.gms.location.** { *; }
-dontwarn com.google.android.gms.**
