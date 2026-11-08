package com.quduman.quduman

import android.content.Context
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.GlanceTheme
import androidx.glance.action.actionStartActivity
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.action.actionRunCallback
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.lazy.LazyColumn
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.currentState
import androidx.glance.layout.*
import androidx.glance.state.GlanceStateDefinition
import androidx.glance.state.PreferencesGlanceStateDefinition
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextAlign
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import es.antonborri.home_widget.HomeWidgetPlugin

class QuranGlanceWidget : GlanceAppWidget() {

    override var stateDefinition: GlanceStateDefinition<*> = PreferencesGlanceStateDefinition

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        provideContent {
            // 1. Reactive Glance Preferences (updated by Next and Audio actions)
            val glancePrefs = currentState<Preferences>()
            // 2. Fallback to HomeWidget shared preferences (updated by Flutter app)
            val homeWidgetPrefs = HomeWidgetPlugin.getData(context)

            val surahName = glancePrefs[stringPreferencesKey("surah_name")]
                ?: homeWidgetPrefs.getString("surah_name", "Al-Faatiha") ?: "Al-Faatiha"
            val ayahNumber = glancePrefs[intPreferencesKey("ayah_number")]
                ?: homeWidgetPrefs.getInt("ayah_number", 1)
            val verseArabic = glancePrefs[stringPreferencesKey("verse_arabic")]
                ?: homeWidgetPrefs.getString("verse_arabic", "بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ")
                ?: "بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ"
            val verseTranslation = glancePrefs[stringPreferencesKey("verse_translation")]
                ?: homeWidgetPrefs.getString(
                    "verse_translation",
                    "In the name of Allah, the Entirely Merciful, the Especially Merciful."
                ) ?: "In the name of Allah, the Entirely Merciful, the Especially Merciful."

            val isAudioPlaying = glancePrefs[booleanPreferencesKey("is_audio_playing")] ?: false

            GlanceTheme {
                Box(
                    modifier = GlanceModifier
                        .fillMaxSize()
                        .background(Color(0xFF13221C))
                        .cornerRadius(20.dp)
                        .padding(14.dp)
                        .clickable(actionStartActivity<MainActivity>())
                ) {
                    Column(
                        modifier = GlanceModifier.fillMaxSize()
                    ) {
                        // Header Row
                        Row(
                            modifier = GlanceModifier.fillMaxWidth(),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(
                                text = surahName,
                                style = TextStyle(
                                    color = ColorProvider(Color(0xFFE2E8F0)),
                                    fontSize = 13.sp,
                                    fontWeight = FontWeight.Bold
                                )
                            )
                            Spacer(modifier = GlanceModifier.defaultWeight())
                            Text(
                                text = "Ayah $ayahNumber",
                                style = TextStyle(
                                    color = ColorProvider(Color(0xFFFBBF24)), // Amber
                                    fontSize = 12.sp,
                                    fontWeight = FontWeight.Bold
                                )
                            )
                        }

                        Spacer(modifier = GlanceModifier.height(8.dp))

                        // Adaptive Typography based on verse length
                        val wordCount = verseArabic.trim().split(Regex("\\s+")).filter { it.isNotEmpty() }.size
                        val arabicFontSize = when {
                            wordCount <= 10 -> 22.sp
                            wordCount <= 35 -> 17.sp
                            wordCount <= 70 -> 14.5.sp
                            else -> 12.5.sp
                        }
                        val translationFontSize = when {
                            wordCount <= 10 -> 13.5.sp
                            wordCount <= 35 -> 12.sp
                            wordCount <= 70 -> 11.sp
                            else -> 10.sp
                        }

                        // Verse Body (Scrollable for longer verses, clickable to deep-link to Reading Mode)
                        LazyColumn(
                            modifier = GlanceModifier.defaultWeight().fillMaxWidth()
                        ) {
                            item {
                                Column(
                                    modifier = GlanceModifier
                                        .fillMaxWidth()
                                        .clickable(actionStartActivity<MainActivity>())
                                ) {
                                    // Arabic Text
                                    Text(
                                        text = verseArabic,
                                        style = TextStyle(
                                            color = ColorProvider(Color(0xFFFFFFFF)),
                                            fontSize = arabicFontSize,
                                            fontWeight = FontWeight.Medium,
                                            textAlign = TextAlign.End
                                        ),
                                        modifier = GlanceModifier
                                            .fillMaxWidth()
                                            .padding(vertical = 4.dp)
                                            .clickable(actionStartActivity<MainActivity>())
                                    )

                                    Spacer(modifier = GlanceModifier.height(6.dp))

                                    // Translation
                                    Text(
                                        text = verseTranslation,
                                        style = TextStyle(
                                            color = ColorProvider(Color(0xFF94A3B8)),
                                            fontSize = translationFontSize
                                        ),
                                        modifier = GlanceModifier
                                            .fillMaxWidth()
                                            .clickable(actionStartActivity<MainActivity>())
                                    )
                                }
                            }
                        }

                        Spacer(modifier = GlanceModifier.height(6.dp))

                        // Bottom Action Row with Audio Play/Pause button and [Next →] Button
                        Row(
                            modifier = GlanceModifier.fillMaxWidth(),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            // Brand / Tag
                            Text(
                                text = "Quduman",
                                style = TextStyle(
                                    color = ColorProvider(Color(0xFF475569)),
                                    fontSize = 10.sp
                                )
                            )

                            Spacer(modifier = GlanceModifier.defaultWeight())

                            // 1. Audio Play / Pause Button (Changes icon/label dynamically)
                            Box(
                                modifier = GlanceModifier
                                    .background(if (isAudioPlaying) Color(0xFF7C2D12) else Color(0xFF1E3A2F))
                                    .cornerRadius(10.dp)
                                    .padding(horizontal = 10.dp, vertical = 6.dp)
                                    .clickable(actionRunCallback<ToggleAudioActionCallback>())
                            ) {
                                Text(
                                    text = if (isAudioPlaying) "⏸ Pause" else "▶ Audio",
                                    style = TextStyle(
                                        color = ColorProvider(if (isAudioPlaying) Color(0xFFFCA5A5) else Color(0xFF86EFAC)),
                                        fontSize = 12.sp,
                                        fontWeight = FontWeight.Bold
                                    )
                                )
                            }

                            Spacer(modifier = GlanceModifier.width(8.dp))

                            // 2. Next Button
                            Box(
                                modifier = GlanceModifier
                                    .background(Color(0xFF22543D))
                                    .cornerRadius(10.dp)
                                    .padding(horizontal = 12.dp, vertical = 6.dp)
                                    .clickable(actionRunCallback<NextVerseActionCallback>())
                            ) {
                                Text(
                                    text = "Next →",
                                    style = TextStyle(
                                        color = ColorProvider(Color(0xFFFCD34D)),
                                        fontSize = 12.sp,
                                        fontWeight = FontWeight.Bold
                                    )
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}
