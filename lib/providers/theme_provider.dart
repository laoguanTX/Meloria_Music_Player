// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:palette_generator/palette_generator.dart';

class ThemeProvider extends ChangeNotifier {
  final TickerProvider vsync; // 新增：用于 AnimationController
  late AnimationController _animationController;
  Animation<Color?>? _colorAnimation;

  Color _seedColor = _defaultColor; // 当前稳定的种子颜色
  ColorScheme? _lightColorScheme;
  ColorScheme? _darkColorScheme;
  ThemeMode _themeMode = ThemeMode.system; // 新增：主题模式

  static const Color _defaultColor = Color(0xFF87CEEB); // 天蓝色

  ColorScheme? get lightColorScheme => _lightColorScheme;
  ColorScheme? get darkColorScheme => _darkColorScheme;
  Color get dominantColor => _seedColor; // 返回稳定的种子颜色
  ThemeMode get themeMode => _themeMode; // 新增：获取当前主题模式

  // 新增：获取当前主题模式下的合适前景色
  Color get foregroundColor {
    final Brightness currentBrightness;
    switch (_themeMode) {
      case ThemeMode.light:
        currentBrightness = Brightness.light;
        break;
      case ThemeMode.dark:
        currentBrightness = Brightness.dark;
        break;
      case ThemeMode.system:
        currentBrightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
        break;
    }
    return currentBrightness == Brightness.dark ? Colors.white : Colors.black;
  }

  ThemeProvider({required this.vsync}) {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: vsync,
    );

    // 初始化主题颜色方案，这将是第一次动画的起始状态
    // _seedColor 默认为 _defaultColor
    _lightColorScheme = ColorScheme.fromSeed(seedColor: _seedColor, brightness: Brightness.light);
    _darkColorScheme = ColorScheme.fromSeed(seedColor: _seedColor, brightness: Brightness.dark);

    _animationController.addListener(() {
      if (_colorAnimation != null && _colorAnimation!.value != null) {
        final animatedColor = _colorAnimation!.value!;
        _lightColorScheme = ColorScheme.fromSeed(
          seedColor: animatedColor,
          brightness: Brightness.light,
        );
        _darkColorScheme = ColorScheme.fromSeed(
          seedColor: animatedColor,
          brightness: Brightness.dark,
        );
        notifyListeners();
      }
    });

    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // 动画完成后，更新稳定种子颜色并更新系统UI
        if (_colorAnimation?.value != null) {
          _seedColor = _colorAnimation!.value!;
        }
        _updateSystemUiOverlay();
      } else if (status == AnimationStatus.dismissed) {
        // 如果动画被取消或重置，确保使用当前_seedColor
        _lightColorScheme = ColorScheme.fromSeed(seedColor: _seedColor, brightness: Brightness.light);
        _darkColorScheme = ColorScheme.fromSeed(seedColor: _seedColor, brightness: Brightness.dark);
        _updateSystemUiOverlay();
        notifyListeners();
      }
    });

    // 显式调用 _setDefaultTheme() 来设置并可能动画到初始主题。
    // 这确保了 _animationController 在被 _applyThemeChange 使用前已初始化。
    _setDefaultTheme();

    // 初始时调用一次，确保系统UI基于初始（可能是动画前的）主题正确更新。
    // 如果 _setDefaultTheme 启动了动画，动画状态监听器也会调用 _updateSystemUiOverlay。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateSystemUiOverlay();
    });
  }

  void _applyThemeChange(Color newColor) {
    if (_animationController.isAnimating) {
      _animationController.stop();
    }

    final beginColor = _lightColorScheme?.primary ?? _seedColor;

    _colorAnimation = ColorTween(begin: beginColor, end: newColor).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // 预先将目标颜色设置为_seedColor，这样dominantColor getter可以立即返回新颜色
    // 或者等待动画完成。当前设计是动画过程中_seedColor不变，完成后更新。
    // _seedColor = newColor; // 如果希望dominantColor立即反映目标颜色，则取消注释此行

    _animationController.forward(from: 0.0);
  }

  // 根据当前主题更新系统状态栏样式
  void _updateSystemUiOverlay() {
    // 确保在深色模式和浅色模式下，状态栏图标颜色能正确反转
    final Brightness currentBrightness;
    switch (_themeMode) {
      case ThemeMode.light:
        currentBrightness = Brightness.light;
        break;
      case ThemeMode.dark:
        currentBrightness = Brightness.dark;
        break;
      case ThemeMode.system:
        currentBrightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
        break;
    }
    final bool isDark = currentBrightness == Brightness.dark;

    final ColorScheme? currentScheme = isDark ? _darkColorScheme : _lightColorScheme;

    if (currentScheme != null) {
      SystemChrome.setSystemUIOverlayStyle(
        SystemUiOverlayStyle(
          statusBarColor: Colors.transparent, // 保持状态栏背景透明
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light, // For iOS
          systemNavigationBarColor: currentScheme.surface, // 导航栏背景色随主题
          systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          systemNavigationBarDividerColor: Colors.transparent,
        ),
      );
    }
  }

  void _setDefaultTheme() {
    _applyThemeChange(_defaultColor);
  }

  // 从专辑图片提取颜色并更新主题
  Future<void> updateThemeFromAlbumArt(Uint8List? albumArtData) async {
    if (albumArtData == null) {
      _setDefaultTheme();
      return;
    }
    try {
      final imageProvider = MemoryImage(albumArtData);
      final paletteGenerator = await PaletteGenerator.fromImageProvider(
        imageProvider,
        maximumColorCount: 20,
      );

      Color newDominantColor =
          paletteGenerator.dominantColor?.color ?? paletteGenerator.vibrantColor?.color ?? paletteGenerator.mutedColor?.color ?? _defaultColor;

      final hsl = HSLColor.fromColor(newDominantColor);
      if (hsl.lightness < 0.2) {
        // 调整阈值，避免颜色过暗
        newDominantColor = hsl.withLightness(0.4).toColor();
      } else if (hsl.lightness > 0.85) {
        // 调整阈值，避免颜色过亮
        newDominantColor = hsl.withLightness(0.65).toColor();
      }

      // 确保颜色不会与背景过于接近，增加对比度
      // 这是一个简化的对比度检查，可能需要更复杂的逻辑
      final double luminance = newDominantColor.computeLuminance();
      if (luminance < 0.1 || luminance > 0.9) {
        // 如果亮度过低或过高
        // 尝试从调色板中选择另一个颜色
        newDominantColor = paletteGenerator.lightVibrantColor?.color ?? paletteGenerator.darkVibrantColor?.color ?? _defaultColor;
        // 再次调整亮度
        final newHsl = HSLColor.fromColor(newDominantColor);
        if (newHsl.lightness < 0.2) {
          newDominantColor = newHsl.withLightness(0.4).toColor();
        } else if (newHsl.lightness > 0.85) newDominantColor = newHsl.withLightness(0.65).toColor();
      }

      _applyThemeChange(newDominantColor);
    } catch (e) {
      // print('提取专辑颜色时出错: $e');
      // _setDefaultTheme();
    }
  }

  // 重置为默认主题
  void resetToDefault() {
    _setDefaultTheme();
  }

  // 新增：切换主题模式
  void setThemeMode(ThemeMode mode) {
    if (_themeMode != mode) {
      _themeMode = mode;
      _updateSystemUiOverlay(); // 更新系统UI以匹配新模式
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}
