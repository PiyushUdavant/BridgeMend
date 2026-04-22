# Used when minify/shrink is enabled on release. Safe to keep with isMinifyEnabled=false for future toggles.

# Flutter
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }

# ZEGO Express Engine (native + JNI)
-keep class im.zego.** { *; }
-keep class **.zego.** { *; }
-dontwarn im.zego.**

# Gson / JSON (if used by SDKs)
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses
