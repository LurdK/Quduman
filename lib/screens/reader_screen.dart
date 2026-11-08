import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../models/translation_edition.dart';
import '../models/verse.dart';
import '../services/audio_service.dart';
import '../services/database_service.dart';
import '../services/widget_service.dart';
import '../widgets/translation_selector_sheet.dart';

class ReaderScreen extends StatefulWidget {
  final int initialVerseId;
  final String initialEditionId;

  const ReaderScreen({
    super.key,
    required this.initialVerseId,
    this.initialEditionId = 'en.sahih',
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
  bool _isInitialLoading = true;
  bool _isPageLoading = false;
  String _selectedEdition = 'en.sahih';
  String _translationText = '';
  String _editionAuthor = '';

  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  bool _isSeeking = false;
  double _dragValue = 0.0;
  bool _autoPlay = false;

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<Duration?>? _durationSub;

  @override
  void initState() {
    super.initState();
    _selectedEdition = widget.initialEditionId;
    _loadVerse(widget.initialVerseId);
    _setupAudioListeners();
  }

  void _setupAudioListeners() {
    _positionSub = _audio.positionStream.listen((position) {
      if (!_isSeeking && mounted) {
        setState(() => _currentPosition = position);
      }
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

    _durationSub = _audio.durationStream.listen((duration) {
      if (mounted) {
        setState(() => _totalDuration = duration ?? Duration.zero);
      }
    });

    _playerStateSub = _audio.playerStateStream.listen((state) async {
      if (state.processingState == ProcessingState.completed) {
        await _audio.pauseAndReset();
        if (mounted) {
          setState(() {
            _activeWordIndex = -1;
            _currentPosition = Duration.zero;
          });
        }
      }
    });
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
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
    if (_currentVerse == null) {
      setState(() => _isInitialLoading = true);
    } else {
      setState(() => _isPageLoading = true);
    }
    await _audio.stop();

    final verse = await _db.getVerseById(verseId);
    if (verse == null) {
      if (mounted) {
        setState(() {
          _isInitialLoading = false;
          _isPageLoading = false;
        });
      }
      return;
    }

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

    // Fetch translation for active edition
    final trans = await _db.getVerseTranslation(verseId, editionId: _selectedEdition);

    if (_editionAuthor.isEmpty) {
      final downloaded = await _db.getDownloadedEditions();
      final active = downloaded.firstWhere(
        (e) => e.identifier == _selectedEdition,
        orElse: () => downloaded.isNotEmpty ? downloaded.first : const TranslationEdition(
          identifier: 'en.sahih',
          languageCode: 'en',
          name: 'Saheeh International',
          englishName: 'Saheeh International',
        ),
      );
      _editionAuthor = active.englishName;
    }

    if (!mounted) return;

    setState(() {
      _currentVerse = verse;
      _displayTokens = tokens;
      _acousticSegments = acousticSegments;
      _translationText = trans;
      _activeWordIndex = -1;
      _currentPosition = Duration.zero;
      _totalDuration = duration ?? Duration.zero;
      _isInitialLoading = false;
      _isPageLoading = false;
    });

    // Reset scroll position to top
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }

    // Sync active verse with Android home screen widget
    await WidgetService.updateActiveVerse(
      verse,
      translation: trans,
      selectedEdition: _selectedEdition,
    );

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
    if (_autoPlay) {
      await _audio.play();
    }
  }

  Future<void> _goToPreviousVerse() async {
    if (_currentVerse == null) return;
    final prevId = (_currentVerse!.id - 2 + 6236) % 6236 + 1;
    await _loadVerse(prevId);
    if (_autoPlay) {
      await _audio.play();
    }
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _playerStateSub?.cancel();
    _durationSub?.cancel();
    _audio.stop();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isInitialLoading || _currentVerse == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final verse = _currentVerse!;

    // Adaptive Typography calculation based on word count
    final wordCount = _displayTokens.length;
    final arabicFontSize = (34.0 - (wordCount * 0.12)).clamp(19.0, 34.0);
    final arabicLineHeight = (2.3 - (wordCount * 0.0035)).clamp(1.85, 2.3);
    final translationFontSize = (17.5 - (wordCount * 0.035)).clamp(13.5, 17.5);
    final translationLineHeight = (1.6 - (wordCount * 0.0015)).clamp(1.4, 1.6);

    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back to Selector',
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('${verse.surahNameEn} (${verse.surahNumber}:${verse.ayahNumber})'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Translations Library',
            icon: const Icon(Icons.translate_rounded),
            onPressed: () {
              TranslationSelectorSheet.show(
                context,
                activeEditionId: _selectedEdition,
                onEditionSelected: (edition) async {
                  setState(() {
                    _selectedEdition = edition.identifier;
                    _editionAuthor = edition.englishName;
                  });
                  if (_currentVerse != null) {
                    final updatedTrans = await _db.getVerseTranslation(
                      _currentVerse!.id,
                      editionId: _selectedEdition,
                    );
                    if (mounted) {
                      setState(() => _translationText = updatedTrans);
                    }
                    await WidgetService.updateActiveVerse(
                      _currentVerse!,
                      translation: updatedTrans,
                      selectedEdition: _selectedEdition,
                    );
                  }
                },
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Scrollable Verse Reader Body with auto-scroll support
            Expanded(
              child: _isPageLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
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
                      _editionAuthor.isNotEmpty
                          ? 'Translation ($_editionAuthor):'
                          : 'Translation:',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _translationText.isNotEmpty ? _translationText : verse.translationEn,
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

            // Bottom Mini Audio Player Bar with Audio Scrubber + Centered Controls
            Container(
              padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 12.0),
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. Interactive Audio Scrubber Progress Line
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: Row(
                      children: [
                        Text(
                          _formatDuration(_isSeeking
                              ? Duration(milliseconds: _dragValue.round())
                              : _currentPosition),
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 11,
                            color: theme.colorScheme.onSurfaceVariant,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 3.0,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                              activeTrackColor: theme.colorScheme.primary,
                              inactiveTrackColor: theme.colorScheme.surfaceContainerHighest,
                              thumbColor: theme.colorScheme.primary,
                            ),
                            child: Slider(
                              min: 0.0,
                              max: _totalDuration.inMilliseconds > 0
                                  ? _totalDuration.inMilliseconds.toDouble()
                                  : 1.0,
                              value: (_isSeeking
                                      ? _dragValue
                                      : _currentPosition.inMilliseconds.toDouble())
                                  .clamp(
                                0.0,
                                _totalDuration.inMilliseconds > 0
                                    ? _totalDuration.inMilliseconds.toDouble()
                                    : 1.0,
                              ),
                              onChangeStart: (val) {
                                _isSeeking = true;
                                _dragValue = val;
                              },
                              onChanged: _totalDuration.inMilliseconds > 0
                                  ? (val) {
                                      setState(() => _dragValue = val);
                                    }
                                  : null,
                              onChangeEnd: _totalDuration.inMilliseconds > 0
                                  ? (val) async {
                                      final target = Duration(milliseconds: val.round());
                                      await _audio.seek(target);
                                      if (mounted) {
                                        setState(() {
                                          _currentPosition = target;
                                          _isSeeking = false;
                                        });
                                      }
                                    }
                                  : null,
                            ),
                          ),
                        ),
                        Text(
                          _formatDuration(_totalDuration),
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 11,
                            color: theme.colorScheme.onSurfaceVariant,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 2. Control Buttons Bar: Centered Playback Group + Autoplay Toggle Button on Right
                  SizedBox(
                    height: 54,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Centered Playback Group [⏮ Previous, ▶/⏸ Play/Pause, ⏭ Next]
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // 1. Previous Ayah
                                IconButton(
                                  tooltip: 'Previous Ayah',
                                  iconSize: 26,
                                  icon: const Icon(Icons.skip_previous_rounded),
                                  onPressed: _goToPreviousVerse,
                                ),
                                const SizedBox(width: 8),

                                // 2. Play / Pause Toggle
                                StreamBuilder<PlayerState>(
                                  stream: _audio.playerStateStream,
                                  builder: (context, snapshot) {
                                    final isPlaying = snapshot.data?.playing ?? false;

                                    return IconButton.filled(
                                      tooltip: isPlaying ? 'Pause' : 'Play Recitation',
                                      iconSize: 32,
                                      padding: const EdgeInsets.all(10),
                                      icon: isPlaying
                                          ? const Icon(Icons.pause_rounded)
                                          : Transform.translate(
                                              offset: const Offset(1.5, -1.5),
                                              child: const Icon(Icons.play_arrow_rounded),
                                            ),
                                      onPressed: () async {
                                        if (isPlaying) {
                                          await _audio.pause();
                                        } else {
                                          if (_currentPosition >= _totalDuration && _totalDuration > Duration.zero) {
                                            await _audio.seek(Duration.zero);
                                            if (mounted) {
                                              setState(() => _currentPosition = Duration.zero);
                                            }
                                          }
                                          await _audio.play();
                                        }
                                      },
                                    );
                                  },
                                ),
                                const SizedBox(width: 8),

                                // 3. Next Ayah
                                IconButton(
                                  tooltip: 'Next Ayah',
                                  iconSize: 26,
                                  icon: const Icon(Icons.skip_next_rounded),
                                  onPressed: _advanceToNextVerse,
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Autoplay Circle Button on Right
                        Positioned(
                          right: 0,
                          child: IconButton.filledTonal(
                            tooltip: _autoPlay ? 'Autoplay on navigation: ON' : 'Autoplay on navigation: OFF',
                            iconSize: 22,
                            padding: const EdgeInsets.all(10),
                            style: IconButton.styleFrom(
                              backgroundColor: _autoPlay
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                              foregroundColor: _autoPlay
                                  ? theme.colorScheme.onPrimary
                                  : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                            ),
                            icon: Icon(_autoPlay ? Icons.auto_mode_rounded : Icons.auto_mode_outlined),
                            onPressed: () {
                              setState(() => _autoPlay = !_autoPlay);
                              ScaffoldMessenger.of(context).clearSnackBars();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    _autoPlay
                                        ? 'Autoplay ON: Verses will play automatically when navigating'
                                        : 'Autoplay OFF',
                                  ),
                                  duration: const Duration(seconds: 1),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
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
