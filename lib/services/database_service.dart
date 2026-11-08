import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../models/translation_edition.dart';
import '../models/verse.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._internal();
  DatabaseService._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final dbPath = p.join(databasesPath, 'quran.db');

    bool needsCopy = true;
    if (await databaseExists(dbPath)) {
      try {
        final existingDb = await openDatabase(dbPath, readOnly: true);
        final versionRes = await existingDb.rawQuery("PRAGMA user_version");
        final version = Sqflite.firstIntValue(versionRes) ?? 0;
        await existingDb.close();
        if (version >= 4) {
          needsCopy = false;
        }
      } catch (_) {
        needsCopy = true;
      }
    }

    if (needsCopy) {
      try {
        await Directory(p.dirname(dbPath)).create(recursive: true);
      } catch (_) {}

      final data = await rootBundle.load('assets/databases/quran.db');
      final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      await File(dbPath).writeAsBytes(bytes, flush: true);
    }

    return await openDatabase(dbPath);
  }

  /// Get verse by global ID (1 to 6236)
  Future<Verse?> getVerseById(int id) async {
    final db = await database;
    final results = await db.query(
      'quran_verses',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (results.isNotEmpty) {
      return Verse.fromMap(results.first);
    }
    return null;
  }

  /// Get verse by Surah and Ayah number
  Future<Verse?> getVerseBySurahAndAyah(int surah, int ayah) async {
    final db = await database;
    final results = await db.query(
      'quran_verses',
      where: 'surah_number = ? AND ayah_number = ?',
      whereArgs: [surah, ayah],
      limit: 1,
    );
    if (results.isNotEmpty) {
      return Verse.fromMap(results.first);
    }
    return null;
  }

  /// Global Next Verse pointer formula: (current % 6236) + 1
  Future<Verse?> getNextVerse(int currentId) async {
    final nextId = (currentId % 6236) + 1;
    return getVerseById(nextId);
  }

  /// Fetch all 114 surahs with their name and verse counts
  Future<List<SurahInfo>> getAllSurahs() async {
    final db = await database;
    final results = await db.rawQuery('''
      SELECT 
        surah_number, 
        surah_name_en, 
        surah_name_ar, 
        COUNT(*) as total_ayahs
      FROM quran_verses
      GROUP BY surah_number
      ORDER BY surah_number ASC
    ''');

    return results.map((r) {
      return SurahInfo(
        number: r['surah_number'] as int,
        nameEn: r['surah_name_en'] as String,
        nameAr: r['surah_name_ar'] as String,
        totalAyahs: r['total_ayahs'] as int,
      );
    }).toList();
  }

  /// Get total ayahs in a specific surah
  Future<int> getMaxAyahsForSurah(int surahNumber) async {
    final db = await database;
    final results = await db.rawQuery('''
      SELECT COUNT(*) as count 
      FROM quran_verses 
      WHERE surah_number = ?
    ''', [surahNumber]);
    if (results.isNotEmpty) {
      return Sqflite.firstIntValue(results) ?? 7;
    }
    return 7;
  }

  /// Get all downloaded translation editions
  Future<List<TranslationEdition>> getDownloadedEditions() async {
    final db = await database;
    final results = await db.query(
      'translation_editions',
      where: 'is_downloaded = 1',
      orderBy: 'language_code ASC, name ASC',
    );
    return results.map((r) => TranslationEdition.fromMap(r)).toList();
  }

  /// Get all available translation editions (including those available for download)
  Future<List<TranslationEdition>> getAllAvailableEditions() async {
    final db = await database;
    final results = await db.query(
      'translation_editions',
      orderBy: 'language_code ASC, name ASC',
    );
    return results.map((r) => TranslationEdition.fromMap(r)).toList();
  }

  /// Get translation text for a verse given an edition identifier
  Future<String> getVerseTranslation(int verseId, {String editionId = 'en.sahih'}) async {
    final db = await database;
    final results = await db.query(
      'translations',
      columns: ['translation_text'],
      where: 'edition_id = ? AND verse_id = ?',
      whereArgs: [editionId, verseId],
      limit: 1,
    );
    if (results.isNotEmpty) {
      return results.first['translation_text'] as String? ?? '';
    }

    // Fallback: check quran_verses table
    final fallback = await db.query(
      'quran_verses',
      columns: ['translation_en', 'translation_ms'],
      where: 'id = ?',
      whereArgs: [verseId],
      limit: 1,
    );
    if (fallback.isNotEmpty) {
      if (editionId.startsWith('ms')) {
        return fallback.first['translation_ms'] as String? ?? fallback.first['translation_en'] as String? ?? '';
      }
      return fallback.first['translation_en'] as String? ?? '';
    }
    return '';
  }

  /// Download and store an edition from alquran.cloud into local SQLite
  Future<void> downloadAndStoreEdition(
    TranslationEdition edition, {
    void Function(double progress)? onProgress,
  }) async {
    final client = HttpClient();
    final url = 'https://api.alquran.cloud/v1/quran/${edition.identifier}';
    final request = await client.getUrl(Uri.parse(url));
    final response = await request.close();

    if (response.statusCode != 200) {
      throw Exception('Failed to download edition: HTTP ${response.statusCode}');
    }

    final responseBody = await response.transform(utf8.decoder).join();
    final decoded = jsonDecode(responseBody) as Map<String, dynamic>;
    final surahs = (decoded['data']?['surahs'] as List?) ?? [];

    final db = await database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      int verseIndex = 1;

      for (final s in surahs) {
        final ayahs = (s['ayahs'] as List?) ?? [];
        for (final a in ayahs) {
          final text = (a['text'] as String? ?? '').trim();
          batch.insert(
            'translations',
            {
              'edition_id': edition.identifier,
              'verse_id': verseIndex,
              'translation_text': text,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          verseIndex++;
        }
      }

      batch.update(
        'translation_editions',
        {'is_downloaded': 1},
        where: 'identifier = ?',
        whereArgs: [edition.identifier],
      );

      await batch.commit(noResult: true);
    });
  }

  /// Remove a downloaded edition from local SQLite (cannot remove pre-bundled editions)
  Future<void> removeDownloadedEdition(String editionId) async {
    const prebundled = [
      'en.sahih',
      'ms.basmeih',
      'id.indonesian',
      'fr.hamidullah',
      'tr.diyanet',
      'ur.jalandhry'
    ];
    if (prebundled.contains(editionId)) {
      // Do not delete pre-bundled defaults
      return;
    }
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(
        'translations',
        where: 'edition_id = ?',
        whereArgs: [editionId],
      );
      await txn.update(
        'translation_editions',
        {'is_downloaded': 0},
        where: 'identifier = ?',
        whereArgs: [editionId],
      );
    });
  }
}
