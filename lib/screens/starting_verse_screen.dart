import 'package:flutter/material.dart';
import '../models/verse.dart';
import '../services/database_service.dart';
import '../services/widget_service.dart';
import 'about_screen.dart';
import 'reader_screen.dart';

class StartingVerseScreen extends StatefulWidget {
  const StartingVerseScreen({super.key});

  @override
  State<StartingVerseScreen> createState() => _StartingVerseScreenState();
}

class _StartingVerseScreenState extends State<StartingVerseScreen> {
  final DatabaseService _db = DatabaseService.instance;

  int _currentIndex = 0;
  List<SurahInfo> _surahs = [];
  int _selectedSurah = 1;
  int _selectedAyah = 1;
  int _maxAyahs = 7;
  bool _isLoading = true;
  bool _useMalay = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final surahs = await _db.getAllSurahs();
    final savedIndex = await WidgetService.getSavedVerseIndex();
    final savedLang = await WidgetService.getSavedLanguage();
    final currentVerse = await _db.getVerseById(savedIndex) ?? await _db.getVerseById(1);

    int initialSurah = 1;
    int initialAyah = 1;
    if (currentVerse != null) {
      initialSurah = currentVerse.surahNumber;
      initialAyah = currentVerse.ayahNumber;
    }

    final maxAyahs = await _db.getMaxAyahsForSurah(initialSurah);

    setState(() {
      _surahs = surahs;
      _selectedSurah = initialSurah;
      _selectedAyah = initialAyah;
      _maxAyahs = maxAyahs;
      _useMalay = savedLang == 'ms';
      _isLoading = false;
    });
  }

  Future<void> _onSurahChanged(int? newSurah) async {
    if (newSurah == null) return;
    final max = await _db.getMaxAyahsForSurah(newSurah);
    setState(() {
      _selectedSurah = newSurah;
      _maxAyahs = max;
      if (_selectedAyah > max) {
        _selectedAyah = 1;
      }
    });
  }

  Future<void> _setActiveVerseOnly() async {
    final verse = await _db.getVerseBySurahAndAyah(_selectedSurah, _selectedAyah);
    if (verse == null) return;

    await WidgetService.updateActiveVerse(verse, useMalay: _useMalay);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Active verse set to ${verse.surahNameEn} ${verse.surahNumber}:${verse.ayahNumber}'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _enterReadingMode() async {
    final verse = await _db.getVerseBySurahAndAyah(_selectedSurah, _selectedAyah);
    if (verse == null) return;

    await WidgetService.updateActiveVerse(verse, useMalay: _useMalay);

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReaderScreen(initialVerseId: verse.id, initialUseMalay: _useMalay),
      ),
    ).then((_) => _loadInitialData());
  }

  Widget _buildConfigView(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          // Header description
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Column(
              children: [
                const Icon(Icons.menu_book_rounded, size: 36, color: Colors.amber),
                const SizedBox(height: 10),
                Text(
                  'Daily Quran Verse',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Select your starting point. The home screen widget will advance one verse forward at a time.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // Surah Selector
          Text('Select Surah', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.outline),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _selectedSurah,
                isExpanded: true,
                items: _surahs.map((s) {
                  return DropdownMenuItem<int>(
                    value: s.number,
                    child: Row(
                      children: [
                        Text('${s.number}. ', style: const TextStyle(fontWeight: FontWeight.bold)),
                        Expanded(child: Text(s.nameEn)),
                        Text(s.nameAr, style: const TextStyle(fontFamily: 'AmiriQuran', fontSize: 18)),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: _onSurahChanged,
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Ayah Selector
          Text('Select Ayah (1 - $_maxAyahs)', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.outline),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _selectedAyah,
                isExpanded: true,
                items: List.generate(_maxAyahs, (i) => i + 1).map((ayahNum) {
                  return DropdownMenuItem<int>(
                    value: ayahNum,
                    child: Text('Ayah $ayahNum'),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedAyah = val);
                },
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Language toggle
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Malay Translation (Basmeih)'),
            subtitle: const Text('Default is English (Saheeh International)'),
            value: _useMalay,
            onChanged: (val) {
              setState(() => _useMalay = val);
              _setActiveVerseOnly();
            },
          ),

          const SizedBox(height: 24),

          // Action 1: Set Active Verse Button
          OutlinedButton.icon(
            onPressed: _setActiveVerseOnly,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.bookmark_added_rounded),
            label: const Text(
              'Set as Active Verse',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 12),

          // Action 2: Enter Reading Mode Button
          FilledButton.icon(
            onPressed: _enterReadingMode,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.auto_stories_rounded),
            label: const Text(
              'Enter Reading Mode',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentIndex == 0
            ? 'Quduman • قدوما'
            : _currentIndex == 1
                ? 'Reading Mode'
                : 'About'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex == 1 ? 0 : _currentIndex,
          children: [
            _buildConfigView(theme),
            const SizedBox.shrink(),
            const AboutScreen(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          if (index == 1) {
            _enterReadingMode();
          } else {
            setState(() => _currentIndex = index);
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.tune_rounded),
            selectedIcon: Icon(Icons.tune_rounded, color: Colors.amber),
            label: 'Active Verse',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_stories_outlined),
            selectedIcon: Icon(Icons.auto_stories_rounded, color: Colors.amber),
            label: 'Reading Mode',
          ),
          NavigationDestination(
            icon: Icon(Icons.info_outline_rounded),
            selectedIcon: Icon(Icons.info_rounded, color: Colors.amber),
            label: 'About',
          ),
        ],
      ),
    );
  }
}
