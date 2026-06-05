# ProGuard/R8 configuration rules for MemoVault

# Keep Firebase and Crashlytics components from being stripped by R8
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-keep class io.flutter.plugins.firebase.** { *; }
