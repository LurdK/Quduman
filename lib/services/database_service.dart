import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
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
        if (version >= 3) {
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

    return await openDatabase(dbPath, readOnly: true);
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
}
