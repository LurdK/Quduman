import 'dart:io';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/verse.dart';

class AudioService {
  static final AudioService instance = AudioService._internal();
  AudioService._internal();

  final AudioPlayer _player = AudioPlayer();

  AudioPlayer get player => _player;
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<Duration?> get durationStream => _player.durationStream;

  String _currentReciter = 'Husary_128kbps';
  String get currentReciter => _currentReciter;

  void setReciter(String reciter) {
    _currentReciter = reciter;
  }

  Future<File> _getLocalAudioFile(int surah, int ayah, String reciter) async {
    final tempDir = await getTemporaryDirectory();
    final audioDir = Directory(p.join(tempDir.path, 'audio', reciter));
    if (!audioDir.existsSync()) {
      await audioDir.create(recursive: true);
    }
    final s = surah.toString().padLeft(3, '0');
    final a = ayah.toString().padLeft(3, '0');
    return File(p.join(audioDir.path, '$s$a.mp3'));
  }

  Future<Duration?> loadVerse(Verse verse) async {
    final url = verse.getAudioUrl(reciter: _currentReciter);
    final file = await _getLocalAudioFile(verse.surahNumber, verse.ayahNumber, _currentReciter);

    try {
      if (await file.exists() && await file.length() > 0) {
        // Play directly from persistent local disk cache
        return await _player.setFilePath(file.path);
      } else {
        // Stream while saving to cache for offline replay
        final duration = await _player.setUrl(url);
        _cacheAudioFile(url, file);
        return duration;
      }
    } catch (e) {
      // Offline fallback: check if file was partially cached
      if (await file.exists() && await file.length() > 0) {
        try {
          return await _player.setFilePath(file.path);
        } catch (_) {}
      }
      return null;
    }
  }

  void _cacheAudioFile(String url, File destFile) {
    Future(() async {
      try {
        final client = HttpClient();
        final request = await client.getUrl(Uri.parse(url));
        final response = await request.close();
        if (response.statusCode == 200) {
          final tempFile = File('${destFile.path}.tmp');
          final sink = tempFile.openWrite();
          await response.pipe(sink);
          if (await tempFile.exists() && await tempFile.length() > 0) {
            await tempFile.rename(destFile.path);
          }
        }
      } catch (_) {}
    });
  }

  /// Silently pre-fetches the audio of a verse in the background
  Future<void> prefetchVerse(Verse verse) async {
    try {
      final file = await _getLocalAudioFile(verse.surahNumber, verse.ayahNumber, _currentReciter);
      if (!await file.exists() || await file.length() == 0) {
        final url = verse.getAudioUrl(reciter: _currentReciter);
        _cacheAudioFile(url, file);
      }
    } catch (_) {}
  }

  Future<void> play() async {
    if (_player.processingState == ProcessingState.completed ||
        (_player.duration != null && _player.position >= _player.duration!)) {
      await _player.seek(Duration.zero);
    }
    await _player.play();
  }

  Future<void> pause() async {
    await _player.pause();
  }

  Future<void> pauseAndReset() async {
    await _player.pause();
    await _player.seek(Duration.zero);
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  Future<void> stop() async {
    await _player.stop();
  }

  void dispose() {
    _player.dispose();
  }
}

