// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import '../providers/music_provider.dart';
import '../widgets/bottom_player.dart';
import './music_library_screen.dart';
import './search_screen.dart';
import './folder_screen.dart';
import './library_stats_screen.dart';
import './settings_screen.dart';
import './history_screen.dart';
import './playlist_management_screen.dart';
import './artists_screen.dart';
import './albums_screen.dart';
import '../providers/theme_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WindowListener {
  final FocusNode _focusNode = FocusNode();
  int _selectedIndex = 0;
  bool _isExtended = false;
  bool _showLabels = false;

  static const double _kExtendedWidth = 256.0;
  static const double _kCollapsedWidth = 72.0;
  final List<Widget> _pages = [
    const MusicLibrary(),
    const ArtistsScreen(),
    const AlbumsScreen(),
    const PlaylistManagementScreen(),
    const HistoryScreen(),
    const FolderTab(),
    const SearchTab(),
    const LibraryStatsScreen(),
    const SettingsScreen(),
  ];

  bool _isMaximized = false;
  bool _isFullScreen = false;
  bool _isAlwaysOnTop = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _loadInitialWindowState();
    _setWindowMinSize();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final screenWidth = MediaQuery.of(context).size.width;
        setState(() {
          _isExtended = screenWidth > 700;
          if (_isExtended) {
            _showLabels = true;
          }
        });
      }
    });
  }

  Future<void> _setWindowMinSize() async {
    await windowManager.setMinimumSize(const Size(1000, 750));
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
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final navigationRailBackgroundColor = Color.alphaBlend(
      Colors.white.withOpacity(0.03),
      theme.colorScheme.surface,
    );

    return Focus(
      focusNode: _focusNode,
      onKey: (node, event) => _handleKeyEvent(event),
      autofocus: true,
      child: Consumer<MusicProvider>(
        builder: (context, musicProvider, child) {
          final themeProvider = context.watch<ThemeProvider>();
          return Scaffold(
            appBar: PreferredSize(
              preferredSize: const Size.fromHeight(kToolbarHeight + 10),
              child: GestureDetector(
                onPanStart: (details) => windowManager.startDragging(),
                child: Container(
                  padding: const EdgeInsets.only(left: 16, right: 8, top: 6, bottom: 6),
                  color: theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface,
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onDoubleTap: () async {
                            if (await windowManager.isMaximized()) {
                              windowManager.unmaximize();
                            } else {
                              windowManager.maximize();
                            }
                          },
                          behavior: HitTestBehavior.opaque,
                          child: Row(
                            children: [
                              Image.asset(
                                'lib/asset/icon/app_icon.png',
                                width: 28,
                                height: 28,
                                errorBuilder: (context, error, stackTrace) => const SizedBox(width: 28, height: 28),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Meloria Music Player',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: theme.colorScheme.onSurface,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                            ],
                          ),
                        ),
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
                        isCloseButton: true,
                        onPressed: () => windowManager.close(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            body: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 20.0),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    width: _isExtended ? _kExtendedWidth : _kCollapsedWidth,
                    decoration: BoxDecoration(
                      color: navigationRailBackgroundColor,
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(16.0),
                        bottomRight: Radius.circular(16.0),
                      ),
                    ),
                    onEnd: () {
                      if (mounted && _isExtended) {
                        if (!_showLabels) {
                          setState(() {
                            _showLabels = true;
                          });
                        }
                      }
                    },
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(
                            top: 8.0,
                            right: 0,
                          ),
                          child: AnimatedAlign(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            alignment: _isExtended ? Alignment.centerRight : Alignment.center,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    _isExtended ? Icons.menu_open : Icons.menu,
                                    color: Theme.of(context).iconTheme.color,
                                    size: 24,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _isExtended = !_isExtended;
                                      if (!_isExtended) {
                                        _showLabels = false;
                                      }
                                    });
                                  },
                                ),
                                if (_isExtended) SizedBox(width: 10),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          child: NavigationRail(
                            backgroundColor: Colors.transparent,
                            selectedIconTheme: IconThemeData(size: 28, color: theme.colorScheme.primary),
                            unselectedIconTheme: IconThemeData(size: 28, color: theme.colorScheme.onSurface),
                            labelType: NavigationRailLabelType.none,
                            selectedLabelTextStyle:
                                TextStyle(fontSize: 16, fontFamily: themeProvider.fontFamilyName, color: theme.colorScheme.primary),
                            unselectedLabelTextStyle:
                                TextStyle(fontSize: 16, fontFamily: themeProvider.fontFamilyName, color: theme.colorScheme.onSurface),
                            selectedIndex: _selectedIndex,
                            onDestinationSelected: (index) {
                              setState(() {
                                _selectedIndex = index;
                              });
                            },
                            extended: _isExtended,
                            destinations: [
                              NavigationRailDestination(
                                icon: const Icon(Icons.music_note_outlined),
                                selectedIcon: const Icon(Icons.music_note),
                                label: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  transitionBuilder: (Widget child, Animation<double> animation) {
                                    return ScaleTransition(scale: animation, child: child);
                                  },
                                  child: _showLabels
                                      ? const Text('音乐库', key: ValueKey('label_library'))
                                      : const SizedBox.shrink(key: ValueKey('empty_library')),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                              ),
                              NavigationRailDestination(
                                icon: const Icon(Icons.person_outlined),
                                selectedIcon: const Icon(Icons.person),
                                label: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  transitionBuilder: (Widget child, Animation<double> animation) {
                                    return ScaleTransition(scale: animation, child: child);
                                  },
                                  child: _showLabels
                                      ? const Text('音乐家', key: ValueKey('label_artists'))
                                      : const SizedBox.shrink(key: ValueKey('empty_artists')),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                              ),
                              NavigationRailDestination(
                                icon: const Icon(Icons.album_outlined),
                                selectedIcon: const Icon(Icons.album),
                                label: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  transitionBuilder: (Widget child, Animation<double> animation) {
                                    return ScaleTransition(scale: animation, child: child);
                                  },
                                  child: _showLabels
                                      ? const Text('专辑', key: ValueKey('label_albums'))
                                      : const SizedBox.shrink(key: ValueKey('empty_albums')),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                              ),
                              NavigationRailDestination(
                                icon: const Icon(Icons.queue_music_outlined),
                                selectedIcon: const Icon(Icons.queue_music),
                                label: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  transitionBuilder: (Widget child, Animation<double> animation) {
                                    return ScaleTransition(scale: animation, child: child);
                                  },
                                  child: _showLabels
                                      ? const Text('歌单管理', key: ValueKey('label_playlist_management'))
                                      : const SizedBox.shrink(key: ValueKey('empty_playlist_management')),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                              ),
                              NavigationRailDestination(
                                icon: const Icon(Icons.history_outlined),
                                selectedIcon: const Icon(Icons.history),
                                label: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  transitionBuilder: (Widget child, Animation<double> animation) {
                                    return ScaleTransition(scale: animation, child: child);
                                  },
                                  child: _showLabels
                                      ? const Text('历史记录', key: ValueKey('label_history'))
                                      : const SizedBox.shrink(key: ValueKey('empty_history')),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                              ),
                              NavigationRailDestination(
                                icon: const Icon(Icons.folder_outlined),
                                selectedIcon: const Icon(Icons.folder),
                                label: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  transitionBuilder: (Widget child, Animation<double> animation) {
                                    return ScaleTransition(scale: animation, child: child);
                                  },
                                  child: _showLabels
                                      ? const Text('文件夹', key: ValueKey('label_folder'))
                                      : const SizedBox.shrink(key: ValueKey('empty_folder')),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                              ),
                              NavigationRailDestination(
                                icon: const Icon(Icons.search_outlined),
                                selectedIcon: const Icon(Icons.search),
                                label: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  transitionBuilder: (Widget child, Animation<double> animation) {
                                    return ScaleTransition(scale: animation, child: child);
                                  },
                                  child: _showLabels
                                      ? const Text('搜索', key: ValueKey('label_search'))
                                      : const SizedBox.shrink(key: ValueKey('empty_search')),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                              ),
                              NavigationRailDestination(
                                icon: const Icon(Icons.bar_chart_outlined),
                                selectedIcon: const Icon(Icons.bar_chart),
                                label: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  transitionBuilder: (Widget child, Animation<double> animation) {
                                    return ScaleTransition(scale: animation, child: child);
                                  },
                                  child: _showLabels
                                      ? const Text('统计', key: ValueKey('label_stats'))
                                      : const SizedBox.shrink(key: ValueKey('empty_stats')),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                              ),
                              NavigationRailDestination(
                                icon: const Icon(Icons.settings_outlined),
                                selectedIcon: const Icon(Icons.settings),
                                label: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  transitionBuilder: (Widget child, Animation<double> animation) {
                                    return ScaleTransition(scale: animation, child: child);
                                  },
                                  child: _showLabels
                                      ? const Text('设置', key: ValueKey('label_settings'))
                                      : const SizedBox.shrink(key: ValueKey('empty_settings')),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (Widget child, Animation<double> animation) {
                            final slideTween = Tween<Offset>(
                              begin: const Offset(0.0, 0.1),
                              end: Offset.zero,
                            );
                            return SlideTransition(
                              position: slideTween.animate(animation),
                              child: FadeTransition(
                                opacity: animation,
                                child: child,
                              ),
                            );
                          },
                          child: Container(
                            key: ValueKey<int>(_selectedIndex),
                            child: _pages[_selectedIndex],
                          ),
                        ),
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (Widget child, Animation<double> animation) {
                          final slideTween = Tween<Offset>(
                            begin: const Offset(0.0, 1.0),
                            end: Offset.zero,
                          );
                          return SlideTransition(
                            position: slideTween.animate(animation),
                            child: child,
                          );
                        },
                        child: musicProvider.currentSong != null
                            ? Padding(
                                key: const ValueKey('bottomPlayerVisible'),
                                padding: EdgeInsets.only(
                                  bottom: MediaQuery.of(context).viewPadding.bottom,
                                ),
                                child: const BottomPlayer(),
                              )
                            : const SizedBox.shrink(key: ValueKey('bottomPlayerHidden')),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
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
            borderRadius: BorderRadius.circular(4),
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
