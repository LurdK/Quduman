import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../models/verse.dart';
import '../services/audio_service.dart';
import '../services/database_service.dart';
import '../services/widget_service.dart';

class ReaderScreen extends StatefulWidget {
  final int initialVerseId;
  final bool initialUseMalay;

  const ReaderScreen({
    super.key,
    required this.initialVerseId,
    this.initialUseMalay = false,
  });

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  final DatabaseService _db = DatabaseService.instance;
  final AudioService _audio = AudioService.instance;

  Verse? _currentVerse;
  List<String> _displayTokens = [];
  List<AcousticSegment> _acousticSegments = [];
  int _activeWordIndex = -1;
  bool _isLoading = true;
  bool _useMalay = false;

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<PlayerState>? _playerStateSub;

  @override
  void initState() {
    super.initState();
    _useMalay = widget.initialUseMalay;
    _loadVerse(widget.initialVerseId);
    _setupAudioListeners();
  }

  void _setupAudioListeners() {
    _positionSub = _audio.positionStream.listen((position) {
      if (_displayTokens.isEmpty) return;
      final currentMs = position.inMilliseconds;

      int matchedIndex = -1;
      for (final seg in _acousticSegments) {
        if (currentMs >= seg.startMs && currentMs < seg.endMs) {
          matchedIndex = seg.wordIndex;
          break;
        }
      }

      if (matchedIndex != -1) {
        if (matchedIndex >= _displayTokens.length) {
          matchedIndex = _displayTokens.length - 1;
        }
        if (matchedIndex != _activeWordIndex && mounted) {
          setState(() => _activeWordIndex = matchedIndex);
        }
      }
    });

    _playerStateSub = _audio.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        if (mounted) {
          setState(() => _activeWordIndex = -1);
        }
      }
    });
  }

  List<String> _tokenizeArabic(String text) {
    final rawTokens = text.trim().split(RegExp(r'\s+'));
    final waqfRegex = RegExp(r'^[\u06D6-\u06DC\u06DE\u06E9\u06DF-\u06E8\u06DD]+$');
    final words = <String>[];
    for (final t in rawTokens) {
      if (t.isEmpty) continue;
      if (waqfRegex.hasMatch(t)) {
        if (words.isNotEmpty) {
          words[words.length - 1] += ' $t';
        }
      } else {
        words.add(t);
      }
    }
    return words;
  }

  Future<void> _loadVerse(int verseId) async {
    setState(() => _isLoading = true);
    await _audio.stop();

    final verse = await _db.getVerseById(verseId);
    if (verse == null) return;

    final tokens = _tokenizeArabic(verse.textArabic);
    final duration = await _audio.loadVerse(verse);

    var acousticSegments = verse.acousticSegments;
    if (acousticSegments.isEmpty) {
      final totalMs = duration?.inMilliseconds ?? (tokens.length * 800);
      final perWordMs = (totalMs / (tokens.isEmpty ? 1 : tokens.length)).round();
      acousticSegments = List.generate(
        tokens.length,
        (i) => AcousticSegment(
          wordIndex: i,
          startMs: i * perWordMs,
          endMs: (i + 1) * perWordMs,
        ),
      );
    }

    if (!mounted) return;

    setState(() {
      _currentVerse = verse;
      _displayTokens = tokens;
      _acousticSegments = acousticSegments;
      _activeWordIndex = -1;
      _isLoading = false;
    });

    // Sync active verse with Android home screen widget
    await WidgetService.updateActiveVerse(verse, useMalay: _useMalay);
  }

  Future<void> _advanceToNextVerse() async {
    if (_currentVerse == null) return;
    final nextId = (_currentVerse!.id % 6236) + 1;
    await _loadVerse(nextId);
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _playerStateSub?.cancel();
    _audio.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading || _currentVerse == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final verse = _currentVerse!;
    final translation = _useMalay && verse.translationMs.isNotEmpty
        ? verse.translationMs
        : verse.translationEn;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back to Selector',
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('${verse.surahNameEn} (${verse.surahNumber}:${verse.ayahNumber})'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: _useMalay ? 'Switch to English' : 'Switch to Malay',
            icon: Icon(_useMalay ? Icons.translate : Icons.language),
            onPressed: () {
              setState(() => _useMalay = !_useMalay);
              WidgetService.updateActiveVerse(verse, useMalay: _useMalay);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Scrollable Verse Reader Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Surah & Ayah Badge
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${verse.surahNameAr} • Verse ${verse.ayahNumber} of 6236',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Decorative Bismillah header for verse 1 (except Surah 1 & Surah 9)
                    if (verse.ayahNumber == 1 && verse.surahNumber != 1 && verse.surahNumber != 9) ...[
                      Center(
                        child: Text(
                          'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'AmiriQuran',
                            fontSize: 22,
                            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Arabic Text with Word-by-Word Acoustic Karaoke Highlighting
                    Directionality(
                      textDirection: TextDirection.rtl,
                      child: RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          children: _displayTokens.asMap().entries.map((entry) {
                            final i = entry.key;
                            final text = entry.value;
                            final isActive = i == _activeWordIndex;
                            return TextSpan(
                              text: '$text ',
                              style: TextStyle(
                                fontFamily: 'AmiriQuran',
                                fontSize: 28,
                                height: 2.2,
                                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                                color: isActive
                                    ? Colors.amber
                                    : theme.colorScheme.onSurface,
                                backgroundColor: isActive
                                    ? Colors.amber.withValues(alpha: 0.2)
                                    : Colors.transparent,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),

                    const SizedBox(height: 36),
                    const Divider(),
                    const SizedBox(height: 20),

                    // Translation
                    Text(
                      _useMalay ? 'Terjemahan (Basmeih):' : 'Translation (Saheeh International):',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      translation,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        height: 1.6,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Audio & Action Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Audio Play / Pause
                  StreamBuilder<PlayerState>(
                    stream: _audio.playerStateStream,
                    builder: (context, snapshot) {
                      final playerState = snapshot.data;
                      final isPlaying = playerState?.playing ?? false;

                      return IconButton.filled(
                        iconSize: 28,
                        icon: Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                        onPressed: () {
                          if (isPlaying) {
                            _audio.pause();
                          } else {
                            _audio.play();
                          }
                        },
                      );
                    },
                  ),
                  const SizedBox(width: 8),

                  // Stop / Replay
                  IconButton.filledTonal(
                    icon: const Icon(Icons.replay_rounded),
                    onPressed: () {
                      _audio.seek(Duration.zero);
                      _audio.play();
                    },
                  ),

                  const Spacer(),

                  // Forward-Only [Next Ayah ->] Button (No Back Button)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _advanceToNextVerse,
                    icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                    label: const Text(
                      'Next Ayah →',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
