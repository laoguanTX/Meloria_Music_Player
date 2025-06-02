// 文件路径: e:\VSCode\Flutter\music_player\lib\screens\player_screen.dart
// ignore_for_file: deprecated_member_use

import 'dart:ui' as ui; // 导入 ui 库用于 lerpDouble
import 'package:flutter/material.dart'; // 导入 Flutter Material 组件库
import 'package:flutter/services.dart'; // 导入系统服务库
import 'package:provider/provider.dart'; // 导入 Provider 状态管理
import 'package:window_manager/window_manager.dart'; // 导入 window_manager 用于窗口管理
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart'; // 导入可滚动定位列表
import '../providers/music_provider.dart'; // 导入音乐数据提供者
import '../models/song.dart'; // 导入歌曲模型

class PlayerScreen extends StatefulWidget {
  // 播放器界面，继承自 StatefulWidget
  const PlayerScreen({super.key}); // 构造函数

  @override
  State<PlayerScreen> createState() => _PlayerScreenState(); // 创建状态对象
}

class _PlayerScreenState extends State<PlayerScreen> with TickerProviderStateMixin, WindowListener {
  late AnimationController _progressAnimationController; // 进度动画控制器
  late Animation<double> _curvedAnimation; // 曲线动画
  double _sliderDisplayValue = 0.0; // 进度条显示值
  double _sliderTargetValue = 0.0; // 进度条目标值
  double _animationStartValueForLerp = 0.0; // 动画插值起始值
  bool _initialized = false; // 是否已初始化

  bool _isMaximized = false; // 是否最大化
  bool _isFullScreen = false; // 是否全屏
  bool _isAlwaysOnTop = false; // 是否置顶

  final ItemScrollController _lyricScrollController = ItemScrollController(); // 歌词滚动控制器
  final ItemPositionsListener _lyricPositionsListener = ItemPositionsListener.create(); // 歌词位置监听器
  int _lastLyricIndex = -1; // 上一次歌词索引
  int _hoveredIndex = -1; // 当前悬停歌词索引

