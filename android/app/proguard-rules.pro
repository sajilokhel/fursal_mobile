# ─────────────────────────────────────────────────────────────────
# Flutter / Dart
# ─────────────────────────────────────────────────────────────────
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# ─────────────────────────────────────────────────────────────────
# Firebase – Core / Auth / Firestore / Storage
# ─────────────────────────────────────────────────────────────────
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Keep Firebase Auth model classes
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# ─────────────────────────────────────────────────────────────────
# Google Sign-In
# ─────────────────────────────────────────────────────────────────
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.common.** { *; }

# ─────────────────────────────────────────────────────────────────
# ML Kit / mobile_scanner
# ─────────────────────────────────────────────────────────────────
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**
-keep class dev.fluttercommunity.plus.** { *; }

# ─────────────────────────────────────────────────────────────────
# flutter_inappwebview
# ─────────────────────────────────────────────────────────────────
-keep class com.pichillilorenzo.flutter_inappwebview.** { *; }
-dontwarn com.pichillilorenzo.flutter_inappwebview.**

# ─────────────────────────────────────────────────────────────────
# esewa_flutter
# ─────────────────────────────────────────────────────────────────
-keep class com.esewa.** { *; }
-dontwarn com.esewa.**

# ─────────────────────────────────────────────────────────────────
# flutter_local_notifications
# ─────────────────────────────────────────────────────────────────
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-dontwarn com.dexterous.flutterlocalnotifications.**

# ─────────────────────────────────────────────────────────────────
# permission_handler
# ─────────────────────────────────────────────────────────────────
-keep class com.baseflow.permissionhandler.** { *; }

# ─────────────────────────────────────────────────────────────────
# image_picker
# ─────────────────────────────────────────────────────────────────
-keep class io.flutter.plugins.imagepicker.** { *; }

# ─────────────────────────────────────────────────────────────────
# geolocator
# ─────────────────────────────────────────────────────────────────
-keep class com.baseflow.geolocator.** { *; }

# ─────────────────────────────────────────────────────────────────
# open_filex / url_launcher
# ─────────────────────────────────────────────────────────────────
-keep class com.crazecoder.openfile.** { *; }
-keep class io.flutter.plugins.urllauncher.** { *; }

# ─────────────────────────────────────────────────────────────────
# printing / PDF
# ─────────────────────────────────────────────────────────────────
-keep class androidx.print.** { *; }

# ─────────────────────────────────────────────────────────────────
# Kotlin coroutines / serialization (used by many packages)
# ─────────────────────────────────────────────────────────────────
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}
-keep class kotlin.** { *; }
-keep class kotlinx.** { *; }
-dontwarn kotlin.**
-dontwarn kotlinx.**

# ─────────────────────────────────────────────────────────────────
# OkHttp (network calls in http package)
# ─────────────────────────────────────────────────────────────────
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }

# ─────────────────────────────────────────────────────────────────
# General: keep reflection-needed attributes
# ─────────────────────────────────────────────────────────────────
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
