# Keep useful metadata for libraries that inspect generic signatures or annotations.
-keepattributes Signature,*Annotation*,InnerClasses,EnclosingMethod

# RevenueCat ships consumer rules, but these warnings can vary by SDK version.
-dontwarn com.revenuecat.purchases.**

# Supabase is primarily Dart-side in this app; keep Android shrinker warnings quiet
# if transitive packages expose optional JVM references.
-dontwarn io.github.jan.supabase.**