  @override
  void initState() {
    super.initState();
    _progressAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300), // 动画时长
    )..addStatusListener(_handleAnimationStatus);

    _curvedAnimation = CurvedAnimation(
      parent: _progressAnimationController,
      curve: Curves.easeOut, // 使用缓动曲线
    )..addListener(_handleAnimationTick);

    windowManager.addListener(this); // 添加窗口监听
    _loadInitialWindowState(); // 加载初始窗口状态
    _lastLyricIndex = -1; // 初始化歌词索引
  }

  Future<void> _loadInitialWindowState() async {
    _isMaximized = await windowManager.isMaximized(); // 获取最大化状态
    _isFullScreen = await windowManager.isFullScreen(); // 获取全屏状态
    _isAlwaysOnTop = await windowManager.isAlwaysOnTop(); // 获取置顶状态
    if (mounted) {
      setState(() {}); // 刷新界面
    }
  }

  void _handleAnimationTick() {
    if (mounted) {
      setState(() {
        _sliderDisplayValue = ui.lerpDouble(_animationStartValueForLerp, _sliderTargetValue, _curvedAnimation.value)!; // 插值更新进度条
      });
    }
  }

  void _handleAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      if (mounted && _sliderDisplayValue != _sliderTargetValue) {
        setState(() {
          _sliderDisplayValue = _sliderTargetValue; // 动画结束时确保进度条精确
        });
      }
    } else if (status == AnimationStatus.dismissed) {
      // Optional: Handle if animation is dismissed (e.g., if controller.reverse() was used)
      // For forward-only animation, this might not be strictly necessary unless
      // there are scenarios where the animation is explicitly reversed or reset
      // leading to a dismissed state.
      if (mounted && _sliderDisplayValue != _animationStartValueForLerp && _progressAnimationController.value == 0.0) {
        // If dismissed and not at the start value (e.g. due to interruption),
        // consider snapping to _animationStartValueForLerp or _sliderTargetValue
        // depending on the desired behavior.
        // For this progress bar, completing usually means snapping to _sliderTargetValue.
      }
    }
  }

  @override
  void dispose() {
    _progressAnimationController.dispose(); // 释放动画控制器
    windowManager.removeListener(this); // 移除窗口监听
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge); // 恢复系统 UI
    super.dispose();
  }

  @override
  void onWindowMaximize() {
    if (mounted) {
      setState(() {
        _isMaximized = true; // 最大化时更新状态
      });
    }
  }

  @override
  void onWindowUnmaximize() {
    if (mounted) {
      setState(() {
        _isMaximized = false; // 取消最大化时更新状态
      });
    }
  }

  @override
  void onWindowEnterFullScreen() {
    if (mounted) {
      setState(() {
        _isFullScreen = true; // 进入全屏时更新状态
      });
    }
  }

  @override
  void onWindowLeaveFullScreen() {
    if (mounted) {
      setState(() {
        _isFullScreen = false; // 退出全屏时更新状态
      });
    }
  }
  // --- End WindowListener Overrides ---

  @override
  Widget build(BuildContext context) {
    // Hides system navigation bar - this was already here
    // SystemChrome.setEnabledSystemUIMode(
    //   SystemUiMode.manual,
    //   overlays: [SystemUiOverlay.top],
    // ); // This will be handled by CustomStatusBar or needs adjustment

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final musicProvider = Provider.of<MusicProvider>(context, listen: false);
      final showLyrics = musicProvider.currentSong?.hasLyrics ?? false;
      if (showLyrics &&
          musicProvider.lyrics.isNotEmpty &&
          musicProvider.currentLyricIndex >= 0 &&
          _lastLyricIndex != musicProvider.currentLyricIndex) {
        _lyricScrollController.scrollTo(
          index: musicProvider.currentLyricIndex,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
          alignment: 0.35,
        );
        _lastLyricIndex = musicProvider.currentLyricIndex;
      }
    });

    return Scaffold(
      appBar: PreferredSize(
        // Keep PreferredSize for consistent height
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: GestureDetector(
          // Wrap AppBar with GestureDetector for dragging
          onPanStart: (_) {
            windowManager.startDragging();
          },
          behavior: HitTestBehavior.translucent, // 允许空白区域拖动
          child: AppBar(
            backgroundColor: Colors.transparent, // 透明背景
            elevation: 0, // 无阴影
            leading: IconButton(
              // MODIFIED: Reverted Row to IconButton as only one icon remains
              icon: const Icon(Icons.expand_more), // 返回按钮
              onPressed: () => Navigator.pop(context), // 返回上一页
            ),
            title: GestureDetector(
              // GestureDetector for double tap on the title area
              onDoubleTap: () async {
                if (await windowManager.isMaximized()) {
                  windowManager.unmaximize(); // 双击还原
                } else {
                  windowManager.maximize(); // 双击最大化
                }
              },
              behavior: HitTestBehavior.opaque, // 整个区域可点击
              child: Container(
                // This container defines the tappable area
                width: double.infinity, // 填满宽度
                height: kToolbarHeight, // 匹配 AppBar 高度
                color: Colors.transparent, // 透明
              ),
            ),
            titleSpacing: 0.0, // 去除默认间距
            centerTitle: true, // 标题居中
            actions: [
              IconButton(
                // MOVED & ADDED: "More options" button
                icon: const Icon(Icons.more_vert), // 更多按钮
                onPressed: () {
                  _showPlayerOptions(context); // 显示更多选项
                },
              ),
              WindowControlButton(
                icon: _isAlwaysOnTop ? Icons.push_pin : Icons.push_pin_outlined, // 置顶图标
                tooltip: _isAlwaysOnTop ? '取消置顶' : '置顶窗口',
                onPressed: () async {
                  await windowManager.setAlwaysOnTop(!_isAlwaysOnTop); // 切换置顶
                  if (mounted) {
                    setState(() {
                      _isAlwaysOnTop = !_isAlwaysOnTop;
                    });
                  }
                },
              ),
              WindowControlButton(
                icon: Icons.minimize, // 最小化图标
                tooltip: '最小化',
                onPressed: () => windowManager.minimize(), // 最小化窗口
              ),
              WindowControlButton(
                icon: _isMaximized
                    ? Icons.filter_none // 最大化时显示还原图标
                    : Icons.crop_square, // 未最大化时显示最大化图标
                tooltip: _isMaximized ? '向下还原' : '最大化',
                onPressed: () async {
                  if (await windowManager.isMaximized()) {
                    windowManager.unmaximize();
                  } else {
                    windowManager.maximize();
                  }
                },
              ),
              WindowControlButton(
                icon: _isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen, // 全屏/退出全屏图标
                tooltip: _isFullScreen ? '退出全屏' : '全屏',
                onPressed: () async {
                  await windowManager.setFullScreen(!_isFullScreen); // 切换全屏
                  final bool newActualFullScreenState = await windowManager.isFullScreen(); // 获取最新全屏状态
                  if (mounted) {
                    if (_isFullScreen != newActualFullScreenState) {
                      setState(() {
                        _isFullScreen = newActualFullScreenState;
                      });
                    }
                  }
                },
              ),
              WindowControlButton(
                icon: Icons.close, // 关闭按钮
                tooltip: '关闭',
                onPressed: () => windowManager.close(), // 关闭窗口
                isCloseButton: true, // 关闭按钮样式
              ),
            ],
          ),
        ),
      ),
      extendBodyBehindAppBar: true, // 内容延伸到 AppBar 后面
      body: Consumer<MusicProvider>(
        builder: (context, musicProvider, child) {
          final song = musicProvider.currentSong; // 当前歌曲
          if (song == null) {
            return const Center(
              child: Text('没有正在播放的歌曲'), // 没有歌曲时显示
            );
          }

          bool showLyrics = song.hasLyrics; // 是否显示歌词

          double currentActualMillis = 0.0; // 当前播放毫秒数
          double totalMillis = musicProvider.totalDuration.inMilliseconds.toDouble(); // 总时长
          if (totalMillis <= 0) {
            totalMillis = 1.0; // 避免除零
          }
          currentActualMillis = musicProvider.currentPosition.inMilliseconds.toDouble().clamp(0.0, totalMillis); // 当前进度

          if (!_initialized) {
            _sliderDisplayValue = currentActualMillis; // 初始化进度条
            _sliderTargetValue = currentActualMillis;
            _animationStartValueForLerp = currentActualMillis;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _initialized = true;
              }
            });
          }

          if (_sliderTargetValue != currentActualMillis) {
            if (_progressAnimationController.isAnimating) {
              _progressAnimationController.stop(); // 停止动画
            }
            _animationStartValueForLerp = _sliderDisplayValue; // 设置动画起点
            _sliderTargetValue = currentActualMillis; // 设置目标值
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                if (_sliderDisplayValue != _sliderTargetValue) {
                  _progressAnimationController.forward(from: 0.0); // 启动动画
                }
              }
            });
          }

          return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Theme.of(context).colorScheme.primaryContainer,
                    Theme.of(context).colorScheme.secondaryContainer,
                  ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0), // 外边距
                child: Column(
                  children: [
                    const SizedBox(height: 80), // 顶部留白
                    Expanded(
                      child: showLyrics
                          ? Row(
                              children: [
                                Expanded(
                                  flex: 1,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: Center(
                                          child: AspectRatio(
                                            aspectRatio: 1.0 / 1.0, // 专辑封面比例
                                            child: Container(
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(20),
                                                color: Theme.of(context).colorScheme.primaryContainer,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Theme.of(context).colorScheme.shadow.withOpacity(0.3),
                                                    blurRadius: 20,
                                                    offset: const Offset(0, 8),
                                                  ),
                                                ],
                                              ),
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(20),
                                                child: song.albumArt != null
                                                    ? Image.memory(
                                                        song.albumArt!,
                                                        fit: BoxFit.cover,
                                                        width: double.infinity,
                                                        height: double.infinity,
                                                        errorBuilder: (context, error, stackTrace) {
                                                          return Icon(
                                                            Icons.music_note,
                                                            size: 120,
                                                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                                                          );
                                                        },
                                                      )
                                                    : Icon(
                                                        Icons.music_note,
                                                        size: 120,
                                                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                                                      ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 32),
                                      Expanded(
                                        flex: 1,
                                        child: Column(
                                          children: [
                                            Text(
                                              song.title, // 歌曲标题
                                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                              textAlign: TextAlign.center,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              song.artist, // 歌手
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleMedium
                                                  ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                                              textAlign: TextAlign.center,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (song.album.isNotEmpty && song.album != 'Unknown Album')
                                              Padding(
                                                padding: const EdgeInsets.only(top: 4),
                                                child: Text(
                                                  song.album, // 专辑名
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodyMedium
                                                      ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.8)),
                                                  textAlign: TextAlign.center,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Container(
                                    alignment: Alignment.center,
                                    child: musicProvider.lyrics.isEmpty || musicProvider.currentLyricIndex < 0
                                        ? const Text('Loading lyrics...ヾ(◍°∇°◍)ﾉﾞ', style: TextStyle(fontSize: 30))
                                        : NotificationListener<ScrollNotification>(
                                            onNotification: (_) => true,
                                            child: ScrollConfiguration(
                                              behavior: const ScrollBehavior().copyWith(scrollbars: false),
                                              child: ScrollablePositionedList.builder(
                                                itemScrollController: _lyricScrollController,
                                                itemPositionsListener: _lyricPositionsListener,
                                                itemCount: musicProvider.lyrics.length,
                                                itemBuilder: (context, index) {
                                                  final lyricLine = musicProvider.lyrics[index]; // 歌词行
                                                  final bool isCurrentLine = musicProvider.currentLyricIndex == index; // 是否当前行
                                                  final bool isHovered = _hoveredIndex == index; // 是否悬停

                                                  final currentStyle = TextStyle(
                                                    fontSize: 30,
                                                    fontFamily: 'MiSans-Bold',
                                                    color: Theme.of(context).colorScheme.primary,
                                                    fontWeight: FontWeight.bold,
                                                  );
                                                  final otherStyle = TextStyle(
                                                    fontSize: 24,
                                                    fontFamily: 'MiSans-Bold',
                                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                                    fontWeight: FontWeight.normal,
                                                  );

                                                  Widget lyricContent = Text(
                                                    lyricLine.text,
                                                    textAlign: TextAlign.center,
                                                  );

                                                  if (lyricLine.translatedText != null && lyricLine.translatedText!.isNotEmpty) {
                                                    lyricContent = Column(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Text(
                                                          lyricLine.text,
                                                          textAlign: TextAlign.center,
                                                          style: isCurrentLine
                                                              ? currentStyle.copyWith(fontSize: currentStyle.fontSize! * 0.8)
                                                              : otherStyle.copyWith(fontSize: otherStyle.fontSize! * 0.8),
                                                        ),
                                                        SizedBox(height: 4),
                                                        Text(
                                                          lyricLine.translatedText!,
                                                          textAlign: TextAlign.center,
                                                          style: isCurrentLine
                                                              ? currentStyle.copyWith(
                                                                  fontSize: currentStyle.fontSize! * 0.7,
                                                                  color: Theme.of(context).colorScheme.secondary)
                                                              : otherStyle.copyWith(
                                                                  fontSize: otherStyle.fontSize! * 0.7,
                                                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
                                                        ),
                                                      ],
                                                    );
                                                  } else {
                                                    lyricContent = Text(
                                                      lyricLine.text,
                                                      textAlign: TextAlign.center,
                                                    );
                                                  }

                                                  if (isHovered) {
                                                    lyricContent = Stack(
                                                      children: [
                                                        // 可在此处添加悬停时的时间显示等
                                                        Center(
                                                          child: lyricContent,
                                                        ),
                                                      ],
                                                    );
                                                  }

                                                  return InkWell(
                                                    onTap: () {
                                                      Provider.of<MusicProvider>(context, listen: false).seekTo(lyricLine.timestamp); // 点击跳转到歌词时间
                                                    },
                                                    mouseCursor: SystemMouseCursors.click, // 鼠标样式
                                                    child: MouseRegion(
                                                      onEnter: (_) {
                                                        if (mounted) {
                                                          setState(() {
                                                            _hoveredIndex = index;
                                                          });
                                                        }
                                                      },
                                                      onExit: (_) {
                                                        if (mounted) {
                                                          setState(() {
                                                            _hoveredIndex = -1;
                                                          });
                                                        }
                                                      },
                                                      child: Container(
                                                        padding: const EdgeInsets.symmetric(vertical: 15.0),
                                                        decoration: isHovered
                                                            ? BoxDecoration(
                                                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.08),
                                                                borderRadius: BorderRadius.circular(8),
                                                              )
                                                            : null,
                                                        alignment: Alignment.center,
                                                        child: AnimatedDefaultTextStyle(
                                                          duration: const Duration(milliseconds: 200),
                                                          style: isCurrentLine ? currentStyle : otherStyle,
                                                          textAlign: TextAlign.center,
                                                          child: lyricContent,
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                          ),
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Center(
                                    child: AspectRatio(
                                      aspectRatio: 1.0 / 1.0,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(20),
                                          color: Theme.of(context).colorScheme.primaryContainer,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Theme.of(context).colorScheme.shadow.withOpacity(0.3),
                                              blurRadius: 20,
                                              offset: const Offset(0, 8),
                                            ),
                                          ],
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(20),
                                          child: song.albumArt != null
                                              ? Image.memory(
                                                  song.albumArt!,
                                                  fit: BoxFit.cover,
                                                  width: double.infinity,
                                                  height: double.infinity,
                                                  errorBuilder: (context, error, stackTrace) {
                                                    return Icon(
                                                      Icons.music_note,
                                                      size: 120,
                                                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                                                    );
                                                  },
                                                )
                                              : Icon(
                                                  Icons.music_note,
                                                  size: 120,
                                                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                                                ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 32),
                                Expanded(
                                  flex: 1,
                                  child: Column(
                                    children: [
                                      Text(
                                        song.title,
                                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        song.artist,
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                                            ),
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (song.album.isNotEmpty && song.album != 'Unknown Album')
                                        Padding(
                                          padding: const EdgeInsets.only(top: 4),
                                          child: Text(
                                            song.album,
                                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                ),
                                            textAlign: TextAlign.center,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                    ),
                    // End of corrected conditional layout

                    // Progress slider 和 Volume slider 并排放置
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24), // 进度条和音量条外边距
                      child: Row(
                        children: [
                          // 播放进度条 (占据5/6的宽度)
                          Expanded(
                            flex: 5,
                            child: Column(
                              children: [
                                Slider(
                                  value: _sliderDisplayValue.clamp(0.0, totalMillis), // 进度条当前值
                                  min: 0.0,
                                  max: totalMillis,
                                  onChanged: (value) {
                                    // Stop animation if it's running
                                    if (_progressAnimationController.isAnimating) {
                                      _progressAnimationController.stop();
                                    }
                                    // Update display value immediately for responsiveness
                                    if (mounted) {
                                      setState(() {
                                        _sliderDisplayValue = value;
                                      });
                                    }
                                    // Seek to the new position
                                    musicProvider.seekTo(Duration(milliseconds: value.toInt())); // 拖动时跳转
                                    // Update the target value to prevent animation jump after user releases slider
                                    _sliderTargetValue = value; // 更新目标值
                                  },
                                  onChangeStart: (_) {
                                    if (_progressAnimationController.isAnimating) {
                                      _progressAnimationController.stop();
                                    }
                                    // When user starts dragging, update the animation start value
                                    // to the current display value to ensure smooth transition if animation was running.
                                    _animationStartValueForLerp = _sliderDisplayValue; // 拖动开始时设置动画起点
                                  },
                                  onChangeEnd: (value) {
                                    // Optional: If you want to trigger something specific when dragging ends,
                                    // like restarting an animation if it was paused for dragging.
                                    // For now, we ensure the target is set, and if not playing,
                                    // the animation will naturally resume or stay at the new _sliderTargetValue.
                                    // If musicProvider's position updates, the existing logic will handle animation.
                                  },
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _formatDuration(musicProvider.currentPosition),
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                    Text(
                                      _formatDuration(musicProvider.totalDuration),
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 16),

                          // 音量控制条 (占据1/6的宽度)
                          Expanded(
                            flex: 1,
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        musicProvider.toggleMute();
                                      },
                                      child: Icon(
                                        musicProvider.volume > 0.5
                                            ? Icons.volume_up
                                            : musicProvider.volume > 0
                                                ? Icons.volume_down
                                                : Icons.volume_off,
                                        size: 20,
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    Expanded(
                                      child: Slider(
                                        value: musicProvider.volume,
                                        min: 0.0,
                                        max: 1.0,
                                        onChanged: (value) {
                                          musicProvider.setVolume(value);
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  '${(musicProvider.volume * 100).round()}%',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Control buttons
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 150.0), // 控制按钮区横向内边距
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // New Play Mode Button
                          _buildPlayModeButton(context, musicProvider), // 播放模式按钮

                          // Previous, Play/Pause, Next buttons grouped
                          // Row(
                          //   mainAxisSize: MainAxisSize.min,
                          //   children: [
                          IconButton(
                            icon: const Icon(Icons.skip_previous),
                            iconSize: 36,
                            onPressed: musicProvider.previousSong, // 上一首
                          ),
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            child: IconButton(
                              icon: Icon(
                                musicProvider.isPlaying ? Icons.pause : Icons.play_arrow,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                              iconSize: 32,
                              onPressed: musicProvider.playPause, // 播放/暂停
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.skip_next),
                            iconSize: 36,
                            onPressed: musicProvider.nextSong, // 下一首
                          ),
                          //   ],
                          // ),

                          // const Spacer(), // Removed

                          // Placeholder for the right side, if needed in future
                          _buildDesktopLyricModeButton(
                              // MODIFIED: Renamed from _buildExclusiveAudioModeButton
                              context,
                              musicProvider),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ));
        },
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0'); // 补零
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    // The user wants "mm:ss" for hover, this handles it if hours are 0.
    // Assuming lyric timestamps are typically less than an hour.
    if (duration.inHours > 0) {
      return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
    }
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  // Helper method to build the play mode button
  Widget _buildPlayModeButton(BuildContext context, MusicProvider musicProvider) {
    IconData icon;
    String currentModeText;
    String nextModeText;

    switch (musicProvider.repeatMode) {
      case RepeatMode.singlePlay:
        icon = Icons.play_arrow; // Or a more specific icon for single play
        currentModeText = '单曲播放';
        nextModeText = '顺序播放';
        break;
      case RepeatMode.sequencePlay:
        icon = Icons.repeat;
        currentModeText = '顺序播放';
        nextModeText = '随机播放';
        break;
      case RepeatMode.randomPlay:
        icon = Icons.shuffle;
        currentModeText = '随机播放';
        nextModeText = '单曲循环';
        break;
      case RepeatMode.singleCycle:
        icon = Icons.repeat_one;
        currentModeText = '单曲循环';
        nextModeText = '单曲播放';
        break;
    }

    return GestureDetector(
      onSecondaryTapUp: (details) {
        final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
        showMenu(
          context: context,
          position: RelativeRect.fromRect(
            details.globalPosition & const Size(40, 40), // Position of the tap
            Offset.zero & overlay.size, // The area of the overlay
          ),
          items: RepeatMode.values.map((mode) {
            String modeText;
            switch (mode) {
              case RepeatMode.singlePlay:
                modeText = '单曲播放';
                break;
              case RepeatMode.sequencePlay:
                modeText = '顺序播放';
                break;
              case RepeatMode.randomPlay:
                modeText = '随机播放';
                break;
              case RepeatMode.singleCycle:
                modeText = '单曲循环';
                break;
            }
            return PopupMenuItem(
              value: mode,
              child: Text(modeText),
            );
          }).toList(),
        ).then((RepeatMode? selectedMode) {
          if (selectedMode != null) {
            musicProvider.setRepeatMode(selectedMode); // 设置播放模式
          }
        });
      },
      child: Tooltip(
        message: '当前: $currentModeText\n点击切换到: $nextModeText\n右键选择模式',
        child: IconButton(
          icon: Icon(icon),
          iconSize: 28,
          color: Theme.of(context).colorScheme.primary, // Keep it highlighted or adapt
          onPressed: musicProvider.toggleRepeatMode, // 切换播放模式
        ),
      ),
    );
  }

  // MODIFIED: Renamed from _buildExclusiveAudioModeButton and updated content
  // 新增：构建桌面歌词模式按钮的方法
  Widget _buildDesktopLyricModeButton(BuildContext context, MusicProvider musicProvider) {
    return Tooltip(
      message: musicProvider.isDesktopLyricMode ? '禁用桌面歌词' : '启用桌面歌词',
      child: IconButton(
        icon: Icon(
          musicProvider.isDesktopLyricMode
              ? Icons.lyrics // 使用不同的图标表示已启用
              : Icons.lyrics_outlined, // 默认图标
        ),
        iconSize: 28,
        color: musicProvider.isDesktopLyricMode
            ? Theme.of(context).colorScheme.primary // 启用时高亮
            : Theme.of(context).colorScheme.onSurface.withOpacity(0.6), // 禁用时普通颜色
        onPressed: () {
          musicProvider.toggleDesktopLyricMode(); // 切换桌面歌词
        },
      ),
    );
  }

  void _showPlayerOptions(BuildContext context) {
    final musicProvider = Provider.of<MusicProvider>(context, listen: false);
    final song = musicProvider.currentSong;

    showModalBottomSheet(
      context: context,
      builder: (BuildContext bc) {
        return Wrap(
          children: <Widget>[
            if (song != null)
              ListTile(
                leading: const Icon(Icons.lyrics_outlined),
                title: Text(song.hasLyrics ? '隐藏歌词' : '显示歌词'),
                onTap: () {
                  // Simplified: Assume toggling directly in provider if possible,
                  // or manage a local state here if PlayerScreen needs to react directly.
                  // For now, let's assume a direct action or a placeholder.
                  // musicProvider.toggleLyricsDisplay(); // Example, if such a method exists
                  Navigator.pop(context); // Close the bottom sheet
                  // Note: Actual lyric display toggle might be more complex
                  // and involve state changes in PlayerScreen or MusicProvider.
                },
              ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('歌曲信息'),
              onTap: () {
                Navigator.pop(context); // Close current sheet
                if (song != null) {
                  _showSongInfoDialog(context, song, musicProvider); // 显示歌曲信息
                }
              },
            ),
            // Add more options here if needed
          ],
        );
      },
    );
  }

  void _showSongInfoDialog(BuildContext context, Song song, MusicProvider musicProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('歌曲信息'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('标题', song.title),
            _buildInfoRow('艺术家', song.artist),
            _buildInfoRow('专辑', song.album),
            _buildInfoRow('时长', _formatDuration(song.duration)),
            _buildInfoRow('文件路径', song.filePath),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}

// 自定义窗口控制按钮 Widget (与 home_screen.dart 中的一致)
class WindowControlButton extends StatelessWidget {
  final IconData icon; // 图标
  final String tooltip; // 提示文本
  final VoidCallback onPressed; // 点击回调
  final bool isCloseButton; // 是否为关闭按钮

  const WindowControlButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.isCloseButton = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Color iconColor;
    if (isCloseButton) {
      iconColor = Theme.of(context).brightness == Brightness.light ? theme.colorScheme.onSurface : Colors.white;
    } else {
      iconColor = theme.colorScheme.onSurface;
    }

    return SizedBox(
      // 固定按钮大小
      width: 40,
      height: 40,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            hoverColor: isCloseButton ? Colors.red.withOpacity(0.8) : theme.colorScheme.onSurface.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4), // 轻微圆角
            child: Center(
              child: Icon(
                icon,
                size: 18, // 调整图标大小
                color: iconColor, // 使用修正后的颜色
              ),
            ),
          ),
        ),
      ),
    );
  }
}
