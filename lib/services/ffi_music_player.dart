import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

class FFIMusicPlayer {
  static DynamicLibrary? _lib;

  late final Pointer<NativeFunction<Pointer<Void> Function()>> _createMusicPlayer;
  late final Pointer<NativeFunction<Void Function(Pointer<Void>)>> _destroyMusicPlayer;
  late final Pointer<NativeFunction<Int32 Function(Pointer<Void>)>> _initializePlayer;
  late final Pointer<NativeFunction<Int32 Function(Pointer<Void>)>> _isInitialized;
  late final Pointer<NativeFunction<Void Function(Pointer<Void>)>> _cleanupPlayer;
  late final Pointer<NativeFunction<Int32 Function(Pointer<Void>, Pointer<Utf8>)>> _loadFile;
  late final Pointer<NativeFunction<Int32 Function(Pointer<Void>)>> _playMusic;
  late final Pointer<NativeFunction<Int32 Function(Pointer<Void>)>> _pauseMusic;
  late final Pointer<NativeFunction<Int32 Function(Pointer<Void>)>> _stopMusic;
  late final Pointer<NativeFunction<Int32 Function(Pointer<Void>)>> _isPlaying;
  late final Pointer<NativeFunction<Int32 Function(Pointer<Void>)>> _isPaused;
  late final Pointer<NativeFunction<Void Function(Pointer<Void>, Float)>> _setVolume;
  late final Pointer<NativeFunction<Float Function(Pointer<Void>)>> _getVolume;
  late final Pointer<NativeFunction<Double Function(Pointer<Void>)>> _getPosition;
  late final Pointer<NativeFunction<Double Function(Pointer<Void>)>> _getLength;
  late final Pointer<NativeFunction<Int32 Function(Pointer<Void>, Double)>> _setPosition;
  // Preamp related native function pointers
  late final Pointer<NativeFunction<Int32 Function(Pointer<Void>, Float)>> _setPreampDb;
  late final Pointer<NativeFunction<Float Function(Pointer<Void>)>> _getPreampDb;
  // Equalizer related native function pointers
  late final Pointer<NativeFunction<Int32 Function(Pointer<Void>, Int32)>> _enableEqualizer;
  late final Pointer<NativeFunction<Int32 Function(Pointer<Void>)>> _isEqualizerEnabled;
  late final Pointer<NativeFunction<Int32 Function(Pointer<Void>, Int32, Float)>> _setEqGain;
  late final Pointer<NativeFunction<Float Function(Pointer<Void>, Int32)>> _getEqGain;
  late final Pointer<NativeFunction<Void Function(Pointer<Void>)>> _resetEqualizer;

  late final Pointer<Void> Function() createMusicPlayer;
  late final void Function(Pointer<Void>) destroyMusicPlayer;
  late final int Function(Pointer<Void>) initializePlayer;
  late final int Function(Pointer<Void>) isInitialized;
  late final void Function(Pointer<Void>) cleanupPlayer;
  late final int Function(Pointer<Void>, Pointer<Utf8>) loadFile;
  late final int Function(Pointer<Void>) playMusic;
  late final int Function(Pointer<Void>) pauseMusic;
  late final int Function(Pointer<Void>) stopMusic;
  late final int Function(Pointer<Void>) isPlaying;
  late final int Function(Pointer<Void>) isPaused;
  late final void Function(Pointer<Void>, double) setVolume;
  late final double Function(Pointer<Void>) getVolume;
  late final double Function(Pointer<Void>) getPosition;
  late final double Function(Pointer<Void>) getLength;
  late final int Function(Pointer<Void>, double) setPosition;
  // Preamp related dart function typedefs
  late final int Function(Pointer<Void>, double) setPreampDb;
  late final double Function(Pointer<Void>) getPreampDb;
  // Equalizer related dart function typedefs
  late final int Function(Pointer<Void>, int) enableEqualizer;
  late final int Function(Pointer<Void>) isEqualizerEnabled;
  late final int Function(Pointer<Void>, int, double) setEqGain;
  late final double Function(Pointer<Void>, int) getEqGain;
  late final void Function(Pointer<Void>) resetEqualizer;

  Pointer<Void>? _playerInstance;

  FFIMusicPlayer() {
    _loadLibrary();
    _bindFunctions();
  }

  void _loadLibrary() {
    if (Platform.isWindows) {
      _lib = DynamicLibrary.open('music_player.dll');
    }
  }

