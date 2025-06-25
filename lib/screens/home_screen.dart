// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart'; // 导入 window_manager
import '../providers/music_provider.dart';
import '../widgets/bottom_player.dart';
import './music_library_screen.dart';
import './search_screen.dart';
import './folder_screen.dart';
import './library_stats_screen.dart';
import './settings_screen.dart'; // 新增导入
import './history_screen.dart'; // 导入历史记录页面
import './playlist_management_screen.dart'; // 导入歌单管理页面
import './artists_screen.dart'; // 导入音乐家页面
import './albums_screen.dart'; // 导入专辑页面
import '../providers/theme_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WindowListener {
  // 添加 WindowListener
  final FocusNode _focusNode = FocusNode();
  int _selectedIndex = 0;
  bool _isExtended = false;
  bool _showLabels = false;

  static const double _kExtendedWidth = 256.0;
  static const double _kCollapsedWidth = 72.0;
  final List<Widget> _pages = [
    const MusicLibrary(), // 音乐库
    const ArtistsScreen(), // 音乐家
    const AlbumsScreen(), // 专辑
    const PlaylistManagementScreen(), // 歌单管理
    const HistoryScreen(), // 历史记录
    const FolderTab(), // 文件夹
    const SearchTab(), // 搜索
    const LibraryStatsScreen(), // 统计
    const SettingsScreen(), // 设置
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
    windowManager.removeListener(this); // 移除监听器
    _focusNode.dispose();
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); // 获取当前主题
    // 计算导航栏背景颜色，混合白色透明度和主题表面颜色
    final navigationRailBackgroundColor = Color.alphaBlend(
      Colors.white.withOpacity(0.03),
      theme.colorScheme.surface,
    );

    return Focus(
      focusNode: _focusNode,
      onKey: (node, event) => _handleKeyEvent(event),
      autofocus: true,
      child: Consumer<MusicProvider>(
        // 使用 Consumer 监听 MusicProvider 的变化
        builder: (context, musicProvider, child) {
          final themeProvider = context.watch<ThemeProvider>();
          return Scaffold(
            // 返回 Scaffold 布局
            appBar: PreferredSize(
              // 自定义 AppBar
              preferredSize: const Size.fromHeight(kToolbarHeight + 10), // 设置 AppBar 的首选高度，增加10像素以容纳拖动区域
              child: GestureDetector(
                // 外层 GestureDetector 用于窗口拖动
                onPanStart: (details) => windowManager.startDragging(), // 拖动开始时，通知 windowManager 开始拖动窗口
                child: Container(
                  // AppBar 的容器
                  padding: const EdgeInsets.only(left: 16, right: 8, top: 6, bottom: 6), // 设置内边距
                  color: theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface, // 设置 AppBar 背景颜色，优先使用 appBarTheme 的颜色，否则使用主题表面颜色
                  child: Row(
                    // AppBar 内容使用行布局
                    children: [
                      Expanded(
                        // 占满 AppBar 左侧剩余空间的部分
                        child: GestureDetector(
                          // 内层 GestureDetector 用于双击最大化/还原窗口
                          onDoubleTap: () async {
                            // 双击事件处理
                            if (await windowManager.isMaximized()) {
                              // 如果窗口已最大化
                              windowManager.unmaximize(); // 取消最大化
                            } else {
                              windowManager.maximize(); // 最大化窗口
                            }
                          },
                          behavior: HitTestBehavior.opaque, // 确保整个区域都可点击
                          child: Row(
                            // 行布局，用于将文本左对齐
                            children: [
                              Image.asset(
                                'lib/asset/icon/app_icon.png',
                                width: 28,
                                height: 28,
                                errorBuilder: (context, error, stackTrace) => const SizedBox(width: 28, height: 28), // 若加载失败则占位
                              ),
                              const SizedBox(width: 8), // 图标与标题间距
                              Text(
                                // 应用标题
                                'Meloria Music Player',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  // 设置标题文本样式
                                  color: theme.colorScheme.onSurface, // 文本颜色
                                  fontWeight: FontWeight.bold, // 粗体
                                ),
                              ),
                              const Spacer(), // 使用 Spacer 填充剩余空间，使 GestureDetector 扩展到整个区域
                            ],
                          ),
                        ),
                      ),
                      // 窗口控制按钮区域
                      WindowControlButton(
                        // 置顶/取消置顶按钮
                        icon: _isAlwaysOnTop ? Icons.push_pin : Icons.push_pin_outlined, // 根据置顶状态显示不同图标
                        tooltip: _isAlwaysOnTop ? '取消置顶' : '置顶窗口', // 提示文本
                        onPressed: () async {
                          // 点击事件处理
                          await windowManager.setAlwaysOnTop(!_isAlwaysOnTop); // 设置窗口置顶状态
                          setState(() {
                            // 更新UI
                            _isAlwaysOnTop = !_isAlwaysOnTop;
                          });
                        },
                      ),
                      WindowControlButton(
                        // 最小化按钮
                        icon: Icons.minimize,
                        tooltip: '最小化',
                        onPressed: () => windowManager.minimize(), // 点击时最小化窗口
                      ),
                      WindowControlButton(
                        // 最大化/向下还原按钮
                        icon: _isMaximized ? Icons.filter_none : Icons.crop_square, // 根据最大化状态显示不同图标
                        tooltip: _isMaximized ? '还原' : '最大化', // 提示文本
                        onPressed: () async {
                          // 点击事件处理
                          if (await windowManager.isMaximized()) {
                            // 如果窗口已最大化
                            windowManager.unmaximize(); // 取消最大化
                          } else {
                            windowManager.maximize(); // 最大化窗口
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
                        // 关闭按钮
                        icon: Icons.close,
                        tooltip: '关闭',
                        isCloseButton: true, // 标记为关闭按钮，可能有特殊样式处理
                        onPressed: () => windowManager.close(), // 点击时关闭窗口
                      ),
                    ],
                  ),
                ),
              ),
            ),
            body: Row(
              // 主体内容使用行布局
              children: [
                Padding(
                  // 左侧导航栏容器，添加底部内边距
                  padding: const EdgeInsets.only(bottom: 20.0), // 添加底部20像素的内边距
                  child: AnimatedContainer(
                    // 带动画效果的容器，用于展开/收起导航栏
                    duration: const Duration(milliseconds: 300), // 动画持续时间
                    curve: Curves.easeInOut, // 动画曲线
                    width: _isExtended ? _kExtendedWidth : _kCollapsedWidth, // 根据展开状态设置宽度
                    decoration: BoxDecoration(
                      // 容器装饰
                      color: navigationRailBackgroundColor, // 背景颜色
                      borderRadius: const BorderRadius.only(
                        // 设置圆角
                        topRight: Radius.circular(16.0),
                        bottomRight: Radius.circular(16.0),
                      ),
                    ),
                    onEnd: () {
                      // 动画结束时的回调
                      if (mounted && _isExtended) {
                        // 如果组件已挂载且导航栏是展开状态
                        if (!_showLabels) {
                          // 仅当标签未显示时更新，避免不必要的 setState 调用
                          setState(() {
                            _showLabels = true; // 展开动画结束后显示标签
                          });
                        }
                      }
                    },
                    child: Column(
                      // 导航栏内容使用列布局
                      children: [
                        Padding(
                          // 展开/收起按钮的容器
                          padding: const EdgeInsets.only(
                            top: 8.0, // 顶部内边距
                            right: 0,
                          ),
                          child: AnimatedAlign(
                            // 带动画效果的对齐组件
                            duration: const Duration(milliseconds: 300), // 动画持续时间
                            curve: Curves.easeInOut, // 动画曲线
                            alignment: _isExtended
                                ? Alignment.centerRight // 展开时，按钮在除去右边距后的空间内靠右
                                : Alignment.center, // 收起时，按钮在总宽度72内居中
                            child: IconButton(
                              // 展开/收起图标按钮
                              icon: Icon(
                                _isExtended ? Icons.menu_open : Icons.menu, // 根据展开状态显示不同图标
                                color: Theme.of(context).iconTheme.color, // 图标颜色
                                size: 24, // 图标大小
                              ),
                              onPressed: () {
                                // 点击事件处理
                                setState(() {
                                  // 更新UI
                                  _isExtended = !_isExtended; // 切换展开状态
                                  if (!_isExtended) {
                                    _showLabels = false; // 收起时立即隐藏标签
                                  }
                                  // 如果 _isExtended 为 true, AnimatedContainer 的 onEnd 回调会处理显示标签
                                });
                              },
                            ),
                          ),
                        ),
                        Expanded(
                          // 占满剩余垂直空间的导航项区域
                          child: NavigationRail(
                            // 导航栏组件
                            backgroundColor: Colors.transparent, // 背景透明，由父容器处理背景色
                            selectedIconTheme: IconThemeData(size: 28, color: theme.colorScheme.primary), // 选中图标主题
                            unselectedIconTheme: IconThemeData(size: 28, color: theme.colorScheme.onSurface), // 未选中图标主题
                            labelType: NavigationRailLabelType.none, // 不显示 NavigationRail 自带的标签，使用自定义 AnimatedSwitcher 实现
                            selectedLabelTextStyle: TextStyle(fontSize: 16, fontFamily: themeProvider.fontFamilyName, color: theme.colorScheme.primary), // 选中标签文本样式
                            unselectedLabelTextStyle:
                                TextStyle(fontSize: 16, fontFamily: themeProvider.fontFamilyName, color: theme.colorScheme.onSurface), // 未选中标签文本样式
                            selectedIndex: _selectedIndex, // 当前选中的导航项索引
                            onDestinationSelected: (index) {
                              // 导航项选择回调
                              setState(() {
                                _selectedIndex = index; // 更新选中的索引
                              });
                            },
                            extended: _isExtended, // 直接使用 _isExtended 状态控制导航栏是否展开（影响标签显示方式）
                            destinations: [
                              // 导航目标列表
                              NavigationRailDestination(
                                // 音乐库导航项
                                icon: const Icon(Icons.music_note_outlined),
                                selectedIcon: const Icon(Icons.music_note),
                                label: AnimatedSwitcher(
                                  // 带动画切换效果的标签
                                  duration: const Duration(milliseconds: 200),
                                  transitionBuilder: (Widget child, Animation<double> animation) {
                                    return ScaleTransition(scale: animation, child: child); // 缩放过渡动画
                                  },
                                  child: _showLabels // 根据 _showLabels 状态决定显示文本还是空SizedBox
                                      ? const Text('音乐库', key: ValueKey('label_library'))
                                      : const SizedBox.shrink(key: ValueKey('empty_library')),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 8.0), // 垂直内边距
                              ),
                              NavigationRailDestination(
                                // 音乐家导航项
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
                                // 专辑导航项
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
                                // 歌单管理导航项
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
                                // 历史记录导航项
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
                                // 文件夹导航项
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
                                // 搜索导航项
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
                                // 统计导航项
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
                                // 设置导航项
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
                  // 主内容区域，占满剩余水平空间
                  child: Column(
                    // 列布局，包含页面内容和底部播放器
                    children: [
                      Expanded(
                        // 占满除底部播放器外的所有垂直空间
                        child: AnimatedSwitcher(
                          // 带动画切换效果的页面容器
                          duration: const Duration(milliseconds: 300), // 动画持续时间
                          switchInCurve: Curves.easeOutCubic, // 进入动画曲线
                          switchOutCurve: Curves.easeInCubic, // 退出动画曲线
                          transitionBuilder: (Widget child, Animation<double> animation) {
                            // 过渡动画构建器
                            final slideTween = Tween<Offset>(
                              // 滑动动画
                              begin: const Offset(0.0, 0.1), // 页面从下方轻微滑入
                              end: Offset.zero,
                            );
                            return SlideTransition(
                              // 滑动过渡
                              position: slideTween.animate(animation),
                              child: FadeTransition(
                                // 淡入淡出过渡
                                opacity: animation,
                                child: child,
                              ),
                            );
                          },
                          child: Container(
                            // 使用带 Key 的 Container 包裹页面，以便 AnimatedSwitcher 正确识别子组件变化
                            key: ValueKey<int>(_selectedIndex), // 使用选中的索引作为 Key
                            child: _pages[_selectedIndex], // 显示当前选中的页面
                          ),
                        ),
                      ),
                      AnimatedSwitcher(
                        // 带动画切换效果的底部播放器容器
                        duration: const Duration(milliseconds: 300), // 动画持续时间
                        switchInCurve: Curves.easeOutCubic, // 进入动画曲线
                        switchOutCurve: Curves.easeInCubic, // 退出动画曲线
                        transitionBuilder: (Widget child, Animation<double> animation) {
                          // 过渡动画构建器
                          final slideTween = Tween<Offset>(
                            // 滑动动画
                            begin: const Offset(0.0, 1.0), // BottomPlayer 从屏幕底部完全滑入
                            end: Offset.zero,
                          );
                          return SlideTransition(
                            // 滑动过渡
                            position: slideTween.animate(animation),
                            child: child,
                          );
                        },
                        child: musicProvider.currentSong != null // 如果当前有播放歌曲
                            ? Padding(
                                // 给底部播放器添加内边距，以避开系统UI（如导航栏）
                                key: const ValueKey('bottomPlayerVisible'), // Key 用于 AnimatedSwitcher 识别
                                padding: EdgeInsets.only(
                                  bottom: MediaQuery.of(context).viewPadding.bottom, // 底部内边距等于系统底部安全区域高度
                                ),
                                child: const BottomPlayer(), // 显示底部播放器
                              )
                            : const SizedBox.shrink(key: ValueKey('bottomPlayerHidden')), // 否则显示一个空的 SizedBox (隐藏)
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

// 自定义窗口控制按钮 Widget
class WindowControlButton extends StatelessWidget {
  final IconData icon; // 按钮图标
  final String tooltip; // 按钮提示文本
  final VoidCallback onPressed; // 按钮点击回调
  final bool isCloseButton; // 是否为关闭按钮，用于特殊样式处理

  const WindowControlButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.isCloseButton = false, // 默认为 false
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); // 获取当前主题
    Color iconColor; // 图标颜色变量
    if (isCloseButton) {
      // 如果是关闭按钮
      // 亮色模式下，使用深色图标 (onSurface color)
      // 暗色模式下，使用白色图标，以便与通常的红色悬停背景形成对比
      iconColor = Theme.of(context).brightness == Brightness.light ? theme.colorScheme.onSurface : Colors.white;
    } else {
      // 其他按钮，使用 onSurface 颜色，该颜色会适应主题
      iconColor = theme.colorScheme.onSurface;
    }

    return SizedBox(
      // 固定按钮大小的容器
      width: 40, // 宽度
      height: 40, // 高度
      child: Tooltip(
        // 添加 Tooltip 以显示提示文本
        message: tooltip,
        child: Material(
          // 使用 Material 包裹 InkWell 以正确显示水波纹效果和圆角
          color: Colors.transparent, // Material 背景透明
          child: InkWell(
            // 可点击区域，带水波纹效果
            onTap: onPressed, // 点击回调
            hoverColor: isCloseButton ? Colors.red.withOpacity(0.8) : theme.colorScheme.onSurface.withOpacity(0.1), // 悬停颜色，关闭按钮为红色，其他为主题色
            borderRadius: BorderRadius.circular(4), // 轻微圆角
            child: Center(
              // 图标居中显示
              child: Icon(
                icon, // 按钮图标
                size: 18, // 调整图标大小
                color: iconColor, // 应用计算出的图标颜色
              ),
            ),
          ),
        ),
      ),
    );
  }
}
