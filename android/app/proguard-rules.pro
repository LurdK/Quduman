# Prevent R8 from obfuscating or stripping Glance & Widget classes
-keep class com.quduman.quduman.** { *; }
-keepclassmembers class com.quduman.quduman.** {
    public <init>(...);
    *;
}

-keep interface androidx.glance.appwidget.action.ActionCallback { *; }
-keep class * implements androidx.glance.appwidget.action.ActionCallback {
    public <init>(...);
    *;
}

-keep class androidx.glance.** { *; }
-keep class es.antonborri.home_widget.** { *; }