  void _bindFunctions() {
    _createMusicPlayer = _lib!.lookup<NativeFunction<Pointer<Void> Function()>>('create_music_player');
    _destroyMusicPlayer = _lib!.lookup<NativeFunction<Void Function(Pointer<Void>)>>('destroy_music_player');
    _initializePlayer = _lib!.lookup<NativeFunction<Int32 Function(Pointer<Void>)>>('initialize_player');
    _isInitialized = _lib!.lookup<NativeFunction<Int32 Function(Pointer<Void>)>>('is_initialized');
    _cleanupPlayer = _lib!.lookup<NativeFunction<Void Function(Pointer<Void>)>>('cleanup_player');
    _loadFile = _lib!.lookup<NativeFunction<Int32 Function(Pointer<Void>, Pointer<Utf8>)>>('load_file');
    _playMusic = _lib!.lookup<NativeFunction<Int32 Function(Pointer<Void>)>>('play_music');
    _pauseMusic = _lib!.lookup<NativeFunction<Int32 Function(Pointer<Void>)>>('pause_music');
    _stopMusic = _lib!.lookup<NativeFunction<Int32 Function(Pointer<Void>)>>('stop_music');
    _isPlaying = _lib!.lookup<NativeFunction<Int32 Function(Pointer<Void>)>>('is_playing');
    _isPaused = _lib!.lookup<NativeFunction<Int32 Function(Pointer<Void>)>>('is_paused');
    _setVolume = _lib!.lookup<NativeFunction<Void Function(Pointer<Void>, Float)>>('set_volume');
    _getVolume = _lib!.lookup<NativeFunction<Float Function(Pointer<Void>)>>('get_volume');
    _getPosition = _lib!.lookup<NativeFunction<Double Function(Pointer<Void>)>>('get_position');
    _getLength = _lib!.lookup<NativeFunction<Double Function(Pointer<Void>)>>('get_length');
    _setPosition = _lib!.lookup<NativeFunction<Int32 Function(Pointer<Void>, Double)>>('set_position');
    // Preamp bindings
    _setPreampDb = _lib!.lookup<NativeFunction<Int32 Function(Pointer<Void>, Float)>>('set_preamp_db');
    _getPreampDb = _lib!.lookup<NativeFunction<Float Function(Pointer<Void>)>>('get_preamp_db');
    // Equalizer bindings
    _enableEqualizer = _lib!.lookup<NativeFunction<Int32 Function(Pointer<Void>, Int32)>>('enable_equalizer');
    _isEqualizerEnabled = _lib!.lookup<NativeFunction<Int32 Function(Pointer<Void>)>>('is_equalizer_enabled');
    _setEqGain = _lib!.lookup<NativeFunction<Int32 Function(Pointer<Void>, Int32, Float)>>('set_eq_gain');
    _getEqGain = _lib!.lookup<NativeFunction<Float Function(Pointer<Void>, Int32)>>('get_eq_gain');
    _resetEqualizer = _lib!.lookup<NativeFunction<Void Function(Pointer<Void>)>>('reset_equalizer');

    createMusicPlayer = _createMusicPlayer.asFunction<Pointer<Void> Function()>();
    destroyMusicPlayer = _destroyMusicPlayer.asFunction<void Function(Pointer<Void>)>();
    initializePlayer = _initializePlayer.asFunction<int Function(Pointer<Void>)>();
    isInitialized = _isInitialized.asFunction<int Function(Pointer<Void>)>();
    cleanupPlayer = _cleanupPlayer.asFunction<void Function(Pointer<Void>)>();
    loadFile = _loadFile.asFunction<int Function(Pointer<Void>, Pointer<Utf8>)>();
    playMusic = _playMusic.asFunction<int Function(Pointer<Void>)>();
    pauseMusic = _pauseMusic.asFunction<int Function(Pointer<Void>)>();
    stopMusic = _stopMusic.asFunction<int Function(Pointer<Void>)>();
    isPlaying = _isPlaying.asFunction<int Function(Pointer<Void>)>();
    isPaused = _isPaused.asFunction<int Function(Pointer<Void>)>();
    setVolume = _setVolume.asFunction<void Function(Pointer<Void>, double)>();
    getVolume = _getVolume.asFunction<double Function(Pointer<Void>)>();
    getPosition = _getPosition.asFunction<double Function(Pointer<Void>)>();
    getLength = _getLength.asFunction<double Function(Pointer<Void>)>();
    setPosition = _setPosition.asFunction<int Function(Pointer<Void>, double)>();
    // Preamp
    setPreampDb = _setPreampDb.asFunction<int Function(Pointer<Void>, double)>();
    getPreampDb = _getPreampDb.asFunction<double Function(Pointer<Void>)>();
    // Equalizer
    enableEqualizer = _enableEqualizer.asFunction<int Function(Pointer<Void>, int)>();
    isEqualizerEnabled = _isEqualizerEnabled.asFunction<int Function(Pointer<Void>)>();
    setEqGain = _setEqGain.asFunction<int Function(Pointer<Void>, int, double)>();
    getEqGain = _getEqGain.asFunction<double Function(Pointer<Void>, int)>();
    resetEqualizer = _resetEqualizer.asFunction<void Function(Pointer<Void>)>();
  }

