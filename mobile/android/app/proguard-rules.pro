# flutter_local_notifications nyimpen jadwal notif sebagai JSON (Gson) di
# SharedPreferences. Tanpa rules ini R8 di build release ngebuang/ngerename
# class & generic signature-nya, jadinya cancel/schedule crash
# "Missing type parameter."
-keep class com.dexterous.** { *; }

# Gson baca tipe generic lewat refleksi, jadi atribut ini harus tetep ada
-keepattributes Signature
-keepattributes *Annotation*

# TypeToken<...>() {} itu subclass anonim; Gson ngambil tipe dari generic
# superclass-nya, jadi class & subclass-nya jangan dibuang/diobfuscate
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken

# adapter custom (mis. RuntimeTypeAdapterFactory di plugin) dibikin lewat refleksi
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
