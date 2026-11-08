import 'package:just_audio/just_audio.dart';
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

  Future<Duration?> loadVerse(Verse verse) async {
    final url = verse.getAudioUrl(reciter: _currentReciter);
    try {
      final duration = await _player.setUrl(url);
      return duration;
    } catch (e) {
      // In case of network error, return null
      return null;
    }
  }

  Future<void> play() async {
    await _player.play();
  }

  Future<void> pause() async {
    await _player.pause();
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

