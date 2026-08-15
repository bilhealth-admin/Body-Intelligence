# BIL release rules. Flutter and AndroidX consumer rules remain authoritative.
# Keep only objects instantiated by platform channels or serialized by name.
-keep class com.kadem.bil.MainActivity { *; }
-keep class com.kadem.bil.PermissionsRationaleActivity { *; }
-keep class com.kadem.bil.BILGlobalHealthBridge { *; }
-keep class com.kadem.bil.BILMedicalBleBridge { *; }

# Preserve generic signatures and annotations used by store/health plugins.
-keepattributes Signature,RuntimeVisibleAnnotations,RuntimeInvisibleAnnotations

# Do not print sensitive application values during release optimization.
-assumenosideeffects class android.util.Log {
    public static int v(...);
    public static int d(...);
    public static int i(...);
}
