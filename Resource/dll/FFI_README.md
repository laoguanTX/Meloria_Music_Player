# FFI 音乐播放器实现

本项目已将原来的 `audioplayers` 包替换为基于 FFI 的 BASS 音频播放器实现。

## 修改内容

### 1. 新增文件

- `lib/services/ffi_music_player.dart` - FFI绑定库，直接调用C/C++音频播放器
- `lib/services/audio_player_adapter.dart` - 适配器，模拟audioplayers包的接口
- `Resource/dll/music_player_ffi.h` - C/C++头文件
- `test/ffi_music_player_test.dart` - 测试文件

### 2. 修改文件

- `lib/providers/music_provider.dart` - 将audioplayers替换为audio_player_adapter

### 3. 功能范围

根据要求，本次修改仅涉及：

#### 基本播放控制
- ✅ 播放/暂停/停止
- ✅ 播放状态检查
- ✅ 文件加载

#### 音量和位置控制  
- ✅ 音量设置/获取
- ✅ 播放位置设置/获取
- ✅ 音频总长度获取

#### 未修改的功能
- ❌ 均衡器控制
- ❌ 音频信息获取（采样率、声道等）
- ❌ 音频效果（音调、速度等）
- ❌ 循环模式（由Flutter层处理）
- ❌ 淡入淡出
- ❌ 音频分析（FFT、波形等）
- ❌ 播放列表支持（由Flutter层处理）

## 使用说明

### 1. 准备DLL文件

需要编译或获取以下文件并放置在 `Resource/dll/` 目录下：

```
Resource/dll/
├── music_player_ffi.dll    # 主要的FFI库
├── bass.dll               # BASS音频库
├── bass_fx.dll            # BASS音效库（可选）
└── music_player_ffi.h     # 头文件（已提供）
```

### 2. DLL接口规范

DLL必须实现以下C接口（详见music_player_ffi.h）：

```c
// 基本播放控制
void* create_music_player();
void destroy_music_player(void* player);
int initialize_player(void* player);
void cleanup_player(void* player);
int load_file(void* player, const char* filename);
int play_music(void* player);
int pause_music(void* player);
int stop_music(void* player);
int is_playing(void* player);
int is_paused(void* player);

// 音量和位置控制
void set_volume(void* player, float volume);
float get_volume(void* player);
double get_position(void* player);
double get_length(void* player);
int set_position(void* player, double position);
```

### 3. 编译DLL

可以使用以下工具编译DLL：
- Visual Studio
- MinGW/GCC
- Clang

示例编译命令（MinGW）：
```bash
gcc -shared -o music_player_ffi.dll music_player_ffi.c -lbass -lbass_fx
```

### 4. 测试

运行测试以验证FFI实现：

```bash
flutter test test/ffi_music_player_test.dart
```

## 技术详情

### 架构

```
MusicProvider (Flutter层)
    ↓
AudioPlayerAdapter (适配器层)
    ↓  
FFIMusicPlayer (FFI绑定层)
    ↓
music_player_ffi.dll (C/C++层)
    ↓
BASS Audio Library (底层音频库)
```

### 错误处理

- FFI调用失败时会打印错误信息
- 当DLL不存在时，播放器会优雅降级
- 所有异步操作都包含try-catch块

### 平台支持

- ✅ Windows (主要支持)
- ❌ macOS (未实现)
- ❌ Linux (未实现)  
- ❌ Web (不支持FFI)
- ❌ Mobile (Android/iOS，未实现)

## 注意事项

1. **DLL依赖**: 确保所有必需的DLL文件都在正确位置
2. **路径编码**: 文件路径需要使用UTF-8编码
3. **内存管理**: FFI播放器会自动管理内存，但需要正确调用dispose()
4. **线程安全**: 当前实现不是线程安全的
5. **错误处理**: 建议在生产环境中添加更完善的错误处理

## 开发者说明

如果需要扩展更多音频功能，可以：

1. 在 `music_player_ffi.h` 中添加新的C接口
2. 在 `ffi_music_player.dart` 中添加对应的FFI绑定
3. 在 `audio_player_adapter.dart` 中实现适配器方法
4. 更新 `music_provider.dart` 调用新功能

当前实现专注于基本播放控制和音量/位置控制，为将来的扩展提供了良好的基础架构。
