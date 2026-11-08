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
  final ScrollController _scrollController = ScrollController();

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

          // Auto-scroll follow-along for longer verses
          if (_displayTokens.length > 25 && _scrollController.hasClients) {
            final progress = matchedIndex / _displayTokens.length;
            final maxScroll = _scrollController.position.maxScrollExtent;
            final targetScroll = progress * maxScroll;
            if ((targetScroll - _scrollController.offset).abs() > 40) {
              _scrollController.animateTo(
                targetScroll,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }
          }
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

    // Reset scroll position to top
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }

    // Sync active verse with Android home screen widget
    await WidgetService.updateActiveVerse(verse, useMalay: _useMalay);

    // Pre-fetch next verse's audio in background for zero-buffer playback on Next
    final nextId = (verse.id % 6236) + 1;
    _db.getVerseById(nextId).then((nextVerse) {
      if (nextVerse != null) {
        _audio.prefetchVerse(nextVerse);
      }
    });
  }

  Future<void> _advanceToNextVerse() async {
    if (_currentVerse == null) return;
    final nextId = (_currentVerse!.id % 6236) + 1;
    await _loadVerse(nextId);
  }

  Future<void> _goToPreviousVerse() async {
    if (_currentVerse == null) return;
    final prevId = (_currentVerse!.id - 2 + 6236) % 6236 + 1;
    await _loadVerse(prevId);
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _playerStateSub?.cancel();
    _audio.stop();
    _scrollController.dispose();
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

    // Adaptive Typography calculation based on word count
    final wordCount = _displayTokens.length;
    final arabicFontSize = (34.0 - (wordCount * 0.12)).clamp(19.0, 34.0);
    final arabicLineHeight = (2.3 - (wordCount * 0.0035)).clamp(1.85, 2.3);
    final translationFontSize = (17.5 - (wordCount * 0.035)).clamp(13.5, 17.5);
    final translationLineHeight = (1.6 - (wordCount * 0.0015)).clamp(1.4, 1.6);

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
            // Scrollable Verse Reader Body with auto-scroll support
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
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

                    // Arabic Text with Word-by-Word Acoustic Karaoke Highlighting & Adaptive Sizing
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
                                fontSize: arabicFontSize,
                                height: arabicLineHeight,
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

                    // Translation with Adaptive Typography
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
                      style: TextStyle(
                        fontSize: translationFontSize,
                        height: translationLineHeight,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Mini Audio Player Bar (Previous, Play/Pause, Replay, Next)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // 1. Previous Verse
                  IconButton.filledTonal(
                    tooltip: 'Previous Ayah',
                    iconSize: 26,
                    icon: const Icon(Icons.skip_previous_rounded),
                    onPressed: _goToPreviousVerse,
                  ),

                  // 2. Audio Play / Pause Toggle
                  StreamBuilder<PlayerState>(
                    stream: _audio.playerStateStream,
                    builder: (context, snapshot) {
                      final isPlaying = snapshot.data?.playing ?? false;

                      return IconButton.filled(
                        tooltip: isPlaying ? 'Pause' : 'Play Recitation',
                        iconSize: 34,
                        padding: const EdgeInsets.all(12),
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

                  // 3. Reset / Replay Current Verse
                  IconButton.filledTonal(
                    tooltip: 'Replay from start',
                    iconSize: 26,
                    icon: const Icon(Icons.replay_rounded),
                    onPressed: () {
                      _audio.seek(Duration.zero);
                      _audio.play();
                    },
                  ),

                  // 4. Next Verse
                  IconButton.filledTonal(
                    tooltip: 'Next Ayah',
                    iconSize: 26,
                    icon: const Icon(Icons.skip_next_rounded),
                    onPressed: _advanceToNextVerse,
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
