import 'dart:convert';

class Verse {
  final int id; // 1 to 6236 (global verse index)
  final int surahNumber; // 1 to 114
  final String surahNameEn;
  final String surahNameAr;
  final int ayahNumber;
  final String textArabic;
  final String translationEn;
  final String translationMs;
  final String? timestampsJson;

  const Verse({
    required this.id,
    required this.surahNumber,
    required this.surahNameEn,
    required this.surahNameAr,
    required this.ayahNumber,
    required this.textArabic,
    required this.translationEn,
    required this.translationMs,
    this.timestampsJson,
  });

  factory Verse.fromMap(Map<String, dynamic> map) {
    return Verse(
      id: map['id'] as int,
      surahNumber: map['surah_number'] as int,
      surahNameEn: map['surah_name_en'] as String? ?? '',
      surahNameAr: map['surah_name_ar'] as String? ?? '',
      ayahNumber: map['ayah_number'] as int,
      textArabic: map['text_arabic'] as String? ?? '',
      translationEn: map['translation_en'] as String? ?? '',
      translationMs: map['translation_ms'] as String? ?? '',
      timestampsJson: map['timestamps_json'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'surah_number': surahNumber,
      'surah_name_en': surahNameEn,
      'surah_name_ar': surahNameAr,
      'ayah_number': ayahNumber,
      'text_arabic': textArabic,
      'translation_en': translationEn,
      'translation_ms': translationMs,
      'timestamps_json': timestampsJson,
    };
  }

  /// Parses timestamps JSON into list of AcousticSegment [wordIndex, startMs, endMs]
  List<AcousticSegment> get acousticSegments {
    if (timestampsJson == null || timestampsJson!.isEmpty) return [];
    try {
      final decoded = jsonDecode(timestampsJson!);
      if (decoded is List) {
        return decoded.map<AcousticSegment>((item) {
          if (item is List && item.length >= 3) {
            return AcousticSegment(
              wordIndex: item[0] as int,
              startMs: item[1] as int,
              endMs: item[2] as int,
            );
          } else if (item is List && item.length == 2) {
            return AcousticSegment(
              wordIndex: 0,
              startMs: item[0] as int,
              endMs: item[1] as int,
            );
          }
          return const AcousticSegment(wordIndex: 0, startMs: 0, endMs: 1000);
        }).toList();
      }
    } catch (_) {}
    return [];
  }

  /// Audio URL from EveryAyah CDN
  String getAudioUrl({String reciter = 'Husary_128kbps'}) {
    final s = surahNumber.toString().padLeft(3, '0');
    final a = ayahNumber.toString().padLeft(3, '0');
    return 'https://everyayah.com/data/$reciter/$s$a.mp3';
  }
}

class AcousticSegment {
  final int wordIndex;
  final int startMs;
  final int endMs;

  const AcousticSegment({
    required this.wordIndex,
    required this.startMs,
    required this.endMs,
  });
}

class SurahInfo {
  final int number;
  final String nameEn;
  final String nameAr;
  final int totalAyahs;

  const SurahInfo({
    required this.number,
    required this.nameEn,
    required this.nameAr,
    required this.totalAyahs,
  });
}
