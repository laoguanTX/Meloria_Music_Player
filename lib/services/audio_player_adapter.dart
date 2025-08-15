import 'dart:async';
import 'ffi_music_player.dart';

enum PlayerState { stopped, playing, paused, completed }

class AudioPlayer {
  final FFIMusicPlayer _ffiPlayer = FFIMusicPlayer();

  final StreamController<Duration> _durationController = StreamController<Duration>.broadcast();
  final StreamController<Duration> _positionController = StreamController<Duration>.broadcast();
  final StreamController<void> _playerCompleteController = StreamController<void>.broadcast();

  Timer? _positionTimer;
  PlayerState _playerState = PlayerState.stopped;
  String? _currentFilePath;
  double _volume = 0.5;
  bool _isInitialized = false;

  Stream<Duration> get onDurationChanged => _durationController.stream;
  Stream<Duration> get onPositionChanged => _positionController.stream;
  Stream<void> get onPlayerComplete => _playerCompleteController.stream;

  AudioPlayer() {
    _initialize();
  }

  Future<void> _initialize() async {
    if (_isInitialized || _ffiPlayer.initialized) {
      _isInitialized = true;
      await _ffiPlayer.changeVolume(_volume);
      return;
    }
    final success = await _ffiPlayer.initialize();
    if (success || _ffiPlayer.initialized) {
      _isInitialized = true;
      await _ffiPlayer.changeVolume(_volume);
    }
  }

  Future<void> play(dynamic source) async {
    String? filePath;

    if (source is DeviceFileSource) {
      filePath = source.path;
    } else if (source is String) {
      filePath = source;
    } else {
      return;
    }

    if (_currentFilePath != filePath) {
      final loadSuccess = await _ffiPlayer.loadAudioFile(filePath);
      if (!loadSuccess) {
        print('加载音频文件失败: $filePath');
        return;
      }
      _currentFilePath = filePath;

      final durationSeconds = _ffiPlayer.duration;
      if (durationSeconds > 0) {
        _durationController.add(Duration(milliseconds: (durationSeconds * 1000).round()));
      }
    }

    final playSuccess = await _ffiPlayer.play();
    if (playSuccess) {
      _playerState = PlayerState.playing;
      _startPositionTimer();
    }
  }

  Future<void> pause() async {
    if (!_isInitialized) return;
    final success = await _ffiPlayer.pause();
    if (success) {
      _playerState = PlayerState.paused;
      _stopPositionTimer();
    }
  }

  Future<void> resume() async {
    if (!_isInitialized) return;

    final success = await _ffiPlayer.play();
    if (success) {
      _playerState = PlayerState.playing;
      _startPositionTimer();
    }
  }

  Future<void> stop() async {
    if (!_isInitialized) return;

    final success = await _ffiPlayer.stop();
    if (success) {
      _playerState = PlayerState.stopped;
      _stopPositionTimer();
      _positionController.add(Duration.zero);
    }
  }

  Future<void> seek(Duration position) async {
    if (!_isInitialized) return;

    final positionSeconds = position.inMilliseconds / 1000.0;
    final success = await _ffiPlayer.seek(positionSeconds);
    if (success) {
      _positionController.add(position);
    }
  }

  Future<void> setVolume(double volume) async {
    if (!_isInitialized) return;

    _volume = volume.clamp(0.0, 1.0);
    await _ffiPlayer.changeVolume(_volume);
  }

  double get volume => _volume;

  bool get isPlaying => _playerState == PlayerState.playing && _ffiPlayer.playing;

  // ================= Equalizer API =================
  Future<bool> enableEqualizer(bool enable) async {
    if (!_isInitialized) {
      await _initialize();
    }
    return await _ffiPlayer.setEqualizerEnabled(enable);
  }

  bool get isEqualizerEnabled => _ffiPlayer.equalizerEnabled;

  Future<bool> setEqGain(int band, double gain) async {
    if (!_isInitialized) {
      await _initialize();
    }
    return await _ffiPlayer.setBandGain(band, gain);
  }

  double getEqGain(int band) => _ffiPlayer.getBandGain(band);

  void resetEqualizer() {
    if (_isInitialized) {
      _ffiPlayer.resetEq();
    }
  }
  // ==================================================

  void _startPositionTimer() {
    _stopPositionTimer();
    _positionTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      _updatePosition();
    });
  }

  void _stopPositionTimer() {
    _positionTimer?.cancel();
    _positionTimer = null;
  }

  void _updatePosition() {
    if (!_isInitialized) return;

    final positionSeconds = _ffiPlayer.position;
    final durationSeconds = _ffiPlayer.duration;

    final position = Duration(milliseconds: (positionSeconds * 1000).round());
    _positionController.add(position);

    if (durationSeconds > 0 && positionSeconds >= durationSeconds - 0.1) {
      _onPlaybackComplete();
    }
  }

  void _onPlaybackComplete() {
    _playerState = PlayerState.completed;
    _stopPositionTimer();
    _playerCompleteController.add(null);
  }

  void dispose() {
    _stopPositionTimer();
    _ffiPlayer.dispose();
    _durationController.close();
    _positionController.close();
    _playerCompleteController.close();
  }
}

class DeviceFileSource {
  final String path;

  DeviceFileSource(this.path);
}

class UrlSource {
  final String url;

  UrlSource(this.url);
}
