// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:io' show Platform;

const double kDefaultCustomTitleBarHeight = 53.33; // Public constant for height

class HomeCustomStatusBar extends StatefulWidget {
  final Widget child;
  final Color? backgroundColor;
  final Gradient? gradient;
  final bool transparent;
  final Color? homeScreenBackgroundColor;
  final List<Widget>? actions;
  final bool applyChildTopPadding; // New property

  const HomeCustomStatusBar({
    super.key,
    required this.child,
    this.backgroundColor,
    this.gradient,
    this.transparent = true,
    this.homeScreenBackgroundColor,
    this.actions,
    this.applyChildTopPadding = true, // Default to true
  });

  @override
  State<HomeCustomStatusBar> createState() => _HomeCustomStatusBarState();
}

class _HomeCustomStatusBarState extends State<HomeCustomStatusBar> {
  bool _isAlwaysOnTop = false;
  bool _isMaximized = false;
  // Use the public constant
  static const double kCustomTitleBarHeight = kDefaultCustomTitleBarHeight;

  @override
  void initState() {
    super.initState();
    _checkInitialMaximizedState();
  }

  void _checkInitialMaximizedState() async {
    _isMaximized = await windowManager.isMaximized();
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor:
            widget.transparent ? Colors.transparent : widget.backgroundColor,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
    );

    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
      overlays: [],
    );

    return Stack(
      children: [
        // 1. Main content, conditionally padded
        widget.applyChildTopPadding
            ? Padding(
                padding: const EdgeInsets.only(top: kCustomTitleBarHeight),
                child: widget.child,
              )
            : widget.child,

        // 2. Unified Draggable Title Bar Area
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: kCustomTitleBarHeight,
          child: GestureDetector(
            behavior:
                HitTestBehavior.opaque, // Capture drag events on the entire bar
            onPanStart: (details) {
              windowManager.startDragging();
            },
            onDoubleTap: () {
              _maximizeWindow();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              decoration: _buildEffectiveDecoration(theme),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // New Back Button
                  Builder(builder: (BuildContext context) {
                    bool canPop = Navigator.canPop(context);
                    return IconButton(
                      icon: Icon(
                        Icons.arrow_back,
                        size: 20,
                        color: canPop
                            ? theme.colorScheme.onSurface.withOpacity(0.7)
                            : theme.colorScheme.onSurface
                                .withOpacity(0.3), // Dim color when disabled
                      ),
                      tooltip: '返回',
                      onPressed: canPop
                          ? () {
                              Navigator.pop(context);
                            }
                          : null, // Disable button if cannot pop
                    );
                  }),
                  const SizedBox(width: 8), // Add some spacing
                  Icon(
                    Icons.music_note, // Music icon
                    size: 20,
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                  const SizedBox(width: 4), // Add some spacing
                  Text(
                    'Music Player', // Text
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                      decoration: TextDecoration.none, // Add this line
                    ),
                  ),

                  const Spacer(), // Added Spacer to push subsequent items to the right

                  // Custom actions from widget parameter
                  if (widget.actions != null) ...widget.actions!,

                  // Right side: Window control buttons
                  if (Platform.isWindows ||
                      Platform.isLinux ||
                      Platform.isMacOS)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _buildWindowButton(
                          icon: _isAlwaysOnTop
                              ? Icons.push_pin
                              : Icons.push_pin_outlined,
                          tooltip: _isAlwaysOnTop ? '取消置顶' : '置顶窗口',
                          color:
                              _isAlwaysOnTop ? theme.colorScheme.primary : null,
                          onPressed: _toggleAlwaysOnTop,
                        ),
                        _buildWindowButton(
                          icon: Icons.remove,
                          tooltip: '最小化',
                          onPressed: _minimizeWindow,
                        ),
                        _buildWindowButton(
                          icon: _isMaximized
                              ? Icons.filter_none
                              : Icons.crop_square, // 修改：根据状态更改图标
                          tooltip: _isMaximized ? '还原' : '最大化', // 修改：根据状态更改提示
                          onPressed: _maximizeWindow,
                        ),
                        _buildWindowButton(
                          icon: Icons.close,
                          tooltip: '关闭',
                          isCloseButton: true,
                          onPressed: _closeWindow,
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  BoxDecoration _buildEffectiveDecoration(ThemeData theme) {
    if (widget.homeScreenBackgroundColor != null) {
      // 优先使用 homeScreenBackgroundColor
      return BoxDecoration(
        color: widget.homeScreenBackgroundColor,
      );
    } else {
      // 如果未提供 homeScreenBackgroundColor，则使用现有逻辑
      if (widget.transparent) {
        return const BoxDecoration(
          color: Colors.transparent,
        );
      } else {
        return BoxDecoration(
          color: widget.backgroundColor ??
              theme.colorScheme.surface.withOpacity(0.9),
          gradient: widget.gradient,
        );
      }
    }
  }

  Widget _buildWindowButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    Color? color,
    bool isCloseButton = false,
  }) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 46,
      height:
          kCustomTitleBarHeight, // Ensure button hit area covers full height
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          hoverColor: isCloseButton
              ? Colors.red.withOpacity(0.1)
              : theme.colorScheme.onSurface.withOpacity(0.05),
          child: Container(
            alignment: Alignment.center,
            child: Tooltip(
              message: tooltip,
              child: Icon(
                icon,
                size: 16,
                color: color ??
                    (isCloseButton
                        ? theme.colorScheme.error
                        : theme.colorScheme.onSurface.withOpacity(0.7)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _toggleAlwaysOnTop() async {
    setState(() {
      _isAlwaysOnTop = !_isAlwaysOnTop;
    });
    try {
      await windowManager.setAlwaysOnTop(_isAlwaysOnTop);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isAlwaysOnTop ? '窗口已置顶' : '取消窗口置顶'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('置顶功能暂不可用'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    }
  }

  void _minimizeWindow() async {
    try {
      await windowManager.minimize();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('最小化功能暂不可用'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _maximizeWindow() async {
    try {
      if (_isMaximized) {
        await windowManager.unmaximize();
        if (mounted) {
          setState(() {
            _isMaximized = false; // 更新状态
          });
        }
      } else {
        await windowManager.maximize();
        if (mounted) {
          setState(() {
            _isMaximized = true; // 更新状态
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('最大化功能暂不可用'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _closeWindow() async {
    try {
      await windowManager.close(); // 使用 window_manager 关闭窗口
    } catch (e) {
      // 如果关闭失败，可以考虑回退到 SystemNavigator.pop() 或者显示错误提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('关闭窗口失败'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      // 或者尝试 SystemNavigator.pop(); 作为备选方案
      // SystemNavigator.pop();
    }
  }
} // Ensures _HomeCustomStatusBarState class is properly closed.

// 状态栏工具类
class StatusBarHelper {
  static void setLightStatusBar() {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
    );
  }

  static void setDarkStatusBar() {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
    );
  }

  static void setCustomStatusBar({
    required Color backgroundColor,
    required Brightness iconBrightness,
    Color? navigationBarColor,
  }) {
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: backgroundColor,
        statusBarIconBrightness: iconBrightness,
        statusBarBrightness: iconBrightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
        systemNavigationBarColor: navigationBarColor ?? backgroundColor,
        systemNavigationBarIconBrightness: iconBrightness,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
    );
  }

  static void setGradientStatusBar({
    required List<Color> colors,
    required Brightness iconBrightness,
  }) {
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: iconBrightness,
        statusBarBrightness: iconBrightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
        systemNavigationBarColor: colors.last,
        systemNavigationBarIconBrightness: iconBrightness,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
    );
  }
}
