# 均衡器使用指南

本指南详细介绍了 BASS FFI 音频播放器中两种均衡器的使用方法和最佳实践。

## 概述

BASS FFI 音频播放器提供了两种均衡器模式：

1. **标准10段均衡器**：传统的10段参数均衡器，每个频段独立调节
2. **样条曲线均衡器**：基于三次样条插值的31段精细均衡器，提供更平滑的频率响应

## 标准10段均衡器

### 特点
- 10个独立的频段控制
- 每个频段可独立调节增益（-15.0 到 +15.0 dB）
- 直观简单，适合快速调节

### 频率分布
```
频段 | 频率    | 说明
-----|---------|-------------
0    | 32Hz    | 极低音（低音炮频段）
1    | 64Hz    | 低音（贝斯、鼓）
2    | 125Hz   | 低中音
3    | 250Hz   | 中低音（人声基频）
4    | 500Hz   | 中音
5    | 1kHz    | 中高音（人声主要频段）
6    | 2kHz    | 高中音（人声清晰度）
7    | 4kHz    | 高音（乐器细节）
8    | 8kHz    | 超高音（泛音、空气感）
9    | 16kHz   | 极高音（细节、延伸）
```

### 使用示例
```c
// 创建播放器并初始化
void* player = create_music_player();
initialize_player(player);
load_file(player, "music.mp3");

// 启用标准均衡器
enable_equalizer(player, 1);

// 经典V型EQ设置（增强低音和高音）
set_eq_gain(player, 0, 6.0f);   // 32Hz +6dB
set_eq_gain(player, 1, 4.0f);   // 64Hz +4dB
set_eq_gain(player, 2, 2.0f);   // 125Hz +2dB
set_eq_gain(player, 3, 0.0f);   // 250Hz 0dB
set_eq_gain(player, 4, -2.0f);  // 500Hz -2dB
set_eq_gain(player, 5, -1.0f);  // 1kHz -1dB
set_eq_gain(player, 6, 0.0f);   // 2kHz 0dB
set_eq_gain(player, 7, 2.0f);   // 4kHz +2dB
set_eq_gain(player, 8, 4.0f);   // 8kHz +4dB
set_eq_gain(player, 9, 6.0f);   // 16kHz +6dB

// 开始播放
play_music(player);
```

## 样条曲线均衡器

### 特点
- 10个控制点，内部生成31段精细均衡器
- 使用Catmull-Rom三次样条插值算法
- 提供平滑、自然的频率响应曲线
- 避免了传统均衡器频段间的突变

### 工作原理
1. 用户设置10个控制点的增益值
2. 系统使用三次样条插值算法计算31个频段的增益
3. 应用到31段参数均衡器，实现平滑的频率响应

### 31段频率分布（第三倍频程）
```
频段 | 频率     | 频段 | 频率     | 频段 | 频率
-----|----------|------|----------|------|----------
0    | 20Hz     | 11   | 250Hz    | 22   | 2.5kHz
1    | 25Hz     | 12   | 315Hz    | 23   | 3.15kHz
2    | 32Hz     | 13   | 400Hz    | 24   | 4kHz
3    | 40Hz     | 14   | 500Hz    | 25   | 5kHz
4    | 50Hz     | 15   | 630Hz    | 26   | 6.3kHz
5    | 63Hz     | 16   | 800Hz    | 27   | 8kHz
6    | 80Hz     | 17   | 1kHz     | 28   | 10kHz
7    | 100Hz    | 18   | 1.25kHz  | 29   | 12.5kHz
8    | 125Hz    | 19   | 1.6kHz   | 30   | 16kHz
9    | 160Hz    | 20   | 2kHz     | 31   | 20kHz
10   | 200Hz    | 21   | 2.5kHz   |      |
```

### 使用示例
```c
// 创建播放器并初始化
void* player = create_music_player();
initialize_player(player);
load_file(player, "music.mp3");

// 启用样条均衡器
enable_spline_equalizer(player, 1);

// 设置控制点（与标准均衡器相同的频率位置）
set_spline_control_point(player, 0, 5.0f);   // 32Hz +5dB
set_spline_control_point(player, 1, 3.0f);   // 64Hz +3dB
set_spline_control_point(player, 2, 1.0f);   // 125Hz +1dB
set_spline_control_point(player, 3, 0.0f);   // 250Hz 0dB
set_spline_control_point(player, 4, -1.0f);  // 500Hz -1dB
set_spline_control_point(player, 5, 0.0f);   // 1kHz 0dB
set_spline_control_point(player, 6, 1.0f);   // 2kHz +1dB
set_spline_control_point(player, 7, 2.0f);   // 4kHz +2dB
set_spline_control_point(player, 8, 3.0f);   // 8kHz +3dB
set_spline_control_point(player, 9, 4.0f);   // 16kHz +4dB

// 样条曲线会自动应用，也可以手动强制更新
apply_spline_curve(player);

// 开始播放
play_music(player);
```

## 常用EQ预设

### 1. 摇滚音乐
```c
// 标准均衡器版本
enable_equalizer(player, 1);
set_eq_gain(player, 0, 5.0f);   // 增强低音
set_eq_gain(player, 1, 3.0f);
set_eq_gain(player, 2, -1.0f);  // 稍微削减低中音
set_eq_gain(player, 3, 0.0f);
set_eq_gain(player, 4, 0.0f);
set_eq_gain(player, 5, 1.0f);   // 突出人声
set_eq_gain(player, 6, 2.0f);
set_eq_gain(player, 7, 4.0f);   // 增强高音细节
set_eq_gain(player, 8, 5.0f);
set_eq_gain(player, 9, 4.0f);
```

