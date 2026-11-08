package com.quduman.quduman

import android.appwidget.AppWidgetManager
import android.content.Context
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetManager
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.state.updateAppWidgetState
import es.antonborri.home_widget.HomeWidgetPlugin
import kotlinx.coroutines.MainScope
import kotlinx.coroutines.launch

class QuranGlanceWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = QuranGlanceWidget()

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        super.onUpdate(context, appWidgetManager, appWidgetIds)
        val prefs = HomeWidgetPlugin.getData(context)
        val currentIndex = prefs.getInt("current_verse_index", 1)
        val surahName = prefs.getString("surah_name", "Al-Faatiha") ?: "Al-Faatiha"
        val ayahNumber = prefs.getInt("ayah_number", 1)
        val verseArabic = prefs.getString("verse_arabic", "") ?: ""
        val verseTranslation = prefs.getString("verse_translation", "") ?: ""
        val lang = prefs.getString("selected_language", "en") ?: "en"

        MainScope().launch {
            val manager = GlanceAppWidgetManager(context)
            for (appWidgetId in appWidgetIds) {
                try {
                    val glanceId = manager.getGlanceIdBy(appWidgetId)
                    updateAppWidgetState(context, glanceId) { glancePrefs ->
                        glancePrefs[intPreferencesKey("current_verse_index")] = currentIndex
                        glancePrefs[stringPreferencesKey("surah_name")] = surahName
                        glancePrefs[intPreferencesKey("ayah_number")] = ayahNumber
                        glancePrefs[stringPreferencesKey("verse_arabic")] = verseArabic
                        glancePrefs[stringPreferencesKey("verse_translation")] = verseTranslation
                        glancePrefs[stringPreferencesKey("selected_language")] = lang
                        glancePrefs[booleanPreferencesKey("is_audio_playing")] = false
                    }
                    glanceAppWidget.update(context, glanceId)
                } catch (e: Exception) {
                    e.printStackTrace()
                }
            }
        }
    }
}

