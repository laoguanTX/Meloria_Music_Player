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
      // 加载music_player.dll
      _bassLib = DynamicLibrary.open('music_player.dll');

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

  // ==================== 10 段均衡器控制 ====================

  // 启用/禁用均衡器
  bool enableEqualizer(bool enable) {
    if (_player == nullptr) return false;
    // 防止重复叠加：如果状态未变化则不再次调用底层启用逻辑
    final bool current = isEqualizerEnabled;
    if ((enable && current) || (!enable && !current)) {
      return true;
    }
    return _enableEqualizer(_player!, enable ? 1 : 0) == 1;
  }

  // 检查均衡器是否启用
  bool get isEqualizerEnabled {
    if (_player == nullptr) return false;
    return _isEqualizerEnabled(_player!) == 1;
  }

  // 设置指定频段的增益 (band: 0-9, gain: -15~+15 dB)
  bool setEqGain(int band, double gain) {
    if (_player == nullptr) return false;
    final clamped = gain.clamp(-15.0, 15.0).toDouble();
    return _setEqGain(_player!, band, clamped) == 1;
  }

  // 获取指定频段增益
  double getEqGain(int band) {
    if (_player == nullptr) return 0.0;
    return _getEqGain(_player!, band);
  }

  // 重置均衡器（所有频段置 0dB）
  void resetEqualizer() {
    if (_player == nullptr) return;
    _resetEqualizer(_player!);
  }

  // 获取 10 段频率（Hz）
  List<double> getEqFrequencies() {
    if (_player == nullptr) {
      return const [32.0, 64.0, 125.0, 250.0, 500.0, 1000.0, 2000.0, 4000.0, 8000.0, 16000.0];
    }
    final frequencies = malloc<Float>(10);
    try {
      final count = _getEqFrequencies(_player!, frequencies, 10);
      if (count > 0) {
        return List<double>.generate(count, (i) => frequencies[i].toDouble());
      }
    } finally {
      malloc.free(frequencies);
    }
    return const [32.0, 64.0, 125.0, 250.0, 500.0, 1000.0, 2000.0, 4000.0, 8000.0, 16000.0];
  }

  // ==================== 前置放大（Preamp）控制 ====================

  // 设置前置放大（单位 dB，范围 -12.0 ~ 12.0）
  bool setPreampDb(double db) {
    if (_player == nullptr) return false;
    final clamped = db.clamp(-12.0, 12.0).toDouble();
    return _setPreampDb(_player!, clamped) == 1;
  }

  // 获取当前前置放大（单位 dB）
  double get preampDb {
    if (_player == nullptr) return 0.0;
    return _getPreampDb(_player!);
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

  // ==================== 10 段均衡器 FFI 绑定 ====================

  // 启用/禁用均衡器
  int _enableEqualizer(Pointer<Void> player, int enable) {
    final func = _bassLib.lookupFunction<Int32 Function(Pointer<Void>, Int32), int Function(Pointer<Void>, int)>('enable_equalizer');
    return func(player, enable);
  }

  // 检查均衡器是否启用
  int _isEqualizerEnabled(Pointer<Void> player) {
    final func = _bassLib.lookupFunction<Int32 Function(Pointer<Void>), int Function(Pointer<Void>)>('is_equalizer_enabled');
    return func(player);
  }

  // 设置频段增益
  int _setEqGain(Pointer<Void> player, int band, double gain) {
    final func = _bassLib.lookupFunction<Int32 Function(Pointer<Void>, Int32, Float), int Function(Pointer<Void>, int, double)>('set_eq_gain');
    return func(player, band, gain);
  }

  // 获取频段增益
  double _getEqGain(Pointer<Void> player, int band) {
    final func = _bassLib.lookupFunction<Float Function(Pointer<Void>, Int32), double Function(Pointer<Void>, int)>('get_eq_gain');
    return func(player, band);
  }

  // 重置均衡器
  void _resetEqualizer(Pointer<Void> player) {
    final func = _bassLib.lookupFunction<Void Function(Pointer<Void>), void Function(Pointer<Void>)>('reset_equalizer');
    func(player);
  }

  // 获取频率列表
  int _getEqFrequencies(Pointer<Void> player, Pointer<Float> frequencies, int maxCount) {
    final func = _bassLib
        .lookupFunction<Int32 Function(Pointer<Void>, Pointer<Float>, Int32), int Function(Pointer<Void>, Pointer<Float>, int)>('get_eq_frequencies');
    return func(player, frequencies, maxCount);
  }

  // ==================== Preamp FFI 绑定 ====================

  // 设置前置放大（dB）
  int _setPreampDb(Pointer<Void> player, double db) {
    final func = _bassLib.lookupFunction<Int32 Function(Pointer<Void>, Float), int Function(Pointer<Void>, double)>('set_preamp_db');
    return func(player, db);
  }

  // 获取前置放大（dB）
  double _getPreampDb(Pointer<Void> player) {
    final func = _bassLib.lookupFunction<Float Function(Pointer<Void>), double Function(Pointer<Void>)>('get_preamp_db');
    return func(player);
  }
}
