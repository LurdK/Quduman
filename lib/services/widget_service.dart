import 'package:home_widget/home_widget.dart';
import '../models/verse.dart';

class WidgetService {
  static const String appGroupId = 'group.com.quduman.quduman';
  static const String androidWidgetName = 'QuranGlanceWidgetReceiver';

  static Future<void> updateActiveVerse(Verse verse, {bool useMalay = false}) async {
    final translation = useMalay && verse.translationMs.isNotEmpty
        ? verse.translationMs
        : verse.translationEn;

    final lang = useMalay ? 'ms' : 'en';

    await HomeWidget.saveWidgetData<int>('current_verse_index', verse.id);
    await HomeWidget.saveWidgetData<String>('surah_name', verse.surahNameEn);
    await HomeWidget.saveWidgetData<int>('ayah_number', verse.ayahNumber);
    await HomeWidget.saveWidgetData<String>('verse_arabic', verse.textArabic);
    await HomeWidget.saveWidgetData<String>('verse_translation', translation);
    await HomeWidget.saveWidgetData<String>('selected_language', lang);

    await HomeWidget.updateWidget(
      name: androidWidgetName,
      androidName: androidWidgetName,
      qualifiedAndroidName: 'com.quduman.quduman.QuranGlanceWidgetReceiver',
    );
  }

  static Future<int> getSavedVerseIndex() async {
    final index = await HomeWidget.getWidgetData<int>('current_verse_index', defaultValue: 1);
    return index ?? 1;
  }

  static Future<String> getSavedLanguage() async {
    final lang = await HomeWidget.getWidgetData<String>('selected_language', defaultValue: 'en');
    return lang ?? 'en';
  }
}
