// ignore_for_file: deprecated_member_use

import 'dart:ui' as ui; // Added for lerpDouble
import 'dart:async'; // Added for Timer
import 'package:flutter/gestures.dart'; // ADDED for PointerScrollEvent
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart'; // 导入 window_manager
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../providers/music_provider.dart';
import '../models/song.dart';

class PlayerScreen extends StatefulWidget {
  // Changed to StatefulWidget
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> with TickerProviderStateMixin, WindowListener {
  // Added WindowListener
  late AnimationController _progressAnimationController;
  late Animation<double> _curvedAnimation; // Added for smoother animation
  double _sliderDisplayValue = 0.0; // Value shown on the slider
  double _sliderTargetValue = 0.0; // Target value from MusicProvider
  double _animationStartValueForLerp = 0.0; // Start value for lerp interpolation
  bool _initialized = false; // To track if initial values have been set

  // Add window state variables
  bool _isMaximized = false;
  bool _isFullScreen = false;
  bool _isAlwaysOnTop = false;

  // 歌词滚动控制器
  final ItemScrollController _lyricScrollController = ItemScrollController();
  final ItemPositionsListener _lyricPositionsListener = ItemPositionsListener.create();
  int _lastLyricIndex = -1;
  // String? _hoveredLyricTimeString; // REMOVED: 用于存储悬停歌词的时间文本
  int _hoveredIndex = -1; // ADDED: Index of the currently hovered lyric line
  // 添加字号调整相关变量
  double _lyricFontSize = 1.0; // 字号比例因子，1.0为默认大小

  // 歌词显示控制
  bool _lyricsVisible = true; // 控制歌词是否显示

  // Lyric scrolling state
  bool _isAutoScrolling = true;
  Timer? _manualScrollTimer;

  @override
  void initState() {
    super.initState();
    _progressAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300), // Adjusted duration
    )..addStatusListener(_handleAnimationStatus);

    _curvedAnimation = CurvedAnimation(
      parent: _progressAnimationController,
      curve: Curves.easeOut, // Added easing curve
    )..addListener(_handleAnimationTick);

    windowManager.addListener(this); // Add window listener
    _loadInitialWindowState(); // Load initial window state

