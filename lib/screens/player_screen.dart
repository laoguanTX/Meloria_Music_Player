// ignore_for_file: deprecated_member_use

import 'dart:ui' as ui;
import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/music_provider.dart';
import '../providers/theme_provider.dart';
import '../models/song.dart';
import '../widgets/music_waveform.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> with TickerProviderStateMixin, WindowListener {
  final FocusNode _focusNode = FocusNode();

  bool _isMaximized = false;
  bool _isFullScreen = false;
  bool _isAlwaysOnTop = false;

  final ItemScrollController _lyricScrollController = ItemScrollController();
  final ItemPositionsListener _lyricPositionsListener = ItemPositionsListener.create();
  int _lastLyricIndex = -1;
  int _hoveredIndex = -1;
  double _lyricFontSize = 1.0;

  static const String _lyricFontSizeKey = 'lyric_font_size';

  bool _lyricsVisible = true;

  bool _isMultiSelectMode = false;
  Set<int> _selectedIndices = <int>{};

  bool _isAutoScrolling = true;
  Timer? _manualScrollTimer;

  @override
  void initState() {
    super.initState();

    windowManager.addListener(this);
    _loadInitialWindowState();
    _loadLyricFontSize();

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

  @override
  void dispose() {
    windowManager.removeListener(this);
    _manualScrollTimer?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
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

  KeyEventResult _handleKeyEvent(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      final musicProvider = Provider.of<MusicProvider>(context, listen: false);

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
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  Widget _buildBackground(BuildContext context, Song? song, Widget child) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    if (song?.albumArt != null && themeProvider.playerBackgroundStyle == PlayerBackgroundStyle.albumArtFrostedGlass) {
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
    return Focus(
      focusNode: _focusNode,
      onKey: (node, event) => _handleKeyEvent(event),
      autofocus: true,
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: GestureDetector(
            onPanStart: (_) {
              windowManager.startDragging();
            },
            behavior: HitTestBehavior.translucent,
            child: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.expand_more),
                onPressed: () => Navigator.pop(context),
              ),
              title: GestureDetector(
                onDoubleTap: () async {
                  if (await windowManager.isMaximized()) {
                    windowManager.unmaximize();
                  } else {
                    windowManager.maximize();
                  }
                },
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: double.infinity,
                  height: kToolbarHeight,
                  color: Colors.transparent,
                ),
              ),
              centerTitle: true,
              actions: [
                IconButton(
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
                  onPressed: () async {
                    if (await windowManager.isFullScreen()) {
                      await windowManager.setFullScreen(!_isFullScreen);
                      _isFullScreen = !_isFullScreen;
                      await windowManager.unmaximize();
                    }
                    await windowManager.minimize();
                  },
                ),
                WindowControlButton(
                  icon: (_isMaximized || _isFullScreen) ? Icons.filter_none : Icons.crop_square,
                  tooltip: (_isMaximized || _isFullScreen) ? '向下还原' : '最大化',
                  onPressed: () async {
                    if (await windowManager.isFullScreen()) {
                      await windowManager.setFullScreen(!_isFullScreen);
                      final bool newActualFullScreenState = await windowManager.isFullScreen();
                      await windowManager.unmaximize();
                      if (mounted) {
                        if (_isFullScreen != newActualFullScreenState) {
                          setState(() {
                            _isFullScreen = newActualFullScreenState;
                            _isMaximized = false;
                          });
                        }
                      }
                    } else if (await windowManager.isMaximized()) {
                      await windowManager.unmaximize();
                    } else {
                      await windowManager.maximize();
                    }
                  },
                ),
                WindowControlButton(
                  icon: _isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
                  tooltip: _isFullScreen ? '退出全屏' : '全屏',
                  onPressed: () async {
                    await windowManager.setFullScreen(!_isFullScreen);
                    final bool newActualFullScreenState = await windowManager.isFullScreen();
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
                  icon: Icons.close,
                  tooltip: '关闭',
                  onPressed: () => windowManager.close(),
                  isCloseButton: true,
                ),
                SizedBox(width: 10),
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

            final currentLyricIndex = musicProvider.currentLyricIndex;
            if (_lastLyricIndex != currentLyricIndex &&
                _isAutoScrolling &&
                _lyricsVisible &&
                song.hasLyrics &&
                musicProvider.lyrics.isNotEmpty &&
                currentLyricIndex >= 0) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && _isAutoScrolling && _lyricsVisible) {
                  _lyricScrollController.scrollTo(
                    index: currentLyricIndex + 3,
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutCubic,
                    alignment: 0.35,
                  );
                }
              });

              _lastLyricIndex = currentLyricIndex;
            }
            double totalMillis = musicProvider.totalDuration.inMilliseconds.toDouble();
            if (totalMillis <= 0) {
              totalMillis = 1.0;
            }
            double currentMillis = musicProvider.currentPosition.inMilliseconds.toDouble().clamp(0.0, totalMillis);
            return _buildBackground(
              context,
              song,
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    const SizedBox(height: 80),
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
                                            aspectRatio: 1.0 / 1.0,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(20),
                                                color: Theme.of(context).colorScheme.primaryContainer,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Theme.of(context).colorScheme.shadow.withOpacity(0.3),
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
                                                  key: ValueKey<String>('${song.id}_art_lyrics_visible'),
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
                                      const SizedBox(height: 16),
                                      AnimatedSwitcher(
                                        duration: const Duration(milliseconds: 500),
                                        transitionBuilder: (Widget child, Animation<double> animation) {
                                          return FadeTransition(opacity: animation, child: child);
                                        },
                                        child: Column(
                                          key: ValueKey<String>('${song.id}_info_lyrics_visible'),
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
                                      const SizedBox(height: 24),
                                      Column(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 24),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    children: [
                                                      SliderTheme(
                                                        data: SliderTheme.of(context).copyWith(
                                                          activeTrackColor: Theme.of(context).colorScheme.primary,
                                                          inactiveTrackColor: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                                                          thumbColor: Theme.of(context).colorScheme.primary,
                                                          overlayColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                                                        ),
                                                        child: Slider(
                                                          value: currentMillis,
                                                          min: 0.0,
                                                          max: totalMillis,
                                                          onChanged: (value) {
                                                            musicProvider.seekTo(Duration(milliseconds: value.toInt()));
                                                          },
                                                        ),
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
                                                SizedBox(
                                                  width: 200,
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
                                                            child: SliderTheme(
                                                              data: SliderTheme.of(context).copyWith(
                                                                activeTrackColor: Theme.of(context).colorScheme.primary,
                                                                inactiveTrackColor: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                                                                thumbColor: Theme.of(context).colorScheme.primary,
                                                                overlayColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                                                              ),
                                                              child: Slider(
                                                                value: musicProvider.volume,
                                                                min: 0.0,
                                                                max: 1.0,
                                                                onChanged: (value) {
                                                                  musicProvider.setVolume(value);
                                                                },
                                                              ),
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
                                          const SizedBox(height: 24),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                              children: [
                                                Container(
                                                  width: 48,
                                                  height: 48,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: Theme.of(context).colorScheme.surfaceVariant,
                                                  ),
                                                  child: _buildPlayModeButton(context, musicProvider),
                                                ),
                                                Container(
                                                  width: 52,
                                                  height: 52,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: Theme.of(context).colorScheme.secondaryContainer,
                                                  ),
                                                  child: IconButton(
                                                    icon: const Icon(Icons.skip_previous),
                                                    iconSize: 28,
                                                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                                                    onPressed: musicProvider.previousSong,
                                                  ),
                                                ),
                                                Container(
                                                  width: 64,
                                                  height: 64,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: Theme.of(context).colorScheme.primary,
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                                                        blurRadius: 8,
                                                        offset: const Offset(0, 4),
                                                      ),
                                                    ],
                                                  ),
                                                  child: IconButton(
                                                    icon: Icon(
                                                      musicProvider.isPlaying ? Icons.pause : Icons.play_arrow,
                                                      color: Theme.of(context).colorScheme.onPrimary,
                                                    ),
                                                    iconSize: 36,
                                                    onPressed: musicProvider.playPause,
                                                  ),
                                                ),
                                                Container(
                                                  width: 52,
                                                  height: 52,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: Theme.of(context).colorScheme.secondaryContainer,
                                                  ),
                                                  child: IconButton(
                                                    icon: const Icon(Icons.skip_next),
                                                    iconSize: 28,
                                                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                                                    onPressed: musicProvider.nextSong,
                                                  ),
                                                ),
                                                Container(
                                                  width: 48,
                                                  height: 48,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: Theme.of(context).colorScheme.surfaceVariant,
                                                  ),
                                                  child: _buildPlaylistButton(context),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 24),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 32),
                                Expanded(
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
                                              _startManualScrollResetTimer();
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
                                                final musicProvider = Provider.of<MusicProvider>(context, listen: false);
                                                if (musicProvider.lyrics.isNotEmpty && musicProvider.currentLyricIndex >= 0) {
                                                  _lyricScrollController.scrollTo(
                                                    index: musicProvider.currentLyricIndex + 3,
                                                    duration: const Duration(milliseconds: 600),
                                                    curve: Curves.easeOutCubic,
                                                    alignment: 0.35,
                                                  );
                                                  _lastLyricIndex = musicProvider.currentLyricIndex;
                                                }
                                              } else {
                                                _startManualScrollResetTimer();
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
                                              _manualScrollTimer?.cancel();
                                            }
                                          },
                                          onVerticalDragEnd: (_) {
                                            if (mounted) {
                                              _startManualScrollResetTimer();
                                            }
                                          },
                                          child: ShaderMask(
                                            shaderCallback: (Rect bounds) {
                                              if (!_isAutoScrolling) {
                                                return const LinearGradient(
                                                  colors: [Colors.white, Colors.white],
                                                  stops: [0.0, 1.0],
                                                ).createShader(bounds);
                                              }
                                              return LinearGradient(
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                                colors: [
                                                  Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.0),
                                                  Theme.of(context).colorScheme.secondaryContainer.withOpacity(1.0),
                                                  Theme.of(context).colorScheme.secondaryContainer.withOpacity(1.0),
                                                  Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.0),
                                                ],
                                                stops: const [0.0, 0.2, 0.8, 1.0],
                                              ).createShader(bounds);
                                            },
                                            blendMode: BlendMode.dstIn,
                                            child: ScrollConfiguration(
                                              behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                                              child: ScrollablePositionedList.builder(
                                                itemScrollController: _lyricScrollController,
                                                itemPositionsListener: _lyricPositionsListener,
                                                itemCount: musicProvider.lyrics.length + 6, // +6 for padding
                                                itemBuilder: (context, index) {
                                                  final themeProvider = context.watch<ThemeProvider>();
                                                  if (index < 3) {
                                                    return const SizedBox(height: 60);
                                                  }
                                                  if (index >= musicProvider.lyrics.length + 3) {
                                                    return const SizedBox(height: 60);
                                                  }
                                                  final actualIndex = index - 3;
                                                  final lyricLine = musicProvider.lyrics[actualIndex];
                                                  final bool isPlaceholderLyric = lyricLine.isPlaceholder;
                                                  final bool isCurrentLine = musicProvider.currentLyricIndex == actualIndex;
                                                  final bool isHovered = _hoveredIndex == actualIndex;
                                                  final currentStyle = TextStyle(
                                                    fontSize: 30 * _lyricFontSize,
                                                    fontFamily: themeProvider.fontFamilyName,
                                                    color: Theme.of(context).colorScheme.primary,
                                                    fontWeight: FontWeight.bold,
                                                    shadows: [
                                                      Shadow(
                                                        color: Theme.of(context).colorScheme.primary.withOpacity(0.8),
                                                        blurRadius: 2.0,
                                                        offset: const Offset(0, 0),
                                                      ),
                                                      Shadow(
                                                        color: Theme.of(context).colorScheme.primary.withOpacity(0.6),
                                                        blurRadius: 5.0,
                                                        offset: const Offset(0, 0),
                                                      ),
                                                      Shadow(
                                                        color: Theme.of(context).colorScheme.primary.withOpacity(0.4),
                                                        blurRadius: 13.0,
                                                        offset: const Offset(0, 0),
                                                      ),
                                                      Shadow(
                                                        color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                                                        blurRadius: 15.0,
                                                        offset: const Offset(0, 0),
                                                      ),
                                                    ],
                                                  );
                                                  final otherStyle = TextStyle(
                                                    fontSize: 24 * _lyricFontSize,
                                                    fontFamily: themeProvider.fontFamilyName,
                                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                                    fontWeight: FontWeight.normal,
                                                  );
                                                  final placeholderCurrentStyle = currentStyle.copyWith(
                                                    fontSize: 26 * _lyricFontSize,
                                                    letterSpacing: 12,
                                                  );
                                                  final placeholderOtherStyle = otherStyle.copyWith(
                                                    letterSpacing: 12,
                                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                                                  );
                                                  Widget lyricContent;
                                                  if (isPlaceholderLyric) {
                                                    lyricContent = Text(
                                                      lyricLine.text,
                                                      textAlign: TextAlign.center,
                                                    );
                                                  } else {
                                                    List<String> lyricLines = lyricLine.text.split('\n');
                                                    if (lyricLines.length > 1) {
                                                      lyricContent = Column(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: lyricLines.asMap().entries.map((entry) {
                                                          int index = entry.key;
                                                          String line = entry.value;
                                                          TextStyle adjustedStyle;
                                                          if (isCurrentLine && index == 0) {
                                                            adjustedStyle = currentStyle;
                                                          } else if (isCurrentLine && index > 0) {
                                                            adjustedStyle = currentStyle.copyWith(
                                                              fontSize: 24 * _lyricFontSize - 4,
                                                              color: Theme.of(context).colorScheme.secondary,
                                                              shadows: [
                                                                Shadow(
                                                                  color: Theme.of(context).colorScheme.secondary.withOpacity(0.8),
                                                                  blurRadius: 1.0,
                                                                  offset: const Offset(0, 0),
                                                                ),
                                                                Shadow(
                                                                  color: Theme.of(context).colorScheme.secondary.withOpacity(0.6),
                                                                  blurRadius: 3.0,
                                                                  offset: const Offset(0, 0),
                                                                ),
                                                                Shadow(
                                                                  color: Theme.of(context).colorScheme.secondary.withOpacity(0.4),
                                                                  blurRadius: 10.0,
                                                                  offset: const Offset(0, 0),
                                                                ),
                                                              ],
                                                            );
                                                          } else {
                                                            adjustedStyle = otherStyle.copyWith(
                                                                fontSize: index == 0 ? (24 * _lyricFontSize) : (24 * _lyricFontSize - 4));
                                                          }
                                                          return AnimatedDefaultTextStyle(
                                                            duration: const Duration(milliseconds: 200),
                                                            style: adjustedStyle,
                                                            textAlign: TextAlign.center,
                                                            child: Text(
                                                              line,
                                                              textAlign: TextAlign.center,
                                                            ),
                                                          );
                                                        }).toList(),
                                                      );
                                                    } else {
                                                      lyricContent = Text(
                                                        lyricLine.text,
                                                        textAlign: TextAlign.center,
                                                      );
                                                    }
                                                  }
                                                  final distance = (actualIndex - musicProvider.currentLyricIndex).abs();
                                                  if (!isPlaceholderLyric && distance > 0 && _isAutoScrolling) {
                                                    final double blurStrength = distance * 0.8;
                                                    lyricContent = ImageFiltered(
                                                      imageFilter: ui.ImageFilter.blur(sigmaX: blurStrength, sigmaY: blurStrength),
                                                      child: lyricContent,
                                                    );
                                                  }
                                                  if (isHovered && !isPlaceholderLyric) {
                                                    lyricContent = Stack(
                                                      children: [
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
                                                        Center(
                                                          child: lyricContent,
                                                        ),
                                                      ],
                                                    );
                                                  }
                                                  return InkWell(
                                                    onTap: isPlaceholderLyric
                                                        ? null
                                                        : () {
                                                            Provider.of<MusicProvider>(context, listen: false).seekTo(lyricLine.timestamp);
                                                          },
                                                    mouseCursor: isPlaceholderLyric ? SystemMouseCursors.basic : SystemMouseCursors.click,
                                                    child: MouseRegion(
                                                      onEnter: (_) {
                                                        if (!isPlaceholderLyric && mounted) {
                                                          setState(() {
                                                            _hoveredIndex = actualIndex;
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
                                                          style: isPlaceholderLyric
                                                              ? (isCurrentLine ? placeholderCurrentStyle : placeholderOtherStyle)
                                                              : (isCurrentLine ? currentStyle : otherStyle),
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
                                        child: AnimatedSwitcher(
                                          duration: const Duration(milliseconds: 500),
                                          transitionBuilder: (Widget child, Animation<double> animation) {
                                            return FadeTransition(opacity: animation, child: child);
                                          },
                                          child: ClipRRect(
                                            key: ValueKey<String>('${song.id}_art_lyrics_hidden'),
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
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 500),
                                  transitionBuilder: (Widget child, Animation<double> animation) {
                                    return FadeTransition(opacity: animation, child: child);
                                  },
                                  child: Column(
                                    key: ValueKey<String>('${song.id}_info_lyrics_hidden'),
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
                                const SizedBox(height: 32),
                                Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 24),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              children: [
                                                SliderTheme(
                                                  data: SliderTheme.of(context).copyWith(
                                                    activeTrackColor: Theme.of(context).colorScheme.primary,
                                                    inactiveTrackColor: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                                                    thumbColor: Theme.of(context).colorScheme.primary,
                                                    overlayColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                                                  ),
                                                  child: Slider(
                                                    value: currentMillis,
                                                    min: 0.0,
                                                    max: totalMillis,
                                                    onChanged: (value) {
                                                      musicProvider.seekTo(Duration(milliseconds: value.toInt()));
                                                    },
                                                  ),
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
                                          SizedBox(
                                            width: 200,
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
                                                      child: SliderTheme(
                                                        data: SliderTheme.of(context).copyWith(
                                                          activeTrackColor: Theme.of(context).colorScheme.primary,
                                                          inactiveTrackColor: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                                                          thumbColor: Theme.of(context).colorScheme.primary,
                                                          overlayColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                                                        ),
                                                        child: Slider(
                                                          value: musicProvider.volume,
                                                          min: 0.0,
                                                          max: 1.0,
                                                          onChanged: (value) {
                                                            musicProvider.setVolume(value);
                                                          },
                                                        ),
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
                                    const SizedBox(height: 24),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                        children: [
                                          Container(
                                            width: 48,
                                            height: 48,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Theme.of(context).colorScheme.surfaceVariant,
                                            ),
                                            child: _buildPlayModeButton(context, musicProvider),
                                          ),
                                          Container(
                                            width: 52,
                                            height: 52,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Theme.of(context).colorScheme.secondaryContainer,
                                            ),
                                            child: IconButton(
                                              icon: const Icon(Icons.skip_previous),
                                              iconSize: 28,
                                              color: Theme.of(context).colorScheme.onSecondaryContainer,
                                              onPressed: musicProvider.previousSong,
                                            ),
                                          ),
                                          Container(
                                            width: 64,
                                            height: 64,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Theme.of(context).colorScheme.primary,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ],
                                            ),
                                            child: IconButton(
                                              icon: Icon(
                                                musicProvider.isPlaying ? Icons.pause : Icons.play_arrow,
                                                color: Theme.of(context).colorScheme.onPrimary,
                                              ),
                                              iconSize: 36,
                                              onPressed: musicProvider.playPause,
                                            ),
                                          ),
                                          Container(
                                            width: 52,
                                            height: 52,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Theme.of(context).colorScheme.secondaryContainer,
                                            ),
                                            child: IconButton(
                                              icon: const Icon(Icons.skip_next),
                                              iconSize: 28,
                                              color: Theme.of(context).colorScheme.onSecondaryContainer,
                                              onPressed: musicProvider.nextSong,
                                            ),
                                          ),
                                          Container(
                                            width: 48,
                                            height: 48,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Theme.of(context).colorScheme.surfaceVariant,
                                            ),
                                            child: _buildPlaylistButton(context),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),
                              ],
                            ),
                    ),
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
    if (duration.inHours > 0) {
      return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
    }
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

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

  Widget _buildPlayModeButton(BuildContext context, MusicProvider musicProvider) {
    IconData icon;
    String currentModeText;
    String nextModeText;

    switch (musicProvider.repeatMode) {
      case RepeatMode.singlePlay:
        icon = Icons.play_arrow;
        currentModeText = '单曲播放';
        nextModeText = '随机播放';
        break;
      case RepeatMode.randomPlay:
        icon = Icons.shuffle;
        currentModeText = '随机播放';
        nextModeText = '播放列表循环';
        break;
      case RepeatMode.playlistLoop:
        icon = Icons.repeat_outlined;
        currentModeText = '播放列表循环';
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
            details.globalPosition & const Size(40, 40),
            Offset.zero & overlay.size,
          ),
          items: RepeatMode.values.map((mode) {
            String modeText;
            switch (mode) {
              case RepeatMode.singlePlay:
                modeText = '单曲播放';
                break;
              case RepeatMode.randomPlay:
                modeText = '随机播放';
                break;
              case RepeatMode.playlistLoop:
                modeText = '播放列表循环';
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
          iconSize: 22,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
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
        iconSize: 22,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
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
              leading: const Icon(Icons.text_fields),
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
                Navigator.pop(context);
                if (song != null) {
                  _showSongInfoDialog(context, song, musicProvider);
                }
              },
            ),
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
        content: Consumer<MusicProvider>(
          builder: (context, mp, _) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow('标题', song.title),
                _buildInfoRow('艺术家', song.artist),
                _buildInfoRow('专辑', song.album),
                _buildInfoRow('时长', _formatDuration(song.duration)),
                _buildInfoRow('文件路径', song.filePath),
                const SizedBox(height: 12),
                Text('音频信息', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                _buildInfoRow('采样率', mp.sampleRate > 0 ? '${mp.sampleRate} Hz' : '未知'),
                _buildInfoRow('声道数', mp.channels > 0 ? '${mp.channels}' : '未知'),
                _buildInfoRow('比特率', mp.bitrateKbps > 0 ? '${mp.bitrateKbps} kbps' : '未知'),
                const SizedBox(height: 12),
                Text('电平', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                // 每 ~10 帧更新一次（约 166ms — 适用于 60fps 的情况）
                StreamBuilder<int>(
                  stream: Stream.periodic(const Duration(milliseconds: 100), (i) => i),
                  builder: (context, snapshot) {
                    // 直接读取 provider 中的值，StreamBuilder 控制刷新频率
                    final left = mp.levelLeft;
                    final right = mp.levelRight;
                    final peak = mp.peakLevel;
                    return Column(
                      children: [
                        _buildInfoRow('左声道电平', left.toStringAsFixed(3)),
                        _buildInfoRow('右声道电平', right.toStringAsFixed(3)),
                        _buildInfoRow('峰值电平', peak.toStringAsFixed(3)),
                      ],
                    );
                  },
                ),
              ],
            );
          },
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

  void _increaseFontSize() {
    setState(() {
      _lyricFontSize = (_lyricFontSize + 0.1).clamp(0.5, 2.0);
    });
    _saveLyricFontSize();
  }

  void _decreaseFontSize() {
    setState(() {
      _lyricFontSize = (_lyricFontSize - 0.1).clamp(0.5, 2.0);
    });
    _saveLyricFontSize();
  }

  Future<void> _saveLyricFontSize() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_lyricFontSizeKey, _lyricFontSize);
  }

  Future<void> _loadLyricFontSize() async {
    final prefs = await SharedPreferences.getInstance();
    final savedFontSize = prefs.getDouble(_lyricFontSizeKey);
    if (savedFontSize != null) {
      if (mounted) {
        setState(() {
          _lyricFontSize = savedFontSize.clamp(0.5, 2.0);
        });
      }
    }
  }

  void _toggleLyricsVisibility() {
    setState(() {
      _lyricsVisible = !_lyricsVisible;
      if (_lyricsVisible) {
        _isAutoScrolling = true;
        _scrollToCurrentLyric();
      }
    });
  }

  void _startManualScrollResetTimer() {
    _manualScrollTimer?.cancel();
    _manualScrollTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        final musicProvider = Provider.of<MusicProvider>(context, listen: false);
        if (!_isAutoScrolling) {
          setState(() {
            _isAutoScrolling = true;
          });
        }
        if (musicProvider.lyrics.isNotEmpty && musicProvider.currentLyricIndex >= 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _isAutoScrolling && _lyricsVisible) {
              _lyricScrollController.scrollTo(
                index: musicProvider.currentLyricIndex + 3,
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                alignment: 0.35,
              );
              _lastLyricIndex = musicProvider.currentLyricIndex;
            }
          });
        }
      }
    });
  }

  void _scrollToCurrentLyric() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _lyricsVisible) {
        final musicProvider = Provider.of<MusicProvider>(context, listen: false);
        if (musicProvider.lyrics.isNotEmpty && musicProvider.currentLyricIndex >= 0) {
          _lyricScrollController.scrollTo(
            index: musicProvider.currentLyricIndex + 3,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            alignment: 0.35,
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
        return StatefulBuilder(builder: (context, setState) {
          return Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(20),
                clipBehavior: Clip.antiAlias,
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.5,
                  height: MediaQuery.of(context).size.height - 32,
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

  Widget _buildPlaylistDrawerContent(BuildContext context, StateSetter setState) {
    return Consumer<MusicProvider>(
      builder: (context, musicProvider, child) {
        final playQueue = musicProvider.playQueue;
        final currentSong = musicProvider.currentSong;

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
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
                        Icons.playlist_play_outlined,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                      tooltip: '多选',
                      onPressed: playQueue.isNotEmpty
                          ? () {
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
                              _deleteSelectedSongs(musicProvider);
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
                      ),
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        itemCount: playQueue.length,
                        itemBuilder: (context, index) {
                          final song = playQueue[index];
                          final isCurrentSong = currentSong?.id == song.id;
                          final isPlaying = isCurrentSong && musicProvider.isPlaying;
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

              musicProvider.removeMultipleFromPlayQueue(_selectedIndices.toList());

              setState(() {
                _isMultiSelectMode = false;
                _selectedIndices.clear();
              });

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
      iconColor = Theme.of(context).brightness == Brightness.light ? theme.colorScheme.onSurface : Colors.white;
    } else {
      iconColor = theme.colorScheme.onSurface;
    }

    return SizedBox(
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
                size: 18,
                color: iconColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
