import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('About Quduman'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Hero
              Center(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.auto_stories_rounded,
                        size: 40,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Quduman • قُدُمًا',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'One Verse a Day • Istiqamah & Contemplation',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Version 1.0.0',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Card 1: The Core Philosophy
              _buildSectionCard(
                context,
                icon: Icons.lightbulb_outline_rounded,
                title: 'The Philosophy of Istiqamah',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quduman (قُدُمًا) is an Arabic word meaning "moving forward steadily with purpose and persistence."',
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(10),
                        border: Border(
                          left: BorderSide(
                            color: theme.colorScheme.primary,
                            width: 3,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '«أَحَبُّ الأَعْمَالِ إِلَى اللَّهِ أَدْوَمُهَا وَإِنْ قَلَّ»',
                            textDirection: TextDirection.rtl,
                            style: const TextStyle(
                              fontFamily: 'AmiriQuran',
                              fontSize: 18,
                              height: 1.8,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '"The deeds most beloved to Allah are those done regularly, even if they are small."',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontStyle: FontStyle.italic,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '— Sahih al-Bukhari (6464)',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Rather than rushing to complete chapters, Quduman prioritizes deep contemplation (tadabbur) by delivering one verse at a time right onto your home screen.',
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Card 2: Home Screen Widget Quick-Start Guide
              _buildSectionCard(
                context,
                icon: Icons.widgets_rounded,
                title: 'Interactive Home Screen Widget',
                child: Column(
                  children: [
                    _buildStepRow(
                      context,
                      step: '1',
                      title: 'Add the Widget',
                      desc: 'Long-press any empty space on your phone launcher → tap Widgets → find Quduman and place it on your home screen.',
                    ),
                    const SizedBox(height: 12),
                    _buildStepRow(
                      context,
                      step: '2',
                      title: 'Listen in Place',
                      desc: 'Tap ▶ Audio directly on the widget to listen to Sheikh Husary without opening the app.',
                    ),
                    const SizedBox(height: 12),
                    _buildStepRow(
                      context,
                      step: '3',
                      title: 'Forward-Only Progression',
                      desc: 'Tap Next → to advance to the next verse in place. Progression is driven by a single global counter (1 to 6,236).',
                    ),
                    const SizedBox(height: 12),
                    _buildStepRow(
                      context,
                      step: '4',
                      title: 'Deep-Link to Reading Mode',
                      desc: 'Tap the verse text to open Reading Mode with real-time acoustic karaoke word highlighting.',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Card 3: Authentic Data Sources & Attribution
              _buildSectionCard(
                context,
                icon: Icons.verified_user_outlined,
                title: 'Authentic Sources & Attribution',
                child: Column(
                  children: [
                    _buildCreditRow(
                      context,
                      label: 'Quranic Text',
                      value: 'Tanzil.net verified Uthmani script',
                    ),
                    const Divider(height: 18),
                    _buildCreditRow(
                      label: 'Reciter',
                      value: 'Sheikh Mahmoud Khalil Al-Husary (Murattal, EveryAyah CDN)',
                      context,
                    ),
                    const Divider(height: 18),
                    _buildCreditRow(
                      label: 'Acoustic Timestamps',
                      value: 'Quran.com API v4 word-segment dataset',
                      context,
                    ),
                    const Divider(height: 18),
                    _buildCreditRow(
                      label: 'Translations',
                      value: 'Saheeh International (EN) & Basmeih (MS)',
                      context,
                    ),
                    const Divider(height: 18),
                    _buildCreditRow(
                      label: 'Arabic Typography',
                      value: 'Amiri Quran Font (Khaled Hosny / Google Fonts)',
                      context,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Card 4: Privacy & Open Source Pledge
              _buildSectionCard(
                context,
                icon: Icons.lock_outline_rounded,
                title: 'Privacy & Open Source',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '• 100% Free & Open Source.\n• No advertisements, no trackers, no user analytics.\n• Works completely offline with zero server dependencies.\n• Distributed directly via GitHub Releases.',
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              Center(
                child: Text(
                  'Made with devotion for daily Quran contemplation.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildStepRow(
    BuildContext context, {
    required String step,
    required String title,
    required String desc,
  }) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            shape: BoxShape.circle,
          ),
          child: Text(
            step,
            style: TextStyle(
              color: theme.colorScheme.onPrimary,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCreditRow(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
