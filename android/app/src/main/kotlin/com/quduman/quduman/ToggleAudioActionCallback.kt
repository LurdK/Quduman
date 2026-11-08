package com.quduman.quduman

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.glance.GlanceId
import androidx.glance.action.ActionParameters
import androidx.glance.appwidget.action.ActionCallback
import androidx.glance.appwidget.state.getAppWidgetState
import androidx.glance.state.PreferencesGlanceStateDefinition
import es.antonborri.home_widget.HomeWidgetPlugin

class ToggleAudioActionCallback : ActionCallback {

    override suspend fun onAction(
        context: Context,
        glanceId: GlanceId,
        parameters: ActionParameters
    ) {
        val glancePrefs = getAppWidgetState(context, PreferencesGlanceStateDefinition, glanceId)
        val homeWidgetPrefs = HomeWidgetPlugin.getData(context)

        var verseIndex = glancePrefs[intPreferencesKey("current_verse_index")]
            ?: homeWidgetPrefs.getInt("current_verse_index", 1)

        var surah = 1
        var ayah = 1

        val dbFile = context.getDatabasePath("quran.db")
        if (dbFile.exists()) {
            try {
                val db = SQLiteDatabase.openDatabase(
                    dbFile.absolutePath,
                    null,
                    SQLiteDatabase.OPEN_READONLY
                )
                val cursor = db.rawQuery(
                    "SELECT surah_number, ayah_number FROM quran_verses WHERE id = ?",
                    arrayOf(verseIndex.toString())
                )
                if (cursor.moveToFirst()) {
                    surah = cursor.getInt(0)
                    ayah = cursor.getInt(1)
                }
                cursor.close()
                db.close()
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }

        WidgetAudioPlayer.togglePlay(context, surah, ayah, glanceId)
    }
}

