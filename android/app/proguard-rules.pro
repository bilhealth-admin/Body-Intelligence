# BIL release rules. Flutter and AndroidX consumer rules remain authoritative.
# Keep only objects instantiated by platform channels or serialized by name.
-keep class com.bilhealth.bodyintelligencelog.MainActivity { *; }
-keep class com.bilhealth.bodyintelligencelog.PermissionsRationaleActivity { *; }
-keep class com.bilhealth.bodyintelligencelog.BILGlobalHealthBridge { *; }
-keep class com.bilhealth.bodyintelligencelog.BILMedicalBleBridge { *; }

# Room creates generated database implementations by class name. Keep the
# WorkManager database pair stable under release R8 optimization so AndroidX
# Startup can initialize before Flutter starts.
-keep class androidx.work.impl.WorkDatabase { *; }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
-keep class androidx.work.impl.WorkDatabase_Impl$* { *; }
-keepnames class * extends androidx.room.RoomDatabase

# Preserve generic signatures and annotations used by store/health plugins.
-keepattributes Signature,RuntimeVisibleAnnotations,RuntimeInvisibleAnnotations

# Do not print sensitive application values during release optimization.
-assumenosideeffects class android.util.Log {
    public static int v(...);
    public static int d(...);
    public static int i(...);
}