### 2. 古典音乐
```c
// 样条均衡器版本（更平滑）
enable_spline_equalizer(player, 1);
set_spline_control_point(player, 0, 1.0f);   // 轻微增强低音
set_spline_control_point(player, 1, 0.5f);
set_spline_control_point(player, 2, 0.0f);
set_spline_control_point(player, 3, 0.0f);
set_spline_control_point(player, 4, 0.0f);
set_spline_control_point(player, 5, 1.0f);   // 突出中音乐器
set_spline_control_point(player, 6, 2.0f);
set_spline_control_point(player, 7, 1.5f);
set_spline_control_point(player, 8, 2.0f);   // 增强高音延伸
set_spline_control_point(player, 9, 1.0f);
```

### 3. 人声突出
```c
// 样条均衡器版本
enable_spline_equalizer(player, 1);
set_spline_control_point(player, 0, -2.0f);  // 削减低音
set_spline_control_point(player, 1, -1.0f);
set_spline_control_point(player, 2, 0.0f);
set_spline_control_point(player, 3, 1.0f);   // 增强人声基频
set_spline_control_point(player, 4, 2.0f);
set_spline_control_point(player, 5, 3.0f);   // 人声主要频段
set_spline_control_point(player, 6, 4.0f);   // 人声清晰度
set_spline_control_point(player, 7, 2.0f);
set_spline_control_point(player, 8, 1.0f);
set_spline_control_point(player, 9, 0.0f);
```

### 4. 低音增强
```c
// 标准均衡器版本
enable_equalizer(player, 1);
set_eq_gain(player, 0, 8.0f);   // 大幅增强极低音
set_eq_gain(player, 1, 6.0f);
set_eq_gain(player, 2, 4.0f);
set_eq_gain(player, 3, 2.0f);
set_eq_gain(player, 4, 0.0f);
set_eq_gain(player, 5, -1.0f);  // 稍微削减中音避免浑浊
set_eq_gain(player, 6, 0.0f);
set_eq_gain(player, 7, 0.0f);
set_eq_gain(player, 8, 1.0f);
set_eq_gain(player, 9, 0.0f);
```

## 使用建议

### 何时使用标准均衡器
- 需要快速调节特定频段
- 想要精确控制某个频率范围
- 制作特殊音效或极端调节
- 简单的音质优化需求

### 何时使用样条均衡器
- 追求更自然、平滑的音质
- 需要专业级的音频处理效果
- 制作音乐或对音质要求较高
- 希望避免频段间的突变

### 调节技巧
1. **先听后调**：在了解音乐特点后再进行调节
2. **小幅调节**：建议增益不超过±6dB，避免失真
3. **A/B对比**：经常切换均衡器开关对比效果
4. **保护听力**：长时间调节时注意音量控制

### 频率特性了解
- **20-60Hz**：极低音，影响音乐的重量感和震撼感
- **60-250Hz**：低音，贝斯、鼓声的主要频段
- **250Hz-2kHz**：中音，人声和大部分乐器的基频
- **2kHz-8kHz**：高中音，影响音乐的清晰度和穿透力
- **8kHz-20kHz**：高音，决定音乐的细节和空气感

## 注意事项

1. **互斥性**：标准均衡器和样条均衡器不能同时启用
2. **性能考虑**：样条均衡器使用更多CPU资源（31段vs10段）
3. **实时更新**：样条均衡器的控制点修改会实时应用到音频流
4. **增益限制**：所有增益值都限制在-15.0到+15.0 dB范围内
5. **音频流要求**：均衡器功能需要先加载音频文件

## 编程最佳实践

```c
// 完整的均衡器使用流程
void setup_equalizer_example() {
    void* player = create_music_player();
    
    // 1. 初始化播放器
    if (!initialize_player(player)) {
        printf("初始化失败\n");
        return;
    }
    
    // 2. 加载音频文件
    if (!load_file(player, "music.mp3")) {
        printf("加载文件失败\n");
        return;
    }
    
    // 3. 选择均衡器类型并启用
    if (PREFER_SMOOTH_SOUND) {
        enable_spline_equalizer(player, 1);
        // 设置样条控制点...
    } else {
        enable_equalizer(player, 1);
        // 设置EQ增益...
    }
    
    // 4. 开始播放
    play_music(player);
    
    // 5. 运行时调节（可选）
    // 用户界面可以实时调节增益值
    
    // 6. 清理资源
    destroy_music_player(player);
}
```

## 故障排除

### 常见问题
1. **没有声音变化**：检查是否已启用均衡器，是否已加载音频文件
2. **声音失真**：减小增益值，避免过度调节
3. **性能问题**：如果设备性能不足，考虑使用标准均衡器
4. **频率响应异常**：检查控制点设置是否合理

### 调试方法
```c
// 检查均衡器状态
if (!is_equalizer_enabled(player) && !is_spline_equalizer_enabled(player)) {
    printf("均衡器未启用\n");
}

// 获取当前设置
for (int i = 0; i < 10; i++) {
    float gain = is_spline_equalizer_enabled(player) ? 
                 get_spline_control_point(player, i) : 
                 get_eq_gain(player, i);
    printf("频段 %d: %.1f dB\n", i, gain);
}
```

这个均衡器系统为用户提供了从简单到专业的完整音频处理解决方案，满足不同层次的音质调节需求。
