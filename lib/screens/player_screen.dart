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
import '../providers/theme_provider.dart';
import '../models/song.dart';
import '../widgets/music_waveform.dart';

class PlayerScreen extends StatefulWidget {
  // Changed to StatefulWidget
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> with TickerProviderStateMixin, WindowListener {
  // Added WindowListener
  final FocusNode _focusNode = FocusNode();
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
  int _hoveredIndex = -1; // ADDED: Index of the currently hovered lyric line
  double _lyricFontSize = 1.0; // 字号比例因子，1.0为默认大小

  // 歌词显示控制
  bool _lyricsVisible = true; // 控制歌词是否显示

  // Playlist multi-selection state
  bool _isMultiSelectMode = false; // 控制播放列表多选模式
  Set<int> _selectedIndices = <int>{}; // 存储选中的歌曲索引

  // Lyric scrolling state
  bool _isAutoScrolling = true;
  Timer? _manualScrollTimer;
  Timer? _progressUpdateTimer;

  // 缓存变量，减少不必要的重建
  Song? _lastSong;
  PlayerState _lastPlayerState = PlayerState.stopped;
  Duration _lastPosition = Duration.zero;
  Duration _lastDuration = Duration.zero;

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

    // 使用定时器定期更新进度，减少频繁的状态监听
    _progressUpdateTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (mounted) {
        final musicProvider = context.read<MusicProvider>();
        final newPosition = musicProvider.currentPosition;
        final newDuration = musicProvider.totalDuration;
        final newSong = musicProvider.currentSong;
        final newPlayerState = musicProvider.playerState;

        bool shouldUpdate = false;

        // 检查是否需要更新UI
        if (_lastSong?.id != newSong?.id) {
          _lastSong = newSong;
          shouldUpdate = true;
        }

        if (_lastPlayerState != newPlayerState) {
          _lastPlayerState = newPlayerState;
          shouldUpdate = true;
        }

        if (_lastPosition != newPosition) {
          _lastPosition = newPosition;
          _updateProgressSlider(newPosition, newDuration);
        }

        if (_lastDuration != newDuration) {
          _lastDuration = newDuration;
          shouldUpdate = true;
        }

        if (shouldUpdate) {
          setState(() {});
        }
      }
    });
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
    _progressUpdateTimer?.cancel(); // Cancel the progress update timer
    // Restore system UI if it was changed for this screen
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    // 歌词滚动控制器无需手动释放
    _focusNode.dispose();
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

  KeyEventResult _handleKeyEvent(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      final musicProvider = Provider.of<MusicProvider>(context, listen: false);

      // Handle media keys and space bar for playback control
      if (event.logicalKey == LogicalKeyboardKey.mediaPlayPause || event.logicalKey == LogicalKeyboardKey.space) {
        musicProvider.playPause();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.mediaTrackNext) {
        musicProvider.nextSong();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.mediaTrackPrevious) {
        musicProvider.previousSong();
        return KeyEventResult.handled;
      }

      final isArrowKey = event.logicalKey == LogicalKeyboardKey.arrowLeft ||
          event.logicalKey == LogicalKeyboardKey.arrowRight ||
          event.logicalKey == LogicalKeyboardKey.arrowUp ||
          event.logicalKey == LogicalKeyboardKey.arrowDown;

      if (isArrowKey) {
        if (musicProvider.currentSong != null) {
          if (event.isControlPressed && event.logicalKey == LogicalKeyboardKey.arrowRight) {
            musicProvider.nextSong();
          } else if (event.isControlPressed && event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            musicProvider.previousSong();
          } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            final newPosition = musicProvider.currentPosition + const Duration(seconds: 5);
            musicProvider.seek(newPosition < musicProvider.totalDuration ? newPosition : musicProvider.totalDuration);
          } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            final newPosition = musicProvider.currentPosition - const Duration(seconds: 5);
            musicProvider.seek(newPosition > Duration.zero ? newPosition : Duration.zero);
          } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            musicProvider.increaseVolume();
          } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            musicProvider.decreaseVolume();
          }
        }
        // Always handle arrow keys to prevent focus traversal.
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  // 构建背景装饰
  Widget _buildBackground(BuildContext context, Song? song, Widget child) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    if (song?.albumArt != null && themeProvider.playerBackgroundStyle == PlayerBackgroundStyle.albumArtFrostedGlass) {
      // 专辑图片毛玻璃背景
      return ClipRect(
        child: Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: MemoryImage(song!.albumArt!),
              fit: BoxFit.cover,
            ),
          ),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 50, sigmaY: 50),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface.withOpacity(0.8),
              ),
              child: child,
            ),
          ),
        ),
      );
    } else {
      // 默认纯色渐变背景
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
        child: child,
      );
    }
  }

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
            // 这满足了要求："每当当前歌词发生变化时，就将歌词聚焦一次，注意，仅仅是在自动滚动状态下这样做"
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

    return Focus(
      focusNode: _focusNode,
      onKey: (node, event) => _handleKeyEvent(event),
      autofocus: true,
      child: Scaffold(
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
            return _buildBackground(
              context,
              song,
              Padding(
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
                                                      color: Theme.of(context).colorScheme.onSurface,
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
                                                  final themeProvider = context.watch<ThemeProvider>();
                                                  // 开头空白区域 (前3项)
                                                  if (index < 3) {
                                                    return const SizedBox(height: 60); // 空白区域高度
                                                  }

                                                  // 结尾空白区域 (后10项)
                                                  if (index >= musicProvider.lyrics.length + 3) {
                                                    return const SizedBox(height: 60); // 空白区域高度
                                                  }

                                                  // 实际歌词内容
                                                  final actualIndex = index - 3; // 调整索引以对应实际歌词
                                                  final lyricLine = musicProvider.lyrics[actualIndex];
                                                  final bool isCurrentLine = musicProvider.currentLyricIndex == actualIndex;
                                                  final bool isHovered = _hoveredIndex == actualIndex;
                                                  final currentStyle = TextStyle(
                                                    fontSize: 30 * _lyricFontSize,
                                                    fontFamily: themeProvider.fontFamilyName,
                                                    color: Theme.of(context).colorScheme.primary,
                                                    fontWeight: FontWeight.bold,
                                                  );
                                                  final otherStyle = TextStyle(
                                                    fontSize: 24 * _lyricFontSize,
                                                    fontFamily: themeProvider.fontFamilyName,
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
                                                                fontFamily: themeProvider.fontFamilyName,
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
                                                color: Theme.of(context).colorScheme.onSurface,
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
                              // 播放列表按钮
                              _buildPlaylistButton(context),
                              const SizedBox(width: 8),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            );
          },
        ),
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

  // Helper method to build default icon for songs without album art
  Widget _buildDefaultIcon(BuildContext context, bool isCurrentSong, bool isPlaying, int index) {
    final ThemeData theme = Theme.of(context);
    final Color iconColorOnPrimary = theme.colorScheme.onPrimary;
    final Color iconColorOnPrimaryContainer = theme.colorScheme.onPrimaryContainer;

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12.0),
        color: isCurrentSong ? theme.colorScheme.primary : theme.colorScheme.primaryContainer,
      ),
      child: Center(
        child: isCurrentSong
            ? (isPlaying
                ? MusicWaveform(
                    color: iconColorOnPrimary,
                    size: 24,
                  )
                : Icon(
                    Icons.pause,
                    size: 24,
                    color: iconColorOnPrimary,
                  ))
            : Icon(
                Icons.music_note,
                size: 20,
                color: iconColorOnPrimaryContainer,
              ),
      ),
    );
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

  Widget _buildPlaylistButton(BuildContext context) {
    return Tooltip(
      message: '打开播放列表',
      child: IconButton(
        icon: const Icon(Icons.queue_music),
        iconSize: 28,
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
        onPressed: () {
          _showPlaylistDrawer(context);
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
            if (song != null && song.hasLyrics)
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
      // 当歌词变为可见时，启用自动滚动并滚动到当前行
      if (_lyricsVisible) {
        _isAutoScrolling = true;
        _scrollToCurrentLyric(); // 滚动到当前歌词行
      }
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

  // 新增：更新进度条的方法
  void _updateProgressSlider(Duration position, Duration duration) {
    if (duration.inMilliseconds > 0) {
      final newTargetValue = position.inMilliseconds.toDouble();
      if (_sliderTargetValue != newTargetValue) {
        _sliderTargetValue = newTargetValue;
        if (!_progressAnimationController.isAnimating) {
          _animationStartValueForLerp = _sliderDisplayValue;
          _progressAnimationController.forward(from: 0.0);
        }
      }
    }
  }

  void _scrollToCurrentLyric() {
    // 使用 addPostFrameCallback 确保滚动操作在UI构建完成后执行
    // 这样可以避免在 `ScrollablePositionedList` 尚未准备好时调用 `scrollTo`
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _lyricsVisible) {
        final musicProvider = Provider.of<MusicProvider>(context, listen: false);
        if (musicProvider.lyrics.isNotEmpty && musicProvider.currentLyricIndex >= 0) {
          _lyricScrollController.scrollTo(
            index: musicProvider.currentLyricIndex + 3, // 加3是因为前面有3个空白项
            duration: const Duration(milliseconds: 600), // 增加持续时间
            curve: Curves.easeOutCubic, // 更改动画曲线
            alignment: 0.35, // 当前对齐方式，原注释：修改此处，将对齐方式改为居中
          );
          _lastLyricIndex = musicProvider.currentLyricIndex;
        }
      }
    });
  }

  void _showPlaylistDrawer(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        // 使用 StatefulBuilder 来管理抽屉内部的状态，特别是多选模式
        return StatefulBuilder(builder: (context, setState) {
          return Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.all(16.0), // 添加外边距以显示圆角
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(20), // 添加圆角
                clipBehavior: Clip.antiAlias, // 确保内容被裁剪到圆角边界内
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.5,
                  height: MediaQuery.of(context).size.height - 32, // 减去上下边距
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 20,
                        offset: const Offset(-4, 0),
                      ),
                    ],
                  ),
                  // 将 setState 传递给内容构建方法
                  child: _buildPlaylistDrawerContent(context, setState),
                ),
              ),
            ),
          );
        });
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOut,
          )),
          child: child,
        );
      },
    );
  }

  // 修改方法签名以接收 StateSetter
  Widget _buildPlaylistDrawerContent(BuildContext context, StateSetter setState) {
    return Consumer<MusicProvider>(
      builder: (context, musicProvider, child) {
        final playQueue = musicProvider.playQueue;
        final currentSong = musicProvider.currentSong;

        return Column(
          children: [
            // 头部
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ), // 只在顶部添加圆角
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.queue_music,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _isMultiSelectMode ? '已选择 ${_selectedIndices.length} 首' : '播放队列',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  if (!_isMultiSelectMode) ...[
                    Text(
                      '${playQueue.length} 首歌曲',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.8),
                          ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: Icon(
                        Icons.playlist_play_outlined, // 更合适的图标
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                      tooltip: '多选',
                      // 修复：无论是否播放，只要列表不为空就启用
                      onPressed: playQueue.isNotEmpty
                          ? () {
                              // 使用传入的 setState 来更新UI
                              setState(() {
                                _isMultiSelectMode = true;
                              });
                            }
                          : null,
                    ),
                  ],
                  if (_isMultiSelectMode) ...[
                    IconButton(
                      icon: Icon(
                        Icons.select_all,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                      tooltip: _selectedIndices.length == playQueue.length ? '取消全选' : '全选',
                      onPressed: () {
                        // 使用传入的 setState
                        setState(() {
                          if (_selectedIndices.length == playQueue.length) {
                            _selectedIndices.clear();
                          } else {
                            _selectedIndices = Set.from(List.generate(playQueue.length, (i) => i));
                          }
                        });
                      },
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                      tooltip: '删除选中',
                      onPressed: _selectedIndices.isNotEmpty
                          ? () {
                              // 删除方法内部不需要 setState，因为它会修改 Provider 的数据
                              _deleteSelectedSongs(musicProvider);
                              // 操作后退出多选模式
                              setState(() {
                                _isMultiSelectMode = false;
                              });
                            }
                          : null,
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.cancel_outlined,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                      tooltip: '取消多选',
                      onPressed: () {
                        // 使用传入的 setState
                        setState(() {
                          _isMultiSelectMode = false;
                          _selectedIndices.clear();
                        });
                      },
                    ),
                  ],
                  if (!_isMultiSelectMode)
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                ],
              ),
            ),
            // 歌曲列表
            Expanded(
              child: playQueue.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.queue_music_outlined,
                            size: 64,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '播放队列为空',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '从音乐库添加歌曲到播放队列',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                                ),
                          ),
                        ],
                      ),
                    )
                  : ClipRRect(
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                      ), // 为列表添加底部圆角
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        itemCount: playQueue.length,
                        itemBuilder: (context, index) {
                          final song = playQueue[index];
                          final isCurrentSong = currentSong?.id == song.id;
                          final isPlaying = isCurrentSong && musicProvider.isPlaying;
                          // 检查当前项是否被选中
                          final isSelected = _isMultiSelectMode && _selectedIndices.contains(index);

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            elevation: isCurrentSong ? 4 : 1,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.0),
                              side: isCurrentSong
                                  ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5)
                                  : isSelected
                                      ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)
                                      : BorderSide.none,
                            ),
                            clipBehavior: Clip.antiAlias,
                            color: isCurrentSong
                                ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.7)
                                : isSelected
                                    ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
                                    : null,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12.0),
                                onTap: () {
                                  if (_isMultiSelectMode) {
                                    setState(() {
                                      if (isSelected) {
                                        _selectedIndices.remove(index);
                                      } else {
                                        _selectedIndices.add(index);
                                      }
                                    });
                                  } else {
                                    musicProvider.playFromQueue(index);
                                  }
                                },
                                onLongPress: () {
                                  if (!_isMultiSelectMode) {
                                    setState(() {
                                      _isMultiSelectMode = true;
                                      _selectedIndices.add(index);
                                    });
                                  }
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      // 专辑图片或序号
                                      if (_isMultiSelectMode)
                                        Checkbox(
                                          value: isSelected,
                                          onChanged: (_) {
                                            setState(() {
                                              if (isSelected) {
                                                _selectedIndices.remove(index);
                                              } else {
                                                _selectedIndices.add(index);
                                              }
                                            });
                                          },
                                        )
                                      else
                                        Container(
                                          width: 48,
                                          height: 48,
                                          margin: const EdgeInsets.only(right: 12),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(12.0),
                                            color: song.albumArt == null
                                                ? (isCurrentSong
                                                    ? Theme.of(context).colorScheme.primary
                                                    : Theme.of(context).colorScheme.primaryContainer)
                                                : null,
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(12.0),
                                            child: song.albumArt != null
                                                ? Stack(
                                                    children: [
                                                      AspectRatio(
                                                        aspectRatio: 1.0,
                                                        child: Image.memory(
                                                          song.albumArt!,
                                                          fit: BoxFit.cover,
                                                          errorBuilder: (context, error, stackTrace) {
                                                            return _buildDefaultIcon(context, isCurrentSong, isPlaying, index);
                                                          },
                                                        ),
                                                      ),
                                                      // 播放时的音乐波形动画遮罩
                                                      if (isCurrentSong && isPlaying)
                                                        Positioned.fill(
                                                          child: Container(
                                                            decoration: BoxDecoration(
                                                              color: Theme.of(context).colorScheme.primary.withOpacity(0.4),
                                                              borderRadius: BorderRadius.circular(12.0),
                                                            ),
                                                            child: const MusicWaveform(
                                                              color: Colors.white,
                                                              size: 24,
                                                            ),
                                                          ),
                                                        ),
                                                      // 暂停时显示的图标
                                                      if (isCurrentSong && !isPlaying && song.albumArt != null)
                                                        Positioned.fill(
                                                          child: Container(
                                                            decoration: BoxDecoration(
                                                              color: Theme.of(context).colorScheme.primary.withOpacity(0.4),
                                                              borderRadius: BorderRadius.circular(12.0),
                                                            ),
                                                            child: const Icon(
                                                              Icons.pause,
                                                              color: Colors.white,
                                                              size: 24,
                                                            ),
                                                          ),
                                                        ),
                                                    ],
                                                  )
                                                : _buildDefaultIcon(context, isCurrentSong, isPlaying, index),
                                          ),
                                        ),
                                      // 歌曲信息
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    song.title,
                                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                          color: isCurrentSong ? Theme.of(context).colorScheme.primary : null,
                                                          fontWeight: isCurrentSong ? FontWeight.bold : null,
                                                        ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                // 显示音频格式标签
                                                if (song.filePath.toLowerCase().endsWith('.flac'))
                                                  Container(
                                                    margin: const EdgeInsets.only(left: 8),
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Colors.amber.withOpacity(0.2),
                                                      borderRadius: BorderRadius.circular(4),
                                                      border: Border.all(color: Colors.amber, width: 1),
                                                    ),
                                                    child: Text(
                                                      'FLAC',
                                                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                                            color: Colors.amber.shade700,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                    ),
                                                  ),
                                                if (song.filePath.toLowerCase().endsWith('.wav'))
                                                  Container(
                                                    margin: const EdgeInsets.only(left: 8),
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Colors.green.withOpacity(0.2),
                                                      borderRadius: BorderRadius.circular(4),
                                                      border: Border.all(color: Colors.green, width: 1),
                                                    ),
                                                    child: Text(
                                                      'WAV',
                                                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                                            color: Colors.green.shade700,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        song.artist,
                                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                            ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                      if (song.album.isNotEmpty && song.album != 'Unknown Album')
                                                        Text(
                                                          song.album,
                                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                              ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  _formatDuration(song.duration),
                                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      // 删除按钮
                                      if (!_isMultiSelectMode)
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline),
                                          iconSize: 20,
                                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                          tooltip: '从队列中删除',
                                          onPressed: () {
                                            musicProvider.removeFromPlayQueue(index);
                                          },
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  // 删除选中的歌曲
  void _deleteSelectedSongs(MusicProvider musicProvider) {
    if (_selectedIndices.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          '确认删除',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
        ),
        content: Text('确定要从播放队列中删除选中的 ${_selectedIndices.length} 首歌曲吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);

              // 使用批量删除方法
              musicProvider.removeMultipleFromPlayQueue(_selectedIndices.toList());

              // 退出多选模式
              setState(() {
                _isMultiSelectMode = false;
                _selectedIndices.clear();
              });

              // 显示删除成功提示
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('已删除 ${_selectedIndices.length} 首歌曲'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
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
