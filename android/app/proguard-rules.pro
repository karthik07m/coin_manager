# Keep rules for release (R8) builds.
#
# Flutter contributes its own engine rules automatically; everything here
# covers plugins that resolve classes reflectively, which R8 cannot see.

# flutter_local_notifications — schedules via reflection and (de)serializes
# notification details with Gson.
-keep class com.dexterous.** { *; }
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
-keepclassmembers,allowobfuscation class * {
    @com.google.gson.annotations.SerializedName <fields>;
}
# Gson keeps generic signatures to resolve TypeToken at runtime.
-keepattributes Signature, *Annotation*, EnclosingMethod, InnerClasses

# Generic Android entry points referenced only from the manifest.
-keep class * extends android.app.Activity
-keep class * extends android.app.Service
-keep class * extends android.content.BroadcastReceiver

# ML Kit text recognition (receipt OCR). The plugin references every language
# bundle, but only the Latin recognizer is packaged, so R8 sees the other four
# as missing classes. They are never reached at runtime.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
-keep class com.google.mlkit.vision.text.latin.** { *; }

# Suppress warnings for optional desugaring/annotation deps that are not
# packaged in the app.
-dontwarn javax.annotation.**
-dontwarn org.conscrypt.**
