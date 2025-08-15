# BASS FFI 音频播放器 API 文档

本文档详细描述了 BASS FFI 音频播放器的所有可用接口。这是一个基于 BASS 音频库的 C/C++ FFI 库，可以被其他编程语言（如 Dart/Flutter, Python, C# 等）调用。

## 目录

1. [基本播放控制](#基本播放控制)
2. [音量和位置控制](#音量和位置控制)
3. [均衡器控制](#均衡器控制)
4. [音频信息获取](#音频信息获取)
5. [音频效果](#音频效果)
6. [循环模式](#循环模式)
7. [淡入淡出](#淡入淡出)
8. [音频分析](#音频分析)
9. [播放列表支持](#播放列表支持)
10. [错误处理](#错误处理)

## 基本播放控制

### `create_music_player()`
```c
void* create_music_player();
```
创建一个新的音乐播放器实例。

**返回值：**
- 成功：返回播放器实例指针
- 失败：返回 NULL

**示例：**
```c
void* player = create_music_player();
```

### `destroy_music_player(void* player)`
```c
void destroy_music_player(void* player);
```
销毁音乐播放器实例，释放所有资源。

**参数：**
- `player`: 播放器实例指针

**示例：**
```c
destroy_music_player(player);
```

### `initialize_player(void* player)`
```c
int initialize_player(void* player);
```
初始化 BASS 音频库。在使用其他功能前必须先调用此函数。

**参数：**
- `player`: 播放器实例指针

**返回值：**
- 1: 初始化成功
- 0: 初始化失败

**示例：**
```c
if (initialize_player(player)) {
    printf("BASS 初始化成功\n");
}
```

### `cleanup_player(void* player)`
```c
void cleanup_player(void* player);
```
清理播放器资源，关闭 BASS 音频库。

**参数：**
- `player`: 播放器实例指针

### `load_file(void* player, const char* filename)`
```c
int load_file(void* player, const char* filename);
```
加载音频文件。支持多种格式：MP3, WAV, OGG, FLAC, AAC 等。

**参数：**
- `player`: 播放器实例指针
- `filename`: 音频文件路径（UTF-8编码）

**返回值：**
- 1: 加载成功
- 0: 加载失败

**示例：**
```c
if (load_file(player, "music.mp3")) {
    printf("文件加载成功\n");
}
```

### `play_music(void* player)`
```c
int play_music(void* player);
```
开始播放音乐。如果之前暂停，则恢复播放。

**参数：**
- `player`: 播放器实例指针

**返回值：**
- 1: 播放成功
- 0: 播放失败

### `pause_music(void* player)`
```c
int pause_music(void* player);
```
暂停音乐播放。

**参数：**
- `player`: 播放器实例指针

**返回值：**
- 1: 暂停成功
- 0: 暂停失败

### `stop_music(void* player)`
```c
int stop_music(void* player);
```
停止音乐播放，播放位置重置到开头。

**参数：**
- `player`: 播放器实例指针

**返回值：**
- 1: 停止成功
- 0: 停止失败

### `is_playing(void* player)`
```c
int is_playing(void* player);
```
检查音乐是否正在播放。

**参数：**
- `player`: 播放器实例指针

**返回值：**
- 1: 正在播放
- 0: 未播放

### `is_paused(void* player)`
```c
int is_paused(void* player);
```
检查音乐是否暂停。

**参数：**
- `player`: 播放器实例指针

**返回值：**
- 1: 已暂停
- 0: 未暂停

## 音量和位置控制

### `set_volume(void* player, float volume)`
```c
void set_volume(void* player, float volume);
```
设置播放音量。

**参数：**
- `player`: 播放器实例指针
- `volume`: 音量值 (0.0 到 1.0)

**示例：**
```c
set_volume(player, 0.8f); // 设置为80%音量
```

### `get_volume(void* player)`
```c
float get_volume(void* player);
```
获取当前播放音量。

**参数：**
- `player`: 播放器实例指针

**返回值：**
- 音量值 (0.0 到 1.0)

### `get_position(void* player)`
```c
double get_position(void* player);
```
获取当前播放位置（秒）。

**参数：**
- `player`: 播放器实例指针

**返回值：**
- 当前位置（秒）
- -1.0: 位置未知或错误

### `get_length(void* player)`
```c
double get_length(void* player);
```
获取音频文件总长度（秒）。

**参数：**
- `player`: 播放器实例指针

**返回值：**
- 总长度（秒）
- -1.0: 长度未知或错误

### `set_position(void* player, double position)`
```c
int set_position(void* player, double position);
```
设置播放位置（秒）。

**参数：**
- `player`: 播放器实例指针
- `position`: 目标位置（秒）

**返回值：**
- 1: 设置成功
- 0: 设置失败

## 均衡器控制

### `enable_equalizer(void* player, int enable)`
```c
int enable_equalizer(void* player, int enable);
```
启用或禁用10段均衡器。

**参数：**
- `player`: 播放器实例指针
- `enable`: 1=启用, 0=禁用

**返回值：**
- 1: 操作成功
- 0: 操作失败

### `is_equalizer_enabled(void* player)`
```c
int is_equalizer_enabled(void* player);
```
检查均衡器是否启用。

**参数：**
- `player`: 播放器实例指针

**返回值：**
- 1: 已启用
- 0: 未启用

### `set_eq_gain(void* player, int band, float gain)`
```c
int set_eq_gain(void* player, int band, float gain);
```
设置指定频段的增益。

**参数：**
- `player`: 播放器实例指针
- `band`: 频段索引 (0-9)
  - 0: 32Hz
  - 1: 64Hz
  - 2: 125Hz
  - 3: 250Hz
  - 4: 500Hz
  - 5: 1kHz
  - 6: 2kHz
  - 7: 4kHz
  - 8: 8kHz
  - 9: 16kHz
- `gain`: 增益值 (-15.0 到 15.0 dB)

**返回值：**
- 1: 设置成功
- 0: 设置失败

**示例：**
```c
// 增强低音 (32Hz)
set_eq_gain(player, 0, 5.0f);
// 降低高音 (16kHz)
set_eq_gain(player, 9, -3.0f);
```

### `get_eq_gain(void* player, int band)`
```c
float get_eq_gain(void* player, int band);
```
获取指定频段的增益。

**参数：**
- `player`: 播放器实例指针
- `band`: 频段索引 (0-9)

**返回值：**
- 增益值 (dB)

### `reset_equalizer(void* player)`
```c
void reset_equalizer(void* player);
```
重置所有均衡器频段增益为0。

**参数：**
- `player`: 播放器实例指针

### `get_eq_frequencies(void* player, float* frequencies, int max_count)`
```c
int get_eq_frequencies(void* player, float* frequencies, int max_count);
```
获取均衡器所有频段的频率值。

**参数：**
- `player`: 播放器实例指针
- `frequencies`: 用于存储频率值的数组
- `max_count`: 数组最大容量

**返回值：**
- 实际返回的频率数量

## 音频信息获取

### `get_current_file(void* player, char* buffer, int buffer_size)`
```c
int get_current_file(void* player, char* buffer, int buffer_size);
```
获取当前加载的文件路径。

**参数：**
- `player`: 播放器实例指针
- `buffer`: 用于存储文件路径的缓冲区
- `buffer_size`: 缓冲区大小

**返回值：**
- 实际写入的字符数

### `get_sample_rate(void* player)`
```c
int get_sample_rate(void* player);
```
获取音频采样率。

**参数：**
- `player`: 播放器实例指针

**返回值：**
- 采样率 (Hz)，如 44100, 48000

### `get_channels(void* player)`
```c
int get_channels(void* player);
```
获取音频声道数。

**参数：**
- `player`: 播放器实例指针

**返回值：**
- 声道数 (1=单声道, 2=立体声, 等)

### `get_bitrate(void* player)`
```c
int get_bitrate(void* player);
```
获取音频比特率估算值。

**参数：**
- `player`: 播放器实例指针

**返回值：**
- 比特率 (kbps)

## 音频效果

### `set_pitch(void* player, float pitch)`
```c
int set_pitch(void* player, float pitch);
```
设置音调（不改变播放速度）。

**参数：**
- `player`: 播放器实例指针
- `pitch`: 音调变化 (-60.0 到 60.0 半音)

**返回值：**
- 1: 设置成功
- 0: 设置失败

**示例：**
```c
set_pitch(player, 12.0f); // 提高一个八度
set_pitch(player, -12.0f); // 降低一个八度
```

### `get_pitch(void* player)`
```c
float get_pitch(void* player);
```
获取当前音调设置。

### `set_tempo(void* player, float tempo)`
```c
int set_tempo(void* player, float tempo);
```
设置播放速度（不改变音调）。

**参数：**
- `player`: 播放器实例指针
- `tempo`: 速度倍数 (0.5 到 2.0)

**返回值：**
- 1: 设置成功
- 0: 设置失败

**示例：**
```c
set_tempo(player, 1.5f); // 1.5倍速播放
set_tempo(player, 0.75f); // 0.75倍速播放
```

### `get_tempo(void* player)`
```c
float get_tempo(void* player);
```
获取当前播放速度。

### `set_rate(void* player, float rate)`
```c
int set_rate(void* player, float rate);
```
设置播放速率（同时改变音调和速度）。

**参数：**
- `player`: 播放器实例指针
- `rate`: 速率倍数 (0.5 到 2.0)

**返回值：**
- 1: 设置成功
- 0: 设置失败

### `get_rate(void* player)`
```c
float get_rate(void* player);
```
获取当前播放速率。

## 循环模式

### `set_loop_mode(void* player, int loop)`
```c
int set_loop_mode(void* player, int loop);
```
设置循环播放模式。

**参数：**
- `player`: 播放器实例指针
- `loop`: 1=启用循环, 0=禁用循环

**返回值：**
- 1: 设置成功
- 0: 设置失败

### `get_loop_mode(void* player)`
```c
int get_loop_mode(void* player);
```
获取循环播放模式状态。

**参数：**
- `player`: 播放器实例指针

**返回值：**
- 1: 启用循环
- 0: 禁用循环

## 淡入淡出

### `fade_in(void* player, int duration_ms)`
```c
int fade_in(void* player, int duration_ms);
```
淡入播放，音量从0逐渐增加到设定值。

**参数：**
- `player`: 播放器实例指针
- `duration_ms`: 淡入持续时间（毫秒）

**返回值：**
- 1: 开始淡入成功
- 0: 淡入失败

**示例：**
```c
fade_in(player, 3000); // 3秒淡入
```

### `fade_out(void* player, int duration_ms)`
```c
int fade_out(void* player, int duration_ms);
```
淡出播放，音量逐渐降低到0。

**参数：**
- `player`: 播放器实例指针
- `duration_ms`: 淡出持续时间（毫秒）

**返回值：**
- 1: 开始淡出成功
- 0: 淡出失败

**示例：**
```c
fade_out(player, 2000); // 2秒淡出
```

## 音频分析

### `get_fft_data(void* player, float* fft_data, int size)`
```c
int get_fft_data(void* player, float* fft_data, int size);
```
获取FFT频谱数据，用于音频可视化。

**参数：**
- `player`: 播放器实例指针
- `fft_data`: 用于存储FFT数据的数组
- `size`: 数组大小（建议256, 512, 1024等2的幂次）

**返回值：**
- 1: 获取成功
- 0: 获取失败

**示例：**
```c
float fft[512];
if (get_fft_data(player, fft, 512)) {
    // 使用FFT数据进行频谱显示
}
```

### `get_waveform_data(void* player, float* wave_data, int size)`
```c
int get_waveform_data(void* player, float* wave_data, int size);
```
获取波形数据，用于波形可视化。

**参数：**
- `player`: 播放器实例指针
- `wave_data`: 用于存储波形数据的数组
- `size`: 数组大小

**返回值：**
- 1: 获取成功
- 0: 获取失败

### `get_level_left(void* player)`
```c
float get_level_left(void* player);
```
获取左声道电平值。

**参数：**
- `player`: 播放器实例指针

**返回值：**
- 左声道电平 (0.0 到 1.0)

### `get_level_right(void* player)`
```c
float get_level_right(void* player);
```
获取右声道电平值。

**参数：**
- `player`: 播放器实例指针

**返回值：**
- 右声道电平 (0.0 到 1.0)

### `get_peak_level(void* player)`
```c
float get_peak_level(void* player);
```
获取峰值电平（左右声道最大值）。

**参数：**
- `player`: 播放器实例指针

**返回值：**
- 峰值电平 (0.0 到 1.0)

## 播放列表支持

### `set_next_file(void* player, const char* filename)`
```c
int set_next_file(void* player, const char* filename);
```
设置下一个要播放的文件。

**参数：**
- `player`: 播放器实例指针
- `filename`: 下一个文件的路径

**返回值：**
- 1: 设置成功
- 0: 设置失败

### `play_next(void* player)`
```c
int play_next(void* player);
```
播放下一个文件（由set_next_file设置）。

**参数：**
- `player`: 播放器实例指针

**返回值：**
- 1: 播放成功
- 0: 播放失败（可能没有设置下一个文件）

## 错误处理

### `get_last_error(void* player)`
```c
int get_last_error(void* player);
```
获取最后一次操作的错误代码。

**参数：**
- `player`: 播放器实例指针

**返回值：**
- 错误代码（0表示无错误）

### `get_error_string(int error_code, char* buffer, int buffer_size)`
```c
int get_error_string(int error_code, char* buffer, int buffer_size);
```
获取错误代码对应的错误描述。

**参数：**
- `error_code`: 错误代码
- `buffer`: 用于存储错误描述的缓冲区
- `buffer_size`: 缓冲区大小

**返回值：**
- 实际写入的字符数

**示例：**
```c
int error = get_last_error(player);
if (error != 0) {
    char error_msg[256];
    get_error_string(error, error_msg, 256);
    printf("错误: %s\n", error_msg);
}
```

## 使用示例

### 基本播放流程

```c
// 1. 创建播放器
void* player = create_music_player();
if (!player) {
    printf("创建播放器失败\n");
    return -1;
}

// 2. 初始化
if (!initialize_player(player)) {
    printf("初始化失败\n");
    destroy_music_player(player);
    return -1;
}

// 3. 加载文件
if (!load_file(player, "music.mp3")) {
    printf("加载文件失败\n");
    cleanup_player(player);
    destroy_music_player(player);
    return -1;
}

// 4. 设置音量
set_volume(player, 0.8f);

// 5. 开始播放
if (play_music(player)) {
    printf("开始播放\n");
}

// 6. 清理资源
cleanup_player(player);
destroy_music_player(player);
```

### 均衡器使用示例

```c
// 启用均衡器
enable_equalizer(player, 1);

// 设置各频段增益（重低音效果）
set_eq_gain(player, 0, 8.0f);   // 32Hz +8dB
set_eq_gain(player, 1, 6.0f);   // 64Hz +6dB
set_eq_gain(player, 2, 4.0f);   // 125Hz +4dB
set_eq_gain(player, 3, 2.0f);   // 250Hz +2dB
set_eq_gain(player, 4, 0.0f);   // 500Hz 0dB
set_eq_gain(player, 5, -1.0f);  // 1kHz -1dB
set_eq_gain(player, 6, -2.0f);  // 2kHz -2dB
set_eq_gain(player, 7, -3.0f);  // 4kHz -3dB
set_eq_gain(player, 8, -4.0f);  // 8kHz -4dB
set_eq_gain(player, 9, -5.0f);  // 16kHz -5dB
```

### 音频可视化示例

```c
// 获取FFT数据进行频谱显示
float fft[512];
if (get_fft_data(player, fft, 512)) {
    for (int i = 0; i < 256; i++) { // 只使用前半部分
        float magnitude = fft[i];
        // 在这里绘制频谱柱状图
        printf("频段 %d: %.3f\n", i, magnitude);
    }
}

// 获取电平数据
float left = get_level_left(player);
float right = get_level_right(player);
float peak = get_peak_level(player);
printf("左声道: %.2f, 右声道: %.2f, 峰值: %.2f\n", left, right, peak);
```

## 注意事项

1. **内存管理**: 使用完播放器后必须调用 `destroy_music_player()` 释放资源。

2. **文件路径**: 文件路径应使用UTF-8编码，支持包含中文和特殊字符的路径。

3. **线程安全**: 此FFI库不是线程安全的，如需在多线程环境中使用，请添加适当的同步机制。

4. **支持格式**: 支持的音频格式取决于BASS库，通常包括MP3, WAV, OGG, FLAC, AAC等主流格式。

5. **效果链**: 音频效果（均衡器、音调、速度）可以同时使用，但过多的效果可能影响性能。

6. **错误处理**: 建议在每次重要操作后检查错误状态，以便及时发现和处理问题。

## 编译说明

使用提供的task来编译DLL：

```bash
# 编译完整的FFI库
"C/C++: g++.exe 生成 Flutter FFI DLL (链接 BASS 库)"
```

确保以下文件在项目目录中：
- `bass.dll` 和 `bass_fx.dll` (运行时需要)
- `bass.lib` 和 `bass_fx.lib` (编译时需要)
- `bass.h` 和 `bass_fx.h` (头文件)

## 版本信息

- BASS FFI 版本: 1.0.0
- BASS 库版本: 2.4+
- 支持平台: Windows x64
- 编译器: GCC (MinGW)
