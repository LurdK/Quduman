package com.quduman.quduman

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.glance.GlanceId
import androidx.glance.action.ActionParameters
import androidx.glance.appwidget.action.ActionCallback
import androidx.glance.appwidget.state.updateAppWidgetState
import es.antonborri.home_widget.HomeWidgetPlugin
import java.io.File
import java.io.FileOutputStream

class NextVerseActionCallback : ActionCallback {

    override suspend fun onAction(
        context: Context,
        glanceId: GlanceId,
        parameters: ActionParameters
    ) {
        // Stop audio if currently playing
        WidgetAudioPlayer.stop(context, null)

        val prefs = HomeWidgetPlugin.getData(context)
        val currentIndex = prefs.getInt("current_verse_index", 1)

        // Global index progression: (current % 6236) + 1
        val nextIndex = (currentIndex % 6236) + 1

        val editionId = prefs.getString("selected_edition", "en.sahih") ?: "en.sahih"
        val lang = prefs.getString("selected_language", editionId.substringBefore(".")) ?: "en"

        val dbFile = context.getDatabasePath("quran.db")

        // Ensure database file exists
        if (!dbFile.exists()) {
            try {
                dbFile.parentFile?.mkdirs()
                val assetPath = "flutter_assets/assets/databases/quran.db"
                context.assets.open(assetPath).use { input ->
                    FileOutputStream(dbFile).use { output ->
                        input.copyTo(output)
                    }
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }

        var surahName = "Al-Faatiha"
        var ayahNumber = 1
        var textArabic = ""
        var translation = ""

        if (dbFile.exists()) {
            try {
                val db = SQLiteDatabase.openDatabase(
                    dbFile.absolutePath,
                    null,
                    SQLiteDatabase.OPEN_READONLY
                )

                val cursor = db.rawQuery(
                    "SELECT surah_name_en, ayah_number, text_arabic, translation_en, translation_ms FROM quran_verses WHERE id = ?",
                    arrayOf(nextIndex.toString())
                )

                if (cursor.moveToFirst()) {
                    surahName = cursor.getString(0) ?: "Al-Faatiha"
                    ayahNumber = cursor.getInt(1)
                    textArabic = cursor.getString(2) ?: ""
                    val translationEn = cursor.getString(3) ?: ""
                    val translationMs = cursor.getString(4) ?: ""

                    // Query translations table for active edition
                    val transCursor = try {
                        db.rawQuery(
                            "SELECT translation_text FROM translations WHERE edition_id = ? AND verse_id = ?",
                            arrayOf(editionId, nextIndex.toString())
                        )
                    } catch (_: Exception) { null }

                    if (transCursor != null && transCursor.moveToFirst()) {
                        translation = transCursor.getString(0) ?: ""
                        transCursor.close()
                    } else {
                        transCursor?.close()
                        val isMalay = editionId.startsWith("ms")
                        translation = if (isMalay && translationMs.isNotEmpty()) translationMs else translationEn
                    }

                    // Keep SharedPreferences updated for the Flutter app
                    prefs.edit()
                        .putInt("current_verse_index", nextIndex)
                        .putString("surah_name", surahName)
                        .putInt("ayah_number", ayahNumber)
                        .putString("verse_arabic", textArabic)
                        .putString("verse_translation", translation)
                        .putString("selected_edition", editionId)
                        .putString("selected_language", lang)
                        .commit()
                }
                cursor.close()
                db.close()
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }

        // Update Glance's reactive DataStore state
        updateAppWidgetState(context, glanceId) { glancePrefs ->
            glancePrefs[intPreferencesKey("current_verse_index")] = nextIndex
            glancePrefs[stringPreferencesKey("surah_name")] = surahName
            glancePrefs[intPreferencesKey("ayah_number")] = ayahNumber
            glancePrefs[stringPreferencesKey("verse_arabic")] = textArabic
            glancePrefs[stringPreferencesKey("verse_translation")] = translation
            glancePrefs[stringPreferencesKey("selected_edition")] = editionId
            glancePrefs[stringPreferencesKey("selected_language")] = lang
            glancePrefs[booleanPreferencesKey("is_audio_playing")] = false
        }

        // Trigger in-place Glance recomposition
        QuranGlanceWidget().update(context, glanceId)
    }
}
