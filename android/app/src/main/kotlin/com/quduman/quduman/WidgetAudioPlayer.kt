package com.quduman.quduman

import android.content.Context
import android.media.AudioAttributes
import android.media.MediaPlayer
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.glance.GlanceId
import androidx.glance.appwidget.state.updateAppWidgetState
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

object WidgetAudioPlayer {
    private var mediaPlayer: MediaPlayer? = null
    var isAudioPlaying: Boolean = false
        private set

    fun togglePlay(context: Context, surah: Int, ayah: Int, glanceId: GlanceId) {
        if (isAudioPlaying) {
            stop(context, glanceId)
        } else {
            val s = String.format("%03d", surah)
            val a = String.format("%03d", ayah)
            val url = "https://everyayah.com/data/Husary_128kbps/$s$a.mp3"
            play(context, url, glanceId)
        }
    }

    private fun play(context: Context, url: String, glanceId: GlanceId) {
        stop(context, glanceId)

        try {
            val player = MediaPlayer()
            mediaPlayer = player

            player.setAudioAttributes(
                AudioAttributes.Builder()
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .build()
            )
            player.setDataSource(url)
            player.setOnPreparedListener { mp ->
                mp.start()
                isAudioPlaying = true
                updateWidgetState(context, glanceId, true)
            }
            player.setOnCompletionListener {
                isAudioPlaying = false
                updateWidgetState(context, glanceId, false)
                releasePlayer()
            }
            player.setOnErrorListener { _, _, _ ->
                isAudioPlaying = false
                updateWidgetState(context, glanceId, false)
                releasePlayer()
                true
            }
            player.prepareAsync()
        } catch (e: Exception) {
            e.printStackTrace()
            isAudioPlaying = false
            updateWidgetState(context, glanceId, false)
        }
    }

    fun stop(context: Context, glanceId: GlanceId?) {
        try {
            mediaPlayer?.stop()
        } catch (_: Exception) {}
        releasePlayer()
        isAudioPlaying = false
        if (glanceId != null) {
            updateWidgetState(context, glanceId, false)
        }
    }

    private fun releasePlayer() {
        try {
            mediaPlayer?.release()
        } catch (_: Exception) {}
        mediaPlayer = null
    }

    private fun updateWidgetState(context: Context, glanceId: GlanceId, playing: Boolean) {
        CoroutineScope(Dispatchers.Main).launch {
            try {
                updateAppWidgetState(context, glanceId) { prefs ->
                    prefs[booleanPreferencesKey("is_audio_playing")] = playing
                }
                QuranGlanceWidget().update(context, glanceId)
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }
}