  Future<bool> initialize() async {
    _playerInstance = createMusicPlayer();
    if (_playerInstance == nullptr) {
      return false;
    }
    return initializePlayer(_playerInstance!) == 1;
  }

  // Equalizer high-level wrappers
  Future<bool> setEqualizerEnabled(bool enabled) async {
    if (_playerInstance == null || _playerInstance == nullptr) return false;
    // 防止重复启用导致底层可能叠加：若状态一致，直接返回成功
    final bool current = equalizerEnabled;
    if ((enabled && current) || (!enabled && !current)) {
      return true;
    }
    return enableEqualizer(_playerInstance!, enabled ? 1 : 0) == 1;
  }

  bool get equalizerEnabled {
    if (_playerInstance == null || _playerInstance == nullptr) return false;
    return isEqualizerEnabled(_playerInstance!) == 1;
  }

  Future<bool> setBandGain(int band, double gain) async {
    if (_playerInstance == null || _playerInstance == nullptr) return false;
    if (band < 0 || band > 9) return false;
    final clamped = gain.clamp(-15.0, 15.0);
    return setEqGain(_playerInstance!, band, clamped.toDouble()) == 1;
  }

  double getBandGain(int band) {
    if (_playerInstance == null || _playerInstance == nullptr) return 0.0;
    if (band < 0 || band > 9) return 0.0;
    return getEqGain(_playerInstance!, band);
  }

  void resetEq() {
    if (_playerInstance == null || _playerInstance == nullptr) return;
    resetEqualizer(_playerInstance!);
  }

  bool get initialized {
    if (_playerInstance == null || _playerInstance == nullptr) {
      return false;
    }
    return isInitialized(_playerInstance!) == 1;
  }

  Future<bool> loadAudioFile(String filePath) async {
    if (_playerInstance == null || _playerInstance == nullptr) {
      return false;
    }

    final pathPtr = filePath.toNativeUtf8();
    final result = loadFile(_playerInstance!, pathPtr);
    malloc.free(pathPtr);
    return result == 1;
  }

  Future<bool> play() async {
    if (_playerInstance == null || _playerInstance == nullptr) {
      return false;
    }

    return playMusic(_playerInstance!) == 1;
  }

  Future<bool> pause() async {
    if (_playerInstance == null || _playerInstance == nullptr) {
      return false;
    }

    return pauseMusic(_playerInstance!) == 1;
  }

  Future<bool> stop() async {
    if (_playerInstance == null || _playerInstance == nullptr) {
      return false;
    }

    return stopMusic(_playerInstance!) == 1;
  }

  bool get playing {
    if (_playerInstance == null || _playerInstance == nullptr) {
      return false;
    }

    return isPlaying(_playerInstance!) == 1;
  }

  bool get paused {
    if (_playerInstance == null || _playerInstance == nullptr) {
      return false;
    }

    return isPaused(_playerInstance!) == 1;
  }

  Future<void> changeVolume(double volume) async {
    if (_playerInstance == null || _playerInstance == nullptr) {
      return;
    }

    final clampedVolume = volume.clamp(0.0, 1.0);
    setVolume(_playerInstance!, clampedVolume);
  }

  double get volume {
    if (_playerInstance == null || _playerInstance == nullptr) {
      return 0.0;
    }

    return getVolume(_playerInstance!);
  }

  double get position {
    if (_playerInstance == null || _playerInstance == nullptr) {
      return 0.0;
    }

    return getPosition(_playerInstance!);
  }

  double get duration {
    if (_playerInstance == null || _playerInstance == nullptr) {
      return 0.0;
    }

    return getLength(_playerInstance!);
  }

  Future<bool> seek(double position) async {
    if (_playerInstance == null || _playerInstance == nullptr) {
      return false;
    }

    return setPosition(_playerInstance!, position) == 1;
  }

  // ================= Preamp high-level wrappers =================
  Future<bool> changePreampDb(double db) async {
    if (_playerInstance == null || _playerInstance == nullptr) return false;
    final clamped = db.clamp(-12.0, 12.0);
    return setPreampDb(_playerInstance!, clamped.toDouble()) == 1;
  }

  double get preampDb {
    if (_playerInstance == null || _playerInstance == nullptr) return 0.0;
    return getPreampDb(_playerInstance!);
  }

  void dispose() {
    if (_playerInstance != null && _playerInstance != nullptr) {
      cleanupPlayer(_playerInstance!);
      destroyMusicPlayer(_playerInstance!);
      _playerInstance = null;
    }
  }
}
