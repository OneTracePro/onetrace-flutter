package pro.onetrace.flutter

import android.app.Activity
import android.content.Context
import pro.onetrace.sdk.location.GeofenceStatus
import pro.onetrace.sdk.location.OneTraceLocation

/**
 * Geofences of the native `onetrace-location` module. The plugin only compiles against it: the module reaches the app
 * with the Gradle property `onetrace.geofences=true`, so an app without geofences gets neither Play services Location nor
 * the location permissions. This class is loaded only when the module is there.
 */
internal object Geofencing {

    /** The name of the status in the Dart `GeofenceStatus` enum. */
    fun enable(context: Context): String = when (OneTraceLocation.enableGeofences(context)) {
        GeofenceStatus.ENABLED -> "enabled"
        GeofenceStatus.LOCATION_PERMISSION_MISSING -> "locationPermissionMissing"
        GeofenceStatus.BACKGROUND_PERMISSION_MISSING -> "backgroundPermissionMissing"
        GeofenceStatus.PLAY_SERVICES_UNAVAILABLE -> "playServicesUnavailable"
        GeofenceStatus.NOT_INITIALIZED -> "notInitialized"
    }

    fun disable(context: Context) = OneTraceLocation.disableGeofences(context)

    fun requestPermission(activity: Activity): Boolean = OneTraceLocation.requestLocationPermission(activity)
}

/** Whether the app has `onetrace-location`: checked by name, without loading [Geofencing]. */
internal object GeofencingModule {
    val linked: Boolean by lazy {
        try {
            Class.forName("pro.onetrace.sdk.location.OneTraceLocation")
            true
        } catch (e: ClassNotFoundException) {
            false
        }
    }
}
