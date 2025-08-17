import 'dart:ffi';
import 'package:ffi/ffi.dart';

// BASS FFI 绑定类
class BassFfiService {
  static BassFfiService? _instance;
  late DynamicLibrary _bassLib;
  Pointer<Void>? _player;

  // 单例模式
  static BassFfiService get instance {
    _instance ??= BassFfiService._();
    return _instance!;
  }

  BassFfiService._();

  // 初始化BASS库
  bool initialize() {
    try {
      // 加载BASS_FFI.dll
      _bassLib = DynamicLibrary.open('BASS_FFI.dll');

      // 创建播放器实例
      _player = _createMusicPlayer();

      if (_player == nullptr) {
        return false;
      }

      // 初始化播放器
      return _initializePlayer(_player!) == 1;
    } catch (e) {
      print('BASS初始化失败: $e');
      return false;
    }
  }

  // 清理资源
  void dispose() {
    if (_player != nullptr) {
      _cleanupPlayer(_player!);
      _destroyMusicPlayer(_player!);
      _player = nullptr;
    }
  }

  // ==================== 基本播放控制 ====================

  // 加载音频文件
  bool loadFile(String filePath) {
    if (_player == nullptr) return false;

    final pathPtr = filePath.toNativeUtf8();
    try {
      return _loadFile(_player!, pathPtr.cast<Char>()) == 1;
    } finally {
      malloc.free(pathPtr);
    }
  }

  // 播放音乐
  bool play() {
    if (_player == nullptr) return false;
    return _playMusic(_player!) == 1;
  }

  // 暂停音乐
  bool pause() {
    if (_player == nullptr) return false;
    return _pauseMusic(_player!) == 1;
  }

  // 停止音乐
  bool stop() {
    if (_player == nullptr) return false;
    return _stopMusic(_player!) == 1;
  }

  // 检查是否正在播放
  bool get isPlaying {
    if (_player == nullptr) return false;
    return _isPlaying(_player!) == 1;
  }

  // 检查是否暂停
  bool get isPaused {
    if (_player == nullptr) return false;
    return _isPaused(_player!) == 1;
  }

  // ==================== 音量和位置控制 ====================

  // 设置音量 (0.0 - 1.0)
  void setVolume(double volume) {
    if (_player == nullptr) return;
    _setVolume(_player!, volume);
  }

  // 获取音量
  double get volume {
    if (_player == nullptr) return 0.0;
    return _getVolume(_player!);
  }

  // 获取当前播放位置（秒）
  double get position {
    if (_player == nullptr) return 0.0;
    return _getPosition(_player!);
  }

  // 获取音频总长度（秒）
  double get length {
    if (_player == nullptr) return 0.0;
    return _getLength(_player!);
  }

  // 设置播放位置（秒）
  bool setPosition(double position) {
    if (_player == nullptr) return false;
    return _setPosition(_player!, position) == 1;
  }

  // ==================== FFI 函数绑定 ====================

  // 创建播放器实例
  Pointer<Void> _createMusicPlayer() {
    final func = _bassLib.lookupFunction<Pointer<Void> Function(), Pointer<Void> Function()>('create_music_player');
    return func();
  }

  // 销毁播放器实例
  void _destroyMusicPlayer(Pointer<Void> player) {
    final func = _bassLib.lookupFunction<Void Function(Pointer<Void>), void Function(Pointer<Void>)>('destroy_music_player');
    func(player);
  }

  // 初始化播放器
  int _initializePlayer(Pointer<Void> player) {
    final func = _bassLib.lookupFunction<Int32 Function(Pointer<Void>), int Function(Pointer<Void>)>('initialize_player');
    return func(player);
  }

  // 清理播放器
  void _cleanupPlayer(Pointer<Void> player) {
    final func = _bassLib.lookupFunction<Void Function(Pointer<Void>), void Function(Pointer<Void>)>('cleanup_player');
    func(player);
  }

  // 加载文件
  int _loadFile(Pointer<Void> player, Pointer<Char> filename) {
    final func = _bassLib.lookupFunction<Int32 Function(Pointer<Void>, Pointer<Char>), int Function(Pointer<Void>, Pointer<Char>)>('load_file');
    return func(player, filename);
  }

  // 播放音乐
  int _playMusic(Pointer<Void> player) {
    final func = _bassLib.lookupFunction<Int32 Function(Pointer<Void>), int Function(Pointer<Void>)>('play_music');
    return func(player);
  }

  // 暂停音乐
  int _pauseMusic(Pointer<Void> player) {
    final func = _bassLib.lookupFunction<Int32 Function(Pointer<Void>), int Function(Pointer<Void>)>('pause_music');
    return func(player);
  }

  // 停止音乐
  int _stopMusic(Pointer<Void> player) {
    final func = _bassLib.lookupFunction<Int32 Function(Pointer<Void>), int Function(Pointer<Void>)>('stop_music');
    return func(player);
  }

  // 检查是否播放
  int _isPlaying(Pointer<Void> player) {
    final func = _bassLib.lookupFunction<Int32 Function(Pointer<Void>), int Function(Pointer<Void>)>('is_playing');
    return func(player);
  }

  // 检查是否暂停
  int _isPaused(Pointer<Void> player) {
    final func = _bassLib.lookupFunction<Int32 Function(Pointer<Void>), int Function(Pointer<Void>)>('is_paused');
    return func(player);
  }

  // 设置音量
  void _setVolume(Pointer<Void> player, double volume) {
    final func = _bassLib.lookupFunction<Void Function(Pointer<Void>, Float), void Function(Pointer<Void>, double)>('set_volume');
    func(player, volume);
  }

  // 获取音量
  double _getVolume(Pointer<Void> player) {
    final func = _bassLib.lookupFunction<Float Function(Pointer<Void>), double Function(Pointer<Void>)>('get_volume');
    return func(player);
  }

  // 获取位置
  double _getPosition(Pointer<Void> player) {
    final func = _bassLib.lookupFunction<Double Function(Pointer<Void>), double Function(Pointer<Void>)>('get_position');
    return func(player);
  }

  // 获取长度
  double _getLength(Pointer<Void> player) {
    final func = _bassLib.lookupFunction<Double Function(Pointer<Void>), double Function(Pointer<Void>)>('get_length');
    return func(player);
  }

  // 设置位置
  int _setPosition(Pointer<Void> player, double position) {
    final func = _bassLib.lookupFunction<Int32 Function(Pointer<Void>, Double), int Function(Pointer<Void>, double)>('set_position');
    return func(player, position);
  }
}
