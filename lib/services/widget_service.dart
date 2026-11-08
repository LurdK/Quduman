import 'package:home_widget/home_widget.dart';
import '../models/verse.dart';

class WidgetService {
  static const String appGroupId = 'group.com.quduman.quduman';
  static const String androidWidgetName = 'QuranGlanceWidgetReceiver';

  static Future<void> updateActiveVerse(
    Verse verse, {
    String? translation,
    String selectedEdition = 'en.sahih',
  }) async {
    final transText = translation ??
        (selectedEdition.startsWith('ms') && verse.translationMs.isNotEmpty
            ? verse.translationMs
            : verse.translationEn);

    await HomeWidget.saveWidgetData<int>('current_verse_index', verse.id);
    await HomeWidget.saveWidgetData<String>('surah_name', verse.surahNameEn);
    await HomeWidget.saveWidgetData<int>('ayah_number', verse.ayahNumber);
    await HomeWidget.saveWidgetData<String>('verse_arabic', verse.textArabic);
    await HomeWidget.saveWidgetData<String>('verse_translation', transText);
    await HomeWidget.saveWidgetData<String>('selected_edition', selectedEdition);
    await HomeWidget.saveWidgetData<String>('selected_language', selectedEdition.split('.').first);

    await HomeWidget.updateWidget(
      name: androidWidgetName,
      androidName: androidWidgetName,
      qualifiedAndroidName: 'com.quduman.quduman.QuranGlanceWidgetReceiver',
    );
  }

  static Future<int> getSavedVerseIndex() async {
    try {
      final raw = await HomeWidget.getWidgetData<dynamic>('current_verse_index');
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      if (raw is String) return int.tryParse(raw) ?? 1;
    } catch (_) {}
    return 1;
  }

  static Future<String> getSavedEdition() async {
    final edition = await HomeWidget.getWidgetData<String>('selected_edition', defaultValue: 'en.sahih');
    return edition ?? 'en.sahih';
  }

  static Future<String> getSavedLanguage() async {
    final edition = await getSavedEdition();
    return edition.split('.').first;
  }
}
