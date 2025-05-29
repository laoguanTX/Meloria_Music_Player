// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart'; // 导入 window_manager
import '../providers/music_provider.dart';
import '../widgets/bottom_player.dart';
import '../widgets/music_library.dart';
import '../widgets/playlists_tab.dart';
import '../widgets/search_tab.dart';
import '../widgets/folder_tab.dart';
import './library_stats_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WindowListener {
  // 添加 WindowListener
  int _selectedIndex = 0;
  bool _isExtended = false;
  bool _showLabels = false;

  static const double _kExtendedWidth = 256.0;
  static const double _kCollapsedWidth = 72.0;

  final List<Widget> _pages = [
    const MusicLibrary(),
    const PlaylistsTab(),
    const FolderTab(),
    const LibraryStatsScreen(),
    const SearchTab(),
  ];

  bool _isMaximized = false;
  bool _isFullScreen = false;
  bool _isAlwaysOnTop = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this); // 添加监听器
    _loadInitialWindowState(); // 加载初始窗口状态

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
    windowManager.removeListener(this); // 移除监听器
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
      // Update _isFullScreen immediately for responsive UI of the fullscreen button.
      setState(() {
        _isFullScreen = false;
      });
      // After exiting fullscreen, the window's maximized state might have changed.
      // Query it directly from the windowManager to ensure _isMaximized is accurate.
      windowManager.isMaximized().then((maximized) {
        if (mounted) {
          // Check if the state needs updating to avoid unnecessary setState calls.
          if (_isMaximized != maximized) {
            setState(() {
              _isMaximized = maximized;
            });
          }
        }
      }).catchError((e) {
        // Log potential errors during state fetching.
        // In a real app, you might want more sophisticated error handling.
        // print('Error updating maximized state after leaving fullscreen: $e');
      });
    }
  }
  // --- End WindowListener Overrides ---

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final navigationRailBackgroundColor = Color.alphaBlend(
      Colors.white.withOpacity(0.03),
      theme.colorScheme.surface,
    );

    return Consumer<MusicProvider>(
      builder: (context, musicProvider, child) {
        return Scaffold(
          // 使用自定义的 AppBar
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(
                kToolbarHeight + 10), // 调整 AppBar 高度以适应拖动区域和内容
            child: GestureDetector(
              // Outer GestureDetector for dragging
              onPanStart: (details) => windowManager.startDragging(),
              // onDoubleTap removed from here
              child: Container(
                padding: const EdgeInsets.only(
                    left: 16, right: 8, top: 6, bottom: 6), // 调整内边距
                color: theme.appBarTheme.backgroundColor ??
                    theme.colorScheme.surface,
                child: Row(
                  children: [
                    Expanded(
                      // Wrap the tappable area to the left of buttons
                      child: GestureDetector(
                        // Inner GestureDetector for double-tap
                        onDoubleTap: () async {
                          if (await windowManager.isMaximized()) {
                            windowManager.unmaximize();
                          } else {
                            windowManager.maximize();
                          }
                        },
                        behavior: HitTestBehavior
                            .opaque, // Ensure entire area is tappable
                        child: Row(
                          // Row to align text to the left within tappable area
                          children: [
                            Text(
                              'Music Player',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(), // Spacer to make the GestureDetector expand
                          ],
                        ),
                      ),
                    ),
                    // 窗口控制按钮
                    WindowControlButton(
                      icon: _isAlwaysOnTop
                          ? Icons.push_pin
                          : Icons.push_pin_outlined,
                      tooltip: _isAlwaysOnTop ? '取消置顶' : '置顶窗口',
                      onPressed: () async {
                        await windowManager.setAlwaysOnTop(!_isAlwaysOnTop);
                        setState(() {
                          _isAlwaysOnTop = !_isAlwaysOnTop;
                        });
                      },
                    ),
                    WindowControlButton(
                      icon: Icons.minimize,
                      tooltip: '最小化',
                      onPressed: () => windowManager.minimize(),
                    ),
                    WindowControlButton(
                      icon: _isMaximized
                          ? Icons.fullscreen_exit
                          : Icons.crop_square, // 根据状态切换图标
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
                      icon: _isFullScreen
                          ? Icons.fullscreen_exit
                          : Icons.fullscreen,
                      tooltip: _isFullScreen ? '退出全屏' : '全屏',
                      onPressed: () async {
                        await windowManager.setFullScreen(!_isFullScreen);
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
              // 左侧导航栏
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                width: _isExtended ? _kExtendedWidth : _kCollapsedWidth,
                decoration: BoxDecoration(
                  color: navigationRailBackgroundColor,
                  borderRadius: const BorderRadius.only(
                    // 添加圆角
                    topRight: Radius.circular(16.0),
                    bottomRight: Radius.circular(16.0),
                  ),
                ),
                child: Column(
                  children: [
                    // 展开/收起按钮
                    Padding(
                      padding: const EdgeInsets.only(
                        top: 8.0,
                        right: 0, // 固定右边距 (72-48)/2 = 12
                      ),
                      child: AnimatedAlign(
                        duration: const Duration(milliseconds: 300), // 动画时长
                        curve: Curves.easeInOut, // 动画曲线
                        alignment: _isExtended
                            ? Alignment.centerRight // 展开时，按钮在除去右边距后的空间内靠右
                            : Alignment.center, // 收起时，按钮在总宽度72内居中
                        child: IconButton(
                          icon: Icon(
                            _isExtended ? Icons.menu_open : Icons.menu,
                            color: Theme.of(context).iconTheme.color,
                            size: 24, // Matching other icon sizes
                          ),
                          onPressed: () {
                            setState(() {
                              _isExtended = !_isExtended;
                              if (!_isExtended) {
                                _showLabels =
                                    false; // Hide labels immediately on collapse
                              }
                            });
                          },
                        ),
                      ),
                    ),
                    Expanded(
                      child: AnimatedContainer(
                        width: _isExtended ? _kExtendedWidth : _kCollapsedWidth,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        onEnd: () {
                          // Added onEnd callback
                          if (_isExtended) {
                            setState(() {
                              _showLabels =
                                  true; // Show labels after expansion animation
                            });
                          }
                        },
                        child: NavigationRail(
                          backgroundColor:
                              Colors.transparent, // 设置为透明，因为父Container会处理背景色
                          selectedIconTheme: IconThemeData(
                              size: 28, color: theme.colorScheme.primary),
                          unselectedIconTheme: IconThemeData(
                              size: 28, color: theme.colorScheme.onSurface),
                          labelType: NavigationRailLabelType.none,
                          selectedLabelTextStyle: TextStyle(
                              fontSize: 16,
                              fontFamily: 'MiSans-Bold',
                              color: theme.colorScheme.primary),
                          unselectedLabelTextStyle: TextStyle(
                              fontSize: 16,
                              fontFamily: 'MiSans-Bold',
                              color: theme.colorScheme.onSurface),
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
                                transitionBuilder: (Widget child,
                                    Animation<double> animation) {
                                  return ScaleTransition(
                                    scale: animation,
                                    child: child,
                                  );
                                },
                                child: _showLabels
                                    ? const Text(
                                        '音乐库',
                                        key: ValueKey('label_library'),
                                      )
                                    : const SizedBox.shrink(
                                        key: ValueKey('empty_library'),
                                      ),
                              ),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8.0),
                            ),
                            NavigationRailDestination(
                              icon: const Icon(Icons.playlist_play_outlined),
                              selectedIcon: const Icon(Icons.playlist_play),
                              label: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                transitionBuilder: (Widget child,
                                    Animation<double> animation) {
                                  return ScaleTransition(
                                    scale: animation,
                                    child: child,
                                  );
                                },
                                child: _showLabels
                                    ? const Text(
                                        '播放列表',
                                        key: ValueKey('label_playlists'),
                                      )
                                    : const SizedBox.shrink(
                                        key: ValueKey('empty_playlists'),
                                      ),
                              ),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8.0),
                            ),
                            NavigationRailDestination(
                              icon: const Icon(Icons.folder_outlined),
                              selectedIcon: const Icon(Icons.folder),
                              label: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                transitionBuilder: (Widget child,
                                    Animation<double> animation) {
                                  return ScaleTransition(
                                    scale: animation,
                                    child: child,
                                  );
                                },
                                child: _showLabels
                                    ? const Text(
                                        '文件夹',
                                        key: ValueKey('label_folder'),
                                      )
                                    : const SizedBox.shrink(
                                        key: ValueKey('empty_folder'),
                                      ),
                              ),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8.0),
                            ),
                            NavigationRailDestination(
                              icon: const Icon(Icons.bar_chart_outlined),
                              selectedIcon: const Icon(Icons.bar_chart),
                              label: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                transitionBuilder: (Widget child,
                                    Animation<double> animation) {
                                  return ScaleTransition(
                                    scale: animation,
                                    child: child,
                                  );
                                },
                                child: _showLabels
                                    ? const Text(
                                        '统计',
                                        key: ValueKey('label_stats'),
                                      )
                                    : const SizedBox.shrink(
                                        key: ValueKey('empty_stats'),
                                      ),
                              ),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8.0),
                            ),
                            NavigationRailDestination(
                              icon: const Icon(Icons.search_outlined),
                              selectedIcon: const Icon(Icons.search),
                              label: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                transitionBuilder: (Widget child,
                                    Animation<double> animation) {
                                  return ScaleTransition(
                                    scale: animation,
                                    child: child,
                                  );
                                },
                                child: _showLabels
                                    ? const Text(
                                        '搜索',
                                        key: ValueKey('label_search'),
                                      )
                                    : const SizedBox.shrink(
                                        key: ValueKey('empty_search'),
                                      ),
                              ),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8.0),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_isExtended) const Divider(height: 1),
                    // 在侧边栏底部始终显示音乐库统计
                    // LibraryStatsInSidebar(
                    //     isExtended: _isExtended), // Pass _isExtended
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: _pages[_selectedIndex],
                    ),
                    if (musicProvider.currentSong != null)
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: MediaQuery.of(context).viewPadding.bottom,
                        ),
                        child: const BottomPlayer(),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// 自定义窗口控制按钮 Widget
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
      // 固定按钮大小
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
            borderRadius: BorderRadius.circular(4), // 轻微圆角
            child: Center(
              child: Icon(
                icon,
                size: 18, // 调整图标大小
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
