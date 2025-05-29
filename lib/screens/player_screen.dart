// ignore_for_file: deprecated_member_use

import 'dart:ui' as ui; // Added for lerpDouble
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

class _PlayerScreenState extends State<PlayerScreen>
    with TickerProviderStateMixin, WindowListener {
  // Added WindowListener
  late AnimationController _progressAnimationController;
  late Animation<double> _curvedAnimation; // Added for smoother animation
  double _sliderDisplayValue = 0.0; // Value shown on the slider
  double _sliderTargetValue = 0.0; // Target value from MusicProvider
  double _animationStartValueForLerp =
      0.0; // Start value for lerp interpolation
  bool _initialized = false; // To track if initial values have been set

  // Add window state variables
  bool _isMaximized = false;
  bool _isFullScreen = false;
  bool _isAlwaysOnTop = false;

  // 歌词滚动控制器
  final ItemScrollController _lyricScrollController = ItemScrollController();
  final ItemPositionsListener _lyricPositionsListener =
      ItemPositionsListener.create();
  int _lastLyricIndex = -1;
  // String? _hoveredLyricTimeString; // REMOVED: 用于存储悬停歌词的时间文本
  int _hoveredIndex = -1; // ADDED: Index of the currently hovered lyric line

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
        _sliderDisplayValue = ui.lerpDouble(
            _animationStartValueForLerp,
            _sliderTargetValue,
            _curvedAnimation.value)!; // Use curved animation value
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
      if (mounted &&
          _sliderDisplayValue != _animationStartValueForLerp &&
          _progressAnimationController.value == 0.0) {
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
    // Restore system UI if it was changed for this screen
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    // 歌词滚动控制器无需手动释放
    super.dispose();
  }

  // --- WindowListener Overrides ---
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
      // Refresh maximized state as it might change after leaving fullscreen
      windowManager.isMaximized().then((maximized) {
        if (mounted && _isMaximized != maximized) {
          setState(() {
            _isMaximized = maximized;
          });
        }
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
          behavior: HitTestBehavior
              .translucent, // Allow dragging on empty AppBar space
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
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
              behavior:
                  HitTestBehavior.opaque, // Ensure entire area is tappable
              child: Container(
                // This container defines the tappable area
                width: double.infinity, // Expand to fill available title space
                height: kToolbarHeight, // Match AppBar height
                color: Colors.transparent, // Invisible
              ),
            ),
            titleSpacing: 0.0, // Remove default spacing around the title
            centerTitle:
                true, // Center the title slot, which our GestureDetector will fill
            actions: [
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
                    ? Icons.fullscreen_exit // Icon for "restore" when maximized
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
                icon: _isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
                tooltip: _isFullScreen ? '退出全屏' : '全屏',
                onPressed: () async {
                  await windowManager.setFullScreen(!_isFullScreen);
                },
              ),
              IconButton(
                icon: const Icon(Icons.more_vert),
                onPressed: () {
                  _showPlayerOptions(context);
                },
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

          bool showLyrics = song.hasLyrics;

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
          double totalMillis =
              musicProvider.totalDuration.inMilliseconds.toDouble();
          if (totalMillis <= 0) {
            totalMillis =
                1.0; // Avoid division by zero or invalid range for Slider
          }
          currentActualMillis = musicProvider.currentPosition.inMilliseconds
              .toDouble()
              .clamp(0.0, totalMillis);

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
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primaryContainer,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .shadow
                                                        .withOpacity(
                                                            0.3), // Adjusted for clarity
                                                    blurRadius: 20,
                                                    offset: const Offset(0, 8),
                                                  ),
                                                ],
                                              ),
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                                child: song.albumArt != null
                                                    ? Image.memory(
                                                        song.albumArt!,
                                                        fit: BoxFit.cover,
                                                        width: double.infinity,
                                                        height: double.infinity,
                                                        errorBuilder: (context,
                                                            error, stackTrace) {
                                                          return Icon(
                                                            Icons.music_note,
                                                            size: 120,
                                                            color: Theme.of(
                                                                    context)
                                                                .colorScheme
                                                                .onPrimaryContainer,
                                                          );
                                                        },
                                                      )
                                                    : Icon(
                                                        Icons.music_note,
                                                        size: 120,
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .onPrimaryContainer,
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
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .headlineSmall
                                                  ?.copyWith(
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
                                                  ?.copyWith(
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .onSurfaceVariant), // Consistent color
                                              textAlign: TextAlign.center,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (song.album.isNotEmpty &&
                                                song.album != 'Unknown Album')
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 4),
                                                child: Text(
                                                  song.album,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodyMedium
                                                      ?.copyWith(
                                                          color: Theme.of(
                                                                  context)
                                                              .colorScheme
                                                              .onSurfaceVariant
                                                              .withOpacity(
                                                                  0.8)),
                                                  textAlign: TextAlign.center,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            // REMOVED: 旧的悬停歌词时间显示逻辑
                                            // if (_hoveredLyricTimeString != null)
                                            //   Padding(
                                            //     padding: const EdgeInsets.only(
                                            //         top: 8.0), // Example padding
                                            //     child: Text(
                                            //       'Hover: $_hoveredLyricTimeString', // Example display
                                            //       style: Theme.of(context)
                                            //           .textTheme
                                            //           .bodySmall,
                                            //     ),
                                            //   ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  // Right side: Lyrics Placeholder
                                  flex: 1,
                                  child: Container(
                                    alignment: Alignment.center,
                                    child: musicProvider.lyrics.isEmpty ||
                                            musicProvider.currentLyricIndex < 0
                                        ? const Text(
                                            'Loading lyrics...ヾ(◍°∇°◍)ﾉﾞ',
                                            style: TextStyle(fontSize: 30))
                                        : NotificationListener<
                                            ScrollNotification>(
                                            onNotification: (_) => true,
                                            child: ScrollConfiguration(
                                              // 添加 ScrollConfiguration 以隐藏滚动条
                                              behavior: const ScrollBehavior()
                                                  .copyWith(scrollbars: false),
                                              child: ScrollablePositionedList
                                                  .builder(
                                                itemScrollController:
                                                    _lyricScrollController,
                                                itemPositionsListener:
                                                    _lyricPositionsListener,
                                                itemCount:
                                                    musicProvider.lyrics.length,
                                                itemBuilder: (context, index) {
                                                  final lyricLine =
                                                      musicProvider
                                                          .lyrics[index];
                                                  final bool isCurrentLine =
                                                      musicProvider
                                                              .currentLyricIndex ==
                                                          index;
                                                  final bool isHovered =
                                                      _hoveredIndex == index;

                                                  final currentStyle =
                                                      TextStyle(
                                                    fontSize: 30,
                                                    fontFamily: 'MiSans-Bold',
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .primary,
                                                    fontWeight: FontWeight.bold,
                                                  );
                                                  final otherStyle = TextStyle(
                                                    fontSize: 24,
                                                    fontFamily: 'MiSans-Bold',
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSurface
                                                        .withOpacity(0.6),
                                                    fontWeight:
                                                        FontWeight.normal,
                                                  );

                                                  Widget lyricContent = Text(
                                                    lyricLine.text,
                                                    textAlign: TextAlign.center,
                                                  );
                                                  if (isHovered) {
                                                    lyricContent = Stack(
                                                      children: [
                                                        // 时间显示在最左侧
                                                        Positioned(
                                                          left: 30,
                                                          top: 0,
                                                          bottom: 0,
                                                          child: Align(
                                                            alignment: Alignment
                                                                .centerLeft,
                                                            child: Text(
                                                              _formatDuration(
                                                                  lyricLine
                                                                      .timestamp),
                                                              style: TextStyle(
                                                                fontSize: 18,
                                                                fontFamily:
                                                                    'MiSans-Bold',
                                                                color: (isCurrentLine
                                                                        ? currentStyle
                                                                            .color
                                                                        : otherStyle
                                                                            .color)
                                                                    ?.withOpacity(
                                                                        0.9),
                                                                fontWeight:
                                                                    FontWeight
                                                                        .normal,
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
                                                      Provider.of<MusicProvider>(
                                                              context,
                                                              listen: false)
                                                          .seekTo(lyricLine
                                                              .timestamp);
                                                    },
                                                    mouseCursor:
                                                        SystemMouseCursors
                                                            .click,
                                                    child: MouseRegion(
                                                      onEnter: (_) {
                                                        if (mounted) {
                                                          setState(() {
                                                            _hoveredIndex =
                                                                index;
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
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                vertical: 15.0),
                                                        decoration: isHovered
                                                            ? BoxDecoration(
                                                                color: Theme.of(
                                                                        context)
                                                                    .colorScheme
                                                                    .onSurface
                                                                    .withOpacity(
                                                                        0.08),
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            8),
                                                              )
                                                            : null,
                                                        alignment:
                                                            Alignment.center,
                                                        child:
                                                            AnimatedDefaultTextStyle(
                                                          duration:
                                                              const Duration(
                                                                  milliseconds:
                                                                      200),
                                                          style: isCurrentLine
                                                              ? currentStyle
                                                              : otherStyle,
                                                          textAlign:
                                                              TextAlign.center,
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
                              // Layout when lyrics are NOT shown (original centered layout)
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Center(
                                    child: AspectRatio(
                                      aspectRatio: 1.0 / 1.0,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primaryContainer,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .shadow
                                                  .withOpacity(
                                                      0.3), // Adjusted for clarity
                                              blurRadius: 20,
                                              offset: const Offset(0, 8),
                                            ),
                                          ],
                                        ),
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          child: song.albumArt != null
                                              ? Image.memory(
                                                  song.albumArt!,
                                                  fit: BoxFit.cover,
                                                  width: double.infinity,
                                                  height: double.infinity,
                                                  errorBuilder: (context, error,
                                                      stackTrace) {
                                                    return Icon(
                                                      Icons.music_note,
                                                      size: 120,
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .onPrimaryContainer,
                                                    );
                                                  },
                                                )
                                              : Icon(
                                                  Icons.music_note,
                                                  size: 120,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onPrimaryContainer,
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
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineSmall
                                            ?.copyWith(
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
                                            ?.copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (song.album.isNotEmpty &&
                                          song.album != 'Unknown Album')
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 4),
                                          child: Text(
                                            song.album,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.copyWith(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant,
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
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: [
                          // 播放进度条 (占据5/6的宽度)
                          Expanded(
                            flex: 5,
                            child: Column(
                              children: [
                                Slider(
                                  value: _sliderDisplayValue.clamp(
                                      0.0, totalMillis),
                                  min: 0.0,
                                  max: totalMillis,
                                  onChanged: (value) {
                                    // Stop animation if it's running
                                    if (_progressAnimationController
                                        .isAnimating) {
                                      _progressAnimationController.stop();
                                    }
                                    // Update display value immediately for responsiveness
                                    if (mounted) {
                                      setState(() {
                                        _sliderDisplayValue = value;
                                      });
                                    }
                                    // Seek to the new position
                                    musicProvider.seekTo(
                                        Duration(milliseconds: value.toInt()));
                                    // Update the target value to prevent animation jump after user releases slider
                                    _sliderTargetValue = value;
                                  },
                                  onChangeStart: (_) {
                                    if (_progressAnimationController
                                        .isAnimating) {
                                      _progressAnimationController.stop();
                                    }
                                    // When user starts dragging, update the animation start value
                                    // to the current display value to ensure smooth transition if animation was running.
                                    _animationStartValueForLerp =
                                        _sliderDisplayValue;
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
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _formatDuration(
                                          musicProvider.currentPosition),
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                    Text(
                                      _formatDuration(
                                          musicProvider.totalDuration),
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
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
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          icon: Icon(
                            musicProvider.shuffleMode
                                ? Icons.shuffle
                                : Icons.shuffle_outlined,
                          ),
                          iconSize: 28,
                          color: musicProvider.shuffleMode
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                          onPressed: musicProvider.toggleShuffle,
                        ),
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
                              musicProvider.isPlaying
                                  ? Icons.pause
                                  : Icons.play_arrow,
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
                        IconButton(
                          icon: Icon(
                            _getRepeatIcon(musicProvider.repeatMode),
                          ),
                          iconSize: 28,
                          color: musicProvider.repeatMode != RepeatMode.none
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                          onPressed: musicProvider.toggleRepeatMode,
                        ),
                      ],
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

  IconData _getRepeatIcon(RepeatMode repeatMode) {
    switch (repeatMode) {
      case RepeatMode.none:
        return Icons.repeat_outlined;
      case RepeatMode.all:
        return Icons.repeat;
      case RepeatMode.one:
        return Icons.repeat_one;
    }
  }

  void _showPlayerOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '播放器选项',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Consumer<MusicProvider>(
              builder: (context, musicProvider, child) {
                final currentSong = musicProvider.currentSong;
                if (currentSong == null) return const SizedBox.shrink();

                return Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.playlist_add),
                      title: const Text('添加到播放列表'),
                      onTap: () {
                        Navigator.pop(context);
                        _showPlaylistSelectionDialog(context, currentSong);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: const Text('歌曲信息'),
                      onTap: () {
                        Navigator.pop(context);
                        _showSongInfo(context, currentSong);
                      },
                    ),
                    ListTile(
                      leading: Icon(musicProvider.shuffleMode
                          ? Icons.shuffle
                          : Icons.shuffle_outlined),
                      title:
                          Text(musicProvider.shuffleMode ? '关闭随机播放' : '开启随机播放'),
                      onTap: () {
                        musicProvider.toggleShuffle();
                        Navigator.pop(context);
                      },
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showPlaylistSelectionDialog(BuildContext context, Song song) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加到播放列表'),
        content: Consumer<MusicProvider>(
          builder: (context, musicProvider, child) {
            if (musicProvider.playlists.isEmpty) {
              return const Text('暂无播放列表\n请先创建一个播放列表');
            }

            return SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: musicProvider.playlists.length,
                itemBuilder: (context, index) {
                  final playlist = musicProvider.playlists[index];
                  return ListTile(
                    title: Text(playlist.name),
                    subtitle: Text('${playlist.songs.length} 首歌曲'),
                    onTap: () async {
                      await musicProvider.addSongToPlaylist(playlist.id, song);
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('已添加到 "${playlist.name}"'),
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
                          ),
                        );
                      }
                    },
                  );
                },
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  void _showSongInfo(BuildContext context, Song song) {
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

// Add the WindowControlButton widget definition (copied from home_screen.dart for consistency)
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
    return SizedBox(
      width: 40,
      height: 40,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            hoverColor: isCloseButton
                ? Colors.red.withOpacity(0.8)
                : theme.colorScheme.onSurface.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
            child: Center(
              child: Icon(
                icon,
                size: 18,
                color:
                    isCloseButton ? Colors.white : theme.colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