    // 歌词滚动初始化
    _lastLyricIndex = -1;
  }

  Future<void> _loadInitialWindowState() async {
    _isMaximized = await windowManager.isMaximized();
    _isFullScreen = await windowManager.isFullScreen();
    _isAlwaysOnTop = await windowManager.isAlwaysOnTop();
    if (mounted) {
      setState(() {});
    }
  }

  void _handleAnimationTick() {
    if (mounted) {
      setState(() {
        _sliderDisplayValue = ui.lerpDouble(_animationStartValueForLerp, _sliderTargetValue, _curvedAnimation.value)!; // Use curved animation value
      });
    }
  }

  void _handleAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      if (mounted && _sliderDisplayValue != _sliderTargetValue) {
        // Ensure the display value exactly matches the target value upon completion.
        // This handles potential precision issues with lerpDouble or animation.
        setState(() {
          _sliderDisplayValue = _sliderTargetValue;
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
    _progressAnimationController.dispose();
    windowManager.removeListener(this); // Remove window listener
    _manualScrollTimer?.cancel(); // Cancel the timer on dispose
    // Restore system UI if it was changed for this screen
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    // 歌词滚动控制器无需手动释放
    super.dispose();
  }

  @override
  void onWindowMaximize() {
    if (mounted) {
      setState(() {
        _isMaximized = true;
      });
    }
  }

  @override
  void onWindowUnmaximize() {
    if (mounted) {
      setState(() {
        _isMaximized = false;
      });
    }
  }

  @override
  void onWindowEnterFullScreen() {
    if (mounted) {
      setState(() {
        _isFullScreen = true;
      });
    }
  }

  @override
  void onWindowLeaveFullScreen() {
    if (mounted) {
      setState(() {
        _isFullScreen = false;
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
      final song = musicProvider.currentSong; // 确定是否满足处理歌词的条件（歌曲存在、有歌词、歌词已加载、索引有效、歌词可见）
      final bool canProcessLyrics =
          song != null && song.hasLyrics && musicProvider.lyrics.isNotEmpty && musicProvider.currentLyricIndex >= 0 && _lyricsVisible;

      if (canProcessLyrics) {
        // 可以处理歌词，现在检查当前歌词行是否确实已更改。
        final bool lyricHasChanged = _lastLyricIndex != musicProvider.currentLyricIndex;

        if (lyricHasChanged) {
          // 当前活动的歌词行已更改。

          if (_isAutoScrolling) {
            // 自动滚动已启用。滚动到新的歌词行。
            // 这满足了要求：“每当当前歌词发生变化时，就将歌词聚焦一次，注意，仅仅是在自动滚动状态下这样做”
            _lyricScrollController.scrollTo(
              index: musicProvider.currentLyricIndex + 3, // 加3是因为前面有3个空白项
              duration: const Duration(milliseconds: 600), // 增加持续时间
              curve: Curves.easeOutCubic, // 更改动画曲线
              alignment: 0.35, // 当前对齐方式，原注释：修改此处，将对齐方式改为居中
            );
          }

          // 将 _lastLyricIndex 更新为新的当前歌词索引。
          // 这对于正确检测*下一次*更改至关重要。
          _lastLyricIndex = musicProvider.currentLyricIndex;
        }
      }
      // 如果 !canProcessLyrics（例如，没有歌曲、歌曲结束、歌词不可用），
      // _lastLyricIndex 保持不变。这通常是正确的，因为当下一个有效歌词出现时，
      // 'lyricHasChanged' 条件将正确评估。
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
          behavior: HitTestBehavior.translucent, // Allow dragging on empty AppBar space
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              // MODIFIED: Reverted Row to IconButton as only one icon remains
              icon: const Icon(Icons.expand_more),
              onPressed: () => Navigator.pop(context),
            ),
            title: GestureDetector(
              // GestureDetector for double tap on the title area
              onDoubleTap: () async {
                if (await windowManager.isMaximized()) {
                  windowManager.unmaximize();
                } else {
                  windowManager.maximize();
                }
              },
              behavior: HitTestBehavior.opaque, // Ensure entire area is tappable
              child: Container(
                // This container defines the tappable area
                width: double.infinity, // Expand to fill available title space
                height: kToolbarHeight, // Match AppBar height
                color: Colors.transparent, // Invisible
              ),
            ),
            titleSpacing: 0.0, // Remove default spacing around the title
            centerTitle: true, // Center the title slot, which our GestureDetector will fill
            actions: [
              IconButton(
                // MOVED & ADDED: "More options" button
                icon: const Icon(Icons.more_vert),
                onPressed: () {
                  _showPlayerOptions(context);
                },
              ),
              WindowControlButton(
                icon: _isAlwaysOnTop ? Icons.push_pin : Icons.push_pin_outlined,
                tooltip: _isAlwaysOnTop ? '取消置顶' : '置顶窗口',
                onPressed: () async {
                  await windowManager.setAlwaysOnTop(!_isAlwaysOnTop);
                  if (mounted) {
                    setState(() {
                      _isAlwaysOnTop = !_isAlwaysOnTop;
                    });
                  }
                },
              ),
              WindowControlButton(
                icon: Icons.minimize,
                tooltip: '最小化',
                onPressed: () => windowManager.minimize(),
              ),
              WindowControlButton(
                icon: _isMaximized
                    ? Icons.filter_none // Icon for "restore" when maximized
                    : Icons.crop_square, // Icon for "maximize"
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
                // 全屏/退出全屏按钮
                icon: _isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen, // 根据全屏状态显示不同图标
                tooltip: _isFullScreen ? '退出全屏' : '全屏', // 提示文本
                onPressed: () async {
                  // 点击事件处理
                  await windowManager.setFullScreen(!_isFullScreen); // 尝试切换全屏状态

                  // 调用 setFullScreen 后，主动获取最新的窗口全屏状态
                  final bool newActualFullScreenState = await windowManager.isFullScreen();

                  // 确保组件仍然挂载，并且如果状态与当前 _isFullScreen 不一致，则更新它
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
                // ADDED: Close button
                icon: Icons.close,
                tooltip: '关闭',
                onPressed: () => windowManager.close(),
                isCloseButton: true, // For specific styling if defined
              ),
            ],
          ),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Consumer<MusicProvider>(
        builder: (context, musicProvider, child) {
          final song = musicProvider.currentSong;
          if (song == null) {
            return const Center(
              child: Text('没有正在播放的歌曲'),
            );
          }

          bool showLyrics = song.hasLyrics && _lyricsVisible;

          // Debugging lyrics loading
          // print(
          //     'PlayerScreen: Song - ${song.title}, hasLyrics: ${song.hasLyrics}');
          if (song.hasLyrics) {
            // print('PlayerScreen: Lyrics count: ${musicProvider.lyrics.length}');
            if (musicProvider.lyrics.isNotEmpty) {
              // print('PlayerScreen: First lyric line: ${musicProvider.lyrics.first.text}');
            }
            // print(
            //     'PlayerScreen: Current lyric index: ${musicProvider.currentLyricIndex}');
          }

          // Debug info - was already here
          // print('PlayerScreen - 当前歌曲: ${song.title}');
          // print(
          //     'PlayerScreen - 专辑图片: ${song.albumArt != null ? '${song.albumArt!.length} bytes' : '无'}');

          double currentActualMillis = 0.0;
          double totalMillis = musicProvider.totalDuration.inMilliseconds.toDouble();
          if (totalMillis <= 0) {
            totalMillis = 1.0; // Avoid division by zero or invalid range for Slider
          }
          currentActualMillis = musicProvider.currentPosition.inMilliseconds.toDouble().clamp(0.0, totalMillis);

          if (!_initialized) {
            // Initialize values directly for the first build.
            // This ensures the slider starts at the correct position without animation.
            _sliderDisplayValue = currentActualMillis;
            _sliderTargetValue = currentActualMillis;
            _animationStartValueForLerp = currentActualMillis;
            // Schedule setting _initialized to true after this frame.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _initialized = true;
              }
            });
          }

          // Check if the target value needs to be updated.
          // This condition is crucial for deciding when to start a new animation.
          if (_sliderTargetValue != currentActualMillis) {
            // If an animation is already running, stop it.
            // This prevents conflicts if new updates come in quickly.
            if (_progressAnimationController.isAnimating) {
              _progressAnimationController.stop();
            }
            // Set the starting point for the new animation to the current display value.
            // This ensures a smooth transition from the current visual state.
            _animationStartValueForLerp = _sliderDisplayValue;
            // Update the target value to the new actual position.
            _sliderTargetValue = currentActualMillis;

            // Defer starting the animation to after the build phase
            // This ensures that the widget tree is stable before animation starts.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                // Double-check if an animation is still needed.
                // The state might have changed again by the time this callback executes.
                // Also, ensure we don't start animation if the display is already at the target.
                if (_sliderDisplayValue != _sliderTargetValue) {
                  _progressAnimationController.forward(from: 0.0);
                } else {
                  // If, by the time this callback runs, the display value has caught up
                  // (e.g., due to rapid user interaction or other state changes),
                  // ensure the controller is reset if it's at the end but shouldn't be.
                  // Or, if it was stopped mid-way and now matches, no action needed.
                  // This case primarily handles scenarios where target changed, then changed back
                  // or was met by other means before animation could start.
                  // If _sliderDisplayValue == _sliderTargetValue, no animation is needed.
                  // The controller's state should reflect this (e.g., not stuck at 1.0 from a previous run).
                  // If it was stopped and reset, `forward(from: 0.0)` handles it.
                  // If it completed and values match, it's fine.
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
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    const SizedBox(height: 80), // Space for app bar

                    // Corrected conditional layout for album art, song info, and lyrics
                    Expanded(
                      child: showLyrics
                          ? Row(
                              // Layout when lyrics are shown
                              children: [
                                Expanded(
                                  // Left side: Album Art and Song Info
                                  flex: 1,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
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
                                                    color: Theme.of(context).colorScheme.shadow.withOpacity(0.3), // Adjusted for clarity
                                                    blurRadius: 20,
                                                    offset: const Offset(0, 8),
                                                  ),
                                                ],
                                              ),
                                              child: AnimatedSwitcher(
                                                duration: const Duration(milliseconds: 500),
                                                transitionBuilder: (Widget child, Animation<double> animation) {
                                                  return FadeTransition(opacity: animation, child: child);
                                                },
                                                child: ClipRRect(
                                                  key: ValueKey<String>('${song.id}_art_lyrics_visible'), // Unique key
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
                                      ),
                                      const SizedBox(height: 32),
                                      Expanded(
                                        flex: 1,
                                        child: AnimatedSwitcher(
                                          duration: const Duration(milliseconds: 500),
                                          transitionBuilder: (Widget child, Animation<double> animation) {
                                            return FadeTransition(opacity: animation, child: child);
                                          },
                                          child: Column(
                                            key: ValueKey<String>('${song.id}_info_lyrics_visible'), // Unique key
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
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleMedium
                                                    ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant), // Consistent color
                                                textAlign: TextAlign.center,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              if (song.album.isNotEmpty && song.album != 'Unknown Album')
                                                Padding(
                                                  padding: const EdgeInsets.only(top: 4),
                                                  child: Text(
                                                    song.album,
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
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  // Right side: Lyrics
                                  flex: 1,
                                  child: Stack(
                                    children: [
                                      Listener(
                                        onPointerSignal: (pointerSignal) {
                                          if (pointerSignal is PointerScrollEvent) {
                                            if (mounted) {
                                              if (_isAutoScrolling) {
                                                setState(() {
                                                  _isAutoScrolling = false;
                                                });
                                              }
                                              _startManualScrollResetTimer(); // Call unified timer reset
                                            }
                                          }
                                        },
                                        child: GestureDetector(
                                          onTap: () {
                                            if (mounted) {
                                              setState(() {
                                                _isAutoScrolling = !_isAutoScrolling;
                                              });
                                              if (_isAutoScrolling) {
                                                _manualScrollTimer?.cancel();
                                                // Scroll to current lyric when toggling back to auto
                                                final musicProvider = Provider.of<MusicProvider>(context, listen: false);
                                                if (musicProvider.lyrics.isNotEmpty && musicProvider.currentLyricIndex >= 0) {
                                                  _lyricScrollController.scrollTo(
                                                    index: musicProvider.currentLyricIndex + 3,
                                                    duration: const Duration(milliseconds: 600), // 增加持续时间
                                                    curve: Curves.easeOutCubic, // 更改动画曲线
                                                    alignment: 0.35,
                                                  );
                                                  _lastLyricIndex = musicProvider.currentLyricIndex;
                                                }
                                              } else {
                                                _startManualScrollResetTimer(); // Start timer if switched to manual
                                              }
                                            }
                                          },
                                          onVerticalDragStart: (_) {
                                            if (mounted) {
                                              if (_isAutoScrolling) {
                                                setState(() {
                                                  _isAutoScrolling = false;
                                                });
                                              }
                                              _manualScrollTimer?.cancel(); // Cancel timer on drag start
                                            }
                                          },
                                          onVerticalDragEnd: (_) {
                                            if (mounted) {
                                              _startManualScrollResetTimer(); // Call unified timer reset
                                            }
                                          },
                                          child: ShaderMask(
                                            shaderCallback: (Rect bounds) {
                                              if (!_isAutoScrolling) {
                                                // When not auto-scrolling, make lyrics fully visible.
                                                // Using an opaque gradient with dstIn blendMode preserves original lyric opacity.
                                                return const LinearGradient(
                                                  colors: [Colors.white, Colors.white],
                                                  stops: [0.0, 1.0],
                                                ).createShader(bounds);
                                              }
                                              // Auto-scrolling: apply fade effect at top and bottom.
                                              return LinearGradient(
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                                colors: [
                                                  Theme.of(context)
                                                      .colorScheme
                                                      .secondaryContainer
                                                      .withOpacity(0.0), // Top edge: transparent (lyrics will fade)
                                                  Theme.of(context)
                                                      .colorScheme
                                                      .secondaryContainer
                                                      .withOpacity(1.0), // Center: opaque (lyrics fully visible)
                                                  Theme.of(context)
                                                      .colorScheme
                                                      .secondaryContainer
                                                      .withOpacity(1.0), // Center: opaque (lyrics fully visible)
                                                  Theme.of(context)
                                                      .colorScheme
                                                      .secondaryContainer
                                                      .withOpacity(0.0), // Bottom edge: transparent (lyrics will fade)
                                                ],
                                                stops: const [0.0, 0.15, 0.85, 1.0], // Adjust stops for desired fade distance
                                              ).createShader(bounds);
                                            },
                                            blendMode: BlendMode.dstIn, // Use dstIn for intuitive alpha blending
                                            child: ScrollConfiguration(
                                              behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                                              child: ScrollablePositionedList.builder(
                                                itemScrollController: _lyricScrollController,
                                                itemPositionsListener: _lyricPositionsListener,
                                                itemCount: musicProvider.lyrics.length + 6, // +6 for padding
                                                itemBuilder: (context, index) {
                                                  // 开头空白区域 (前3项)
                                                  if (index < 3) {
                                                    return SizedBox(height: 60); // 空白区域高度
                                                  }

                                                  // 结尾空白区域 (后10项)
                                                  if (index >= musicProvider.lyrics.length + 3) {
                                                    return SizedBox(height: 60); // 空白区域高度
                                                  }

                                                  // 实际歌词内容
                                                  final actualIndex = index - 3; // 调整索引以对应实际歌词
                                                  final lyricLine = musicProvider.lyrics[actualIndex];
                                                  final bool isCurrentLine = musicProvider.currentLyricIndex == actualIndex;
                                                  final bool isHovered = _hoveredIndex == actualIndex;
                                                  final currentStyle = TextStyle(
                                                    fontSize: 30 * _lyricFontSize,
                                                    fontFamily: 'MiSans-Bold',
                                                    color: Theme.of(context).colorScheme.primary,
                                                    fontWeight: FontWeight.bold,
                                                  );
                                                  final otherStyle = TextStyle(
                                                    fontSize: 24 * _lyricFontSize,
                                                    fontFamily: 'MiSans-Bold',
                                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                                    fontWeight: FontWeight.normal,
                                                  );

                                                  Widget lyricContent; // Declare lyricContent

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
                                                      // Style is applied by AnimatedDefaultTextStyle below
                                                    );
                                                  }

                                                  // Apply Gaussian blur based on distance from the current playing lyric
                                                  final distance = (actualIndex - musicProvider.currentLyricIndex).abs();
                                                  if (distance > 0 && _isAutoScrolling) {
                                                    // Only blur if not the current line
                                                    // Increase blur strength with distance
                                                    // You can adjust the multiplier (e.g., 0.5, 1.0, 1.5) to control how quickly the blur increases
                                                    final double blurStrength = distance * 0.8; // Example: blur increases by 0.8 for each line away
                                                    lyricContent = ImageFiltered(
                                                      imageFilter: ui.ImageFilter.blur(sigmaX: blurStrength, sigmaY: blurStrength),
                                                      child: lyricContent,
                                                    );
                                                  }

                                                  if (isHovered) {
                                                    lyricContent = Stack(
                                                      children: [
                                                        // 时间显示在最左侧
                                                        Positioned(
                                                          left: 30,
                                                          top: 0,
                                                          bottom: 0,
                                                          child: Align(
                                                            alignment: Alignment.centerLeft,
                                                            child: Text(
                                                              _formatDuration(lyricLine.timestamp),
                                                              style: TextStyle(
                                                                fontSize: 18,
                                                                fontFamily: 'MiSans-Bold',
                                                                color: (isCurrentLine ? currentStyle.color : otherStyle.color)?.withOpacity(0.9),
                                                                fontWeight: FontWeight.normal,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                        // 歌词文本居中显示
                                                        Center(
                                                          child: lyricContent,
                                                        ),
                                                      ],
                                                    );
                                                  }

                                                  return InkWell(
                                                    onTap: () {
                                                      Provider.of<MusicProvider>(context, listen: false).seekTo(lyricLine.timestamp);
                                                    },
                                                    mouseCursor: SystemMouseCursors.click,
                                                    child: MouseRegion(
                                                      onEnter: (_) {
                                                        if (mounted) {
                                                          setState(() {
                                                            _hoveredIndex = actualIndex; // 使用实际歌词索引
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
                                      ), // 字体大小调整按钮，位于歌词容器右下角
                                      Positioned(
                                        bottom: 16,
                                        right: 16,
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            // 增大字体按钮
                                            Container(
                                              width: 44,
                                              height: 44,
                                              margin: const EdgeInsets.only(bottom: 8),
                                              decoration: BoxDecoration(
                                                color: Theme.of(context).colorScheme.surface.withOpacity(0.2),
                                                borderRadius: BorderRadius.circular(12),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Theme.of(context).colorScheme.shadow.withOpacity(0.15),
                                                    blurRadius: 8,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ],
                                                border: Border.all(
                                                  color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                                                  width: 1,
                                                ),
                                              ),
                                              child: Material(
                                                color: Colors.transparent,
                                                child: InkWell(
                                                  borderRadius: BorderRadius.circular(12),
                                                  onTap: _increaseFontSize,
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                      borderRadius: BorderRadius.circular(12),
                                                    ),
                                                    child: Center(
                                                      child: Icon(
                                                        Icons.text_increase,
                                                        size: 20,
                                                        color: Theme.of(context).colorScheme.onSurface,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ), // 减小字体按钮
                                            Container(
                                              width: 44,
                                              height: 44,
                                              decoration: BoxDecoration(
                                                color: Theme.of(context).colorScheme.surface.withOpacity(0.2),
                                                borderRadius: BorderRadius.circular(12),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Theme.of(context).colorScheme.shadow.withOpacity(0.15),
                                                    blurRadius: 8,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ],
                                                border: Border.all(
                                                  color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                                                  width: 1,
                                                ),
                                              ),
                                              child: Material(
                                                color: Colors.transparent,
                                                child: InkWell(
                                                  borderRadius: BorderRadius.circular(12),
                                                  onTap: _decreaseFontSize,
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                      borderRadius: BorderRadius.circular(12),
                                                    ),
                                                    child: Center(
                                                      child: Icon(
                                                        Icons.text_decrease,
                                                        size: 20,
                                                        color: Theme.of(context).colorScheme.onSurface,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              // Layout when lyrics are NOT shown (original centered layout)
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
                                              color: Theme.of(context).colorScheme.shadow.withOpacity(0.3), // Adjusted for clarity
                                              blurRadius: 20,
                                              offset: const Offset(0, 8),
                                            ),
                                          ],
                                        ),
                                        child: AnimatedSwitcher(
                                          duration: const Duration(milliseconds: 500),
                                          transitionBuilder: (Widget child, Animation<double> animation) {
                                            return FadeTransition(opacity: animation, child: child);
                                          },
                                          child: ClipRRect(
                                            key: ValueKey<String>('${song.id}_art_lyrics_hidden'), // Unique key
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
                                ),
                                const SizedBox(height: 32),
                                Expanded(
                                  flex: 1,
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 500),
                                    transitionBuilder: (Widget child, Animation<double> animation) {
                                      return FadeTransition(opacity: animation, child: child);
                                    },
                                    child: Column(
                                      key: ValueKey<String>('${song.id}_info_lyrics_hidden'), // Unique key
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
                                ),
                              ],
                            ),
                    ),
                    // End of corrected conditional layout

                    // Progress slider 和 Volume slider 并排放置
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: [
                          // 播放进度条 (占据5/6的宽度)
                          Expanded(
                            flex: 5,
                            child: Column(
                              children: [
                                Slider(
                                  value: _sliderDisplayValue.clamp(0.0, totalMillis),
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
                                    musicProvider.seekTo(Duration(milliseconds: value.toInt()));
                                    // Update the target value to prevent animation jump after user releases slider
                                    _sliderTargetValue = value;
                                  },
                                  onChangeStart: (_) {
                                    if (_progressAnimationController.isAnimating) {
                                      _progressAnimationController.stop();
                                    }
                                    // When user starts dragging, update the animation start value
                                    // to the current display value to ensure smooth transition if animation was running.
                                    _animationStartValueForLerp = _sliderDisplayValue;
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
                      padding: const EdgeInsets.symmetric(horizontal: 150.0), // Add horizontal padding
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween, // Changed to spaceBetween
                        children: [
                          // New Play Mode Button
                          _buildPlayModeButton(context, musicProvider),

                          // Previous, Play/Pause, Next buttons grouped
                          // Row(
                          //   mainAxisSize: MainAxisSize.min,
                          //   children: [
                          IconButton(
                            icon: const Icon(Icons.skip_previous),
                            iconSize: 36,
                            onPressed: musicProvider.previousSong,
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
                              onPressed: musicProvider.playPause,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.skip_next),
                            iconSize: 36,
                            onPressed: musicProvider.nextSong,
                          ),
                          //   ],
                          // ),

                          // const Spacer(), // Removed                          // Placeholder for the right side, if needed in future
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // 歌词显示切换按钮
                              _buildLyricsToggleButton(context, song),
                              const SizedBox(width: 8),
                              // 桌面歌词模式按钮
                              _buildDesktopLyricModeButton(context, musicProvider),
                            ],
                          ),
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
    String twoDigits(int n) => n.toString().padLeft(2, '0');
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
            musicProvider.setRepeatMode(selectedMode);
          }
        });
      },
      child: Tooltip(
        message: '当前: $currentModeText\n点击切换到: $nextModeText\n右键选择模式',
        child: IconButton(
          icon: Icon(icon),
          iconSize: 28,
          color: Theme.of(context).colorScheme.primary, // Keep it highlighted or adapt
          onPressed: musicProvider.toggleRepeatMode,
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
          musicProvider.toggleDesktopLyricMode(); // MODIFIED: Renamed from toggleExclusiveAudioMode
        },
      ),
    );
  }

  Widget _buildLyricsToggleButton(BuildContext context, Song song) {
    // 只有当歌曲有歌词时才显示此按钮
    if (!song.hasLyrics) {
      return const SizedBox.shrink();
    }

    return Tooltip(
      message: _lyricsVisible ? '隐藏歌词' : '显示歌词',
      child: IconButton(
        icon: Icon(
          _lyricsVisible ? Icons.visibility : Icons.visibility_off,
        ),
        iconSize: 28,
        color: _lyricsVisible ? Theme.of(context).colorScheme.onSurface.withOpacity(0.6) : Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
        onPressed: _toggleLyricsVisibility,
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
                title: Text(_lyricsVisible ? '隐藏歌词' : '显示歌词'),
                onTap: () {
                  Navigator.pop(context);
                  _toggleLyricsVisibility();
                },
              ),
            ListTile(
              leading: const Icon(Icons.format_size),
              title: const Text('增大歌词字号'),
              onTap: () {
                Navigator.pop(context);
                _increaseFontSize();
              },
            ),
            ListTile(
              leading: const Icon(Icons.text_fields), // Using a different icon for decrease
              title: const Text('减小歌词字号'),
              onTap: () {
                Navigator.pop(context);
                _decreaseFontSize();
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('歌曲信息'),
              onTap: () {
                Navigator.pop(context); // Close current sheet
                if (song != null) {
                  _showSongInfoDialog(context, song, musicProvider);
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

  // 添加字号调整方法
  void _increaseFontSize() {
    setState(() {
      _lyricFontSize = (_lyricFontSize + 0.1).clamp(0.5, 2.0); // 限制最小0.5，最大2.0
    });
  }

  void _decreaseFontSize() {
    setState(() {
      _lyricFontSize = (_lyricFontSize - 0.1).clamp(0.5, 2.0); // 限制最小0.5，最大2.0
    });
  }

  // 切换歌词显示状态
  void _toggleLyricsVisibility() {
    setState(() {
      _lyricsVisible = !_lyricsVisible;
    });
  }

  void _startManualScrollResetTimer() {
    _manualScrollTimer?.cancel();
    _manualScrollTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        // 移除了 !_isAutoScrolling 的检查，因为我们希望在计时器触发时强制重置
        final musicProvider = Provider.of<MusicProvider>(context, listen: false);
        // 确保在执行滚动前 _isAutoScrolling 已为 true
        if (!_isAutoScrolling) {
          setState(() {
            _isAutoScrolling = true;
          });
        } // After switching back to auto-scrolling, scroll to the current lyric
        if (musicProvider.lyrics.isNotEmpty && musicProvider.currentLyricIndex >= 0) {
          // 使用 WidgetsBinding.instance.addPostFrameCallback 确保滚动在下一帧执行
          // 这有助于避免在状态更新期间执行滚动操作可能引发的问题
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _isAutoScrolling && _lyricsVisible) {
              // 再次检查 mounted, _isAutoScrolling 和 _lyricsVisible
              _lyricScrollController.scrollTo(
                index: musicProvider.currentLyricIndex + 3,
                duration: const Duration(milliseconds: 600), // 增加持续时间
                curve: Curves.easeOutCubic, // 更改动画曲线
                alignment: 0.35,
              );
              _lastLyricIndex = musicProvider.currentLyricIndex;
            }
          });
        }
      }
    });
  }
}

// 自定义窗口控制按钮 Widget (与 home_screen.dart 中的一致)
class WindowControlButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool isCloseButton;

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
      // For the close button:
      // - In light mode, use a dark icon (onSurface color).
      // - In dark mode, use a white icon for better contrast with typical red hover.
      iconColor = Theme.of(context).brightness == Brightness.light ? theme.colorScheme.onSurface : Colors.white;
    } else {
      // For other buttons, use the onSurface color which adapts to the theme.
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
