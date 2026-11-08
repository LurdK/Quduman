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
import java.io.File
import java.io.FileOutputStream
import java.net.URL

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
            play(context, url, surah, ayah, glanceId)
        }
    }

    private fun play(context: Context, url: String, surah: Int, ayah: Int, glanceId: GlanceId) {
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

            // Check shared persistent local cache folder
            val s = String.format("%03d", surah)
            val a = String.format("%03d", ayah)
            val audioDir = File(context.cacheDir, "audio/Husary_128kbps")
            val localFile = File(audioDir, "$s$a.mp3")

            if (localFile.exists() && localFile.length() > 0) {
                // Play directly from persistent local disk cache
                player.setDataSource(localFile.absolutePath)
            } else {
                // Stream from URL
                player.setDataSource(url)
                // Cache to disk in background for future offline use
                CoroutineScope(Dispatchers.IO).launch {
                    try {
                        audioDir.mkdirs()
                        val tempFile = File(audioDir, "$s$a.mp3.tmp")
                        URL(url).openStream().use { input ->
                            FileOutputStream(tempFile).use { output ->
                                input.copyTo(output)
                            }
                        }
                        if (tempFile.exists() && tempFile.length() > 0) {
                            tempFile.renameTo(localFile)
                        }
                    } catch (_: Exception) {}
                }
            }

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
