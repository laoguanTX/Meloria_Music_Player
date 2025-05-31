// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart'; // 导入 window_manager
import '../providers/music_provider.dart';
import '../widgets/bottom_player.dart';
import './music_library_screen.dart';
import './playlists_screen.dart';
import './search_screen.dart';
import './folder_screen.dart';
import './library_stats_screen.dart';
import './settings_screen.dart'; // 新增导入
import './history_screen.dart'; // 导入历史记录页面

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
    const SettingsScreen(), // 新增设置页面
    const HistoryScreen(), // 新增历史记录页面
  ];

  bool _isMaximized = false;
  bool _isFullScreen = false;
  bool _isAlwaysOnTop = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this); // 添加监听器
    _loadInitialWindowState(); // 加载初始窗口状态
    _setWindowMinSize(); // 设置窗口最小尺寸

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
    await windowManager.setMinimumSize(const Size(1000, 700));
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
      // Update _isFullScreen immediately.
      setState(() {
        _isFullScreen = false;
      });

      // After the current frame, update other states that depend on the new window size/state.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          // Fetch the maximized state asynchronously.
          windowManager.isMaximized().then((currentMaximizedState) {
            if (mounted) {
              bool requiresSetState = false;

              // Update maximized state
              if (_isMaximized != currentMaximizedState) {
                _isMaximized = currentMaximizedState;
                requiresSetState = true;
              }

              // Update navigation rail state based on current screen width
              // This ensures the rail adapts to the new window size after exiting fullscreen.
              final screenWidth = MediaQuery.of(context).size.width;
              final newIsExtended = screenWidth > 700;

              if (_isExtended != newIsExtended) {
                _isExtended = newIsExtended;
                if (!_isExtended) {
                  // If collapsing, hide labels immediately, consistent with other parts of the UI.
                  _showLabels = false;
                }
                // If extending, the AnimatedContainer's onEnd callback will handle showing labels
                // after the expansion animation.
                requiresSetState = true;
              }

              if (requiresSetState) {
                setState(() {});
              }
            }
          }).catchError((e) {
            // In a real app, you might want more sophisticated error handling.
            // print('Error updating state after leaving fullscreen: $e');
          });
        }
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
            preferredSize: const Size.fromHeight(kToolbarHeight + 10), // 调整 AppBar 高度以适应拖动区域和内容
            child: GestureDetector(
              // Outer GestureDetector for dragging
              onPanStart: (details) => windowManager.startDragging(),
              // onDoubleTap removed from here
              child: Container(
                padding: const EdgeInsets.only(left: 16, right: 8, top: 6, bottom: 6), // 调整内边距
                color: theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface,
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
                        behavior: HitTestBehavior.opaque, // Ensure entire area is tappable
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
                      icon: _isAlwaysOnTop ? Icons.push_pin : Icons.push_pin_outlined,
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
                      icon: _isMaximized ? Icons.fullscreen_exit : Icons.crop_square, // 根据状态切换图标
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
              Padding(
                // Wrap AnimatedContainer with Padding
                padding: const EdgeInsets.only(bottom: 20.0), // Add bottom padding
                child: AnimatedContainer(
                  // THIS IS THE PRIMARY AnimatedContainer
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
                  onEnd: () {
                    // Moved onEnd callback here
                    if (mounted && _isExtended) {
                      // Only update if _showLabels is false to prevent redundant setState calls
                      if (!_showLabels) {
                        setState(() {
                          _showLabels = true; // Show labels after expansion animation
                        });
                      }
                    }
                  },
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
                                  _showLabels = false; // Hide labels immediately on collapse
                                }
                                // If _isExtended is true, the onEnd callback of this AnimatedContainer
                                // will handle setting _showLabels = true after the animation.
                              });
                            },
                          ),
                        ),
                      ),
                      Expanded(
                        // REMOVED inner AnimatedContainer that also controlled width.
                        // The NavigationRail will now directly fill the space provided by the parent AnimatedContainer.
                        child: NavigationRail(
                          backgroundColor: Colors.transparent, // 设置为透明，因为父Container会处理背景色
                          selectedIconTheme: IconThemeData(size: 28, color: theme.colorScheme.primary),
                          unselectedIconTheme: IconThemeData(size: 28, color: theme.colorScheme.onSurface),
                          labelType: NavigationRailLabelType.none,
                          selectedLabelTextStyle: TextStyle(fontSize: 16, fontFamily: 'MiSans-Bold', color: theme.colorScheme.primary),
                          unselectedLabelTextStyle: TextStyle(fontSize: 16, fontFamily: 'MiSans-Bold', color: theme.colorScheme.onSurface),
                          selectedIndex: _selectedIndex,
                          onDestinationSelected: (index) {
                            setState(() {
                              _selectedIndex = index;
                            });
                          },
                          extended: _isExtended, // Directly use the _isExtended state
                          destinations: [
                            NavigationRailDestination(
                              icon: const Icon(Icons.music_note_outlined),
                              selectedIcon: const Icon(Icons.music_note),
                              label: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                transitionBuilder: (Widget child, Animation<double> animation) {
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
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                            ),
                            NavigationRailDestination(
                              icon: const Icon(Icons.playlist_play_outlined),
                              selectedIcon: const Icon(Icons.playlist_play),
                              label: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                transitionBuilder: (Widget child, Animation<double> animation) {
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
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                            ),
                            NavigationRailDestination(
                              icon: const Icon(Icons.folder_outlined),
                              selectedIcon: const Icon(Icons.folder),
                              label: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                transitionBuilder: (Widget child, Animation<double> animation) {
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
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                            ),
                            NavigationRailDestination(
                              icon: const Icon(Icons.bar_chart_outlined),
                              selectedIcon: const Icon(Icons.bar_chart),
                              label: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                transitionBuilder: (Widget child, Animation<double> animation) {
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
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                            ),
                            NavigationRailDestination(
                              icon: const Icon(Icons.search_outlined),
                              selectedIcon: const Icon(Icons.search),
                              label: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                transitionBuilder: (Widget child, Animation<double> animation) {
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
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                            ),
                            NavigationRailDestination(
                              icon: const Icon(Icons.settings_outlined), // 新增设置图标
                              selectedIcon: const Icon(Icons.settings), // 新增选中状态的设置图标
                              label: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                transitionBuilder: (Widget child, Animation<double> animation) {
                                  return ScaleTransition(
                                    scale: animation,
                                    child: child,
                                  );
                                },
                                child: _showLabels
                                    ? const Text(
                                        '设置', // 新增设置标签
                                        key: ValueKey('label_settings'),
                                      )
                                    : const SizedBox.shrink(
                                        key: ValueKey('empty_settings'),
                                      ),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                            ),
                            NavigationRailDestination(
                              icon: const Icon(Icons.history_outlined), // 新增历史记录图标
                              selectedIcon: const Icon(Icons.history), // 新增选中状态的历史记录图标
                              label: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                transitionBuilder: (Widget child, Animation<double> animation) {
                                  return ScaleTransition(
                                    scale: animation,
                                    child: child,
                                  );
                                },
                                child: _showLabels
                                    ? const Text(
                                        '历史记录', // 新增历史记录标签
                                        key: ValueKey('label_history'),
                                      )
                                    : const SizedBox.shrink(
                                        key: ValueKey('empty_history'),
                                      ),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                            ),
                          ],
                        ),
                      ),
                      // if (_isExtended) const Divider(height: 1),
                      // 在侧边栏底部始终显示音乐库统计
                      // LibraryStatsInSidebar(
                      //     isExtended: _isExtended), // Pass _isExtended
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
                            begin: const Offset(0.0, 0.1), // 页面从下方轻微滑入
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
                          // 使用带 Key 的 Container 包裹页面
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
                          begin: const Offset(0.0, 1.0), // BottomPlayer 从屏幕底部完全滑入
                          end: Offset.zero,
                        );
                        return SlideTransition(
                          position: slideTween.animate(animation),
                          child: child,
                        );
                      },
                      child: musicProvider.currentSong != null
                          ? Padding(
                              key: const ValueKey('bottomPlayerVisible'), // Key 用于 AnimatedSwitcher 识别
                              padding: EdgeInsets.only(
                                bottom: MediaQuery.of(context).viewPadding.bottom,
                              ),
                              child: const BottomPlayer(),
                            )
                          : const SizedBox.shrink(key: ValueKey('bottomPlayerHidden')), // 隐藏时使用 SizedBox.shrink
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
