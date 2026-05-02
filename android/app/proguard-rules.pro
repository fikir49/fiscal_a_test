# Keep Google ML Kit and Text Recognition classes
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_text_common.** { *; }

# Important: ML Kit Text plugin references multiple languages (Chinese, Japanese, etc.)
# We ignore warnings if these optional modules are not in your app
-dontwarn com.google.mlkit.vision.text.**
-dontwarn com.google.android.gms.internal.mlkit_vision_text_common.**

# Keep local_auth and biometric classes
-keep class io.flutter.plugins.localauth.** { *; }
-dontwarn androidx.biometric.**
-keep class androidx.biometric.** { *; }

# General Flutter Proguard Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
