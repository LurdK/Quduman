class TranslationEdition {
  final String identifier;
  final String languageCode;
  final String name;
  final String englishName;
  final String direction;
  final bool isDownloaded;

  const TranslationEdition({
    required this.identifier,
    required this.languageCode,
    required this.name,
    required this.englishName,
    this.direction = 'ltr',
    this.isDownloaded = false,
  });

  factory TranslationEdition.fromMap(Map<String, dynamic> map) {
    return TranslationEdition(
      identifier: map['identifier'] as String,
      languageCode: map['language_code'] as String,
      name: map['name'] as String,
      englishName: map['english_name'] as String,
      direction: map['direction'] as String? ?? 'ltr',
      isDownloaded: (map['is_downloaded'] as int? ?? 0) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'identifier': identifier,
      'language_code': languageCode,
      'name': name,
      'english_name': englishName,
      'direction': direction,
      'is_downloaded': isDownloaded ? 1 : 0,
    };
  }

  TranslationEdition copyWith({bool? isDownloaded}) {
    return TranslationEdition(
      identifier: identifier,
      languageCode: languageCode,
      name: name,
      englishName: englishName,
      direction: direction,
      isDownloaded: isDownloaded ?? this.isDownloaded,
    );
  }
}

